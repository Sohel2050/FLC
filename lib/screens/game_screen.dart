import 'package:flutter/material.dart';
import 'package:flutter_chess_app/env.dart';
import 'package:flutter_chess_app/models/user_model.dart';
import 'package:flutter_chess_app/models/game_room_model.dart';
import 'package:flutter_chess_app/providers/game_provider.dart';
import 'package:flutter_chess_app/providers/settings_provoder.dart';
import 'package:flutter_chess_app/services/admob_service.dart';
import 'package:flutter_chess_app/widgets/animated_dialog.dart';
import 'package:flutter_chess_app/widgets/captured_piece_widget.dart';
import 'package:flutter_chess_app/widgets/confirmation_dialog.dart';
import 'package:flutter_chess_app/widgets/draw_offer_widget.dart';
import 'package:flutter_chess_app/widgets/friend_request_widget.dart';
import 'package:flutter_chess_app/widgets/first_move_countdown_widget.dart';
import 'package:flutter_chess_app/widgets/game_over_dialog.dart';
import 'package:flutter_chess_app/services/friend_service.dart';
import 'package:flutter_chess_app/widgets/profile_image_widget.dart';
import 'package:flutter_chess_app/widgets/unread_badge_widget.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:squares/squares.dart';
import 'package:flutter_chess_app/screens/chat_screen.dart';
import 'package:zego_express_engine/zego_express_engine.dart';

class GameScreen extends StatefulWidget {
  final ChessUser user;
  const GameScreen({super.key, required this.user});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late GameProvider _gameProvider;
  InterstitialAd? _interstitialAd;

  // Audio room state variables
  bool _isInAudioRoom = false;
  bool _isMicrophoneEnabled = false;
  bool _isSpeakerMuted = false;

  BannerAd? _bannerAd;

  @override
  void initState() {
    super.initState();
    _gameProvider = context.read<GameProvider>();
    _gameProvider.gameResultNotifier.addListener(_handleGameOver);

    // We make sure to reset the game state when entering the game screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _gameProvider.resetGame(false); // Start the game and timer

      // For online games, we ensure the listener is active if it's not already
      // This handles cases where GameProvider might be re-initialized
      // or if the stream was somehow interrupted.
      if (_gameProvider.isOnlineGame &&
          _gameProvider.onlineGameRoom != null &&
          _gameProvider.gameRoomSubscription == null) {
        // Re-establish the subscription if it's null (e.g., provider was disposed and re-created)
        _gameProvider.gameRoomSubscription = _gameProvider.gameService
            .streamGameRoom(_gameProvider.onlineGameRoom!.gameId)
            .listen(
              _gameProvider.onOnlineGameRoomUpdate,
              onError: (error) {
                _gameProvider.logger.e(
                  'Error re-streaming game room ${_gameProvider.onlineGameRoom!.gameId}: $error',
                );
              },
              onDone: () {
                _gameProvider.logger.i(
                  'Game room ${_gameProvider.onlineGameRoom!.gameId} stream closed (re-established).',
                );
              },
            );
        _gameProvider.logger.i(
          'Re-established game room subscription in GameScreen.initState',
        );
      }
    });
    _createBannerAd();

    _createInterstitialAd();
  }

  void _createBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: AdMobService.bannerAdUnitId!,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: AdMobService.bannerAdListener,
    )..load();
  }

  void _createInterstitialAd() {
    InterstitialAd.load(
      adUnitId: AdMobService.interstitialAdUnitId!,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _interstitialAd = ad;
        },
        onAdFailedToLoad: (LoadAdError error) => _interstitialAd = null,
      ),
    );
  }

  void _showInterstitialAd() {
    if (_interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _createInterstitialAd();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _createInterstitialAd();
        },
      );
      _interstitialAd!.show();
      _interstitialAd = null;
    }
  }

  @override
  void dispose() {
    _gameProvider.gameResultNotifier.removeListener(_handleGameOver);

    // Cleanup audio room if still connected
    if (_isInAudioRoom) {
      _cleanupZegoEngine().catchError((e) {
        // Handle cleanup error silently in dispose
      });
    }

    _bannerAd?.dispose();
    _interstitialAd?.dispose();

    super.dispose();
  }

  void _handleGameOver() {
    final removeAds =
        widget.user.removeAds == null ? false : widget.user.removeAds!;
    // Check if dialog is already showing to prevent multiple dialogs
    if (ModalRoute.of(context)?.isCurrent != true) {
      return;
    }

    // show interstitialAd
    if (removeAds == false) {
      _showInterstitialAd();
    }

    // Only show dialog if game result is not null
    final gameResult = _gameProvider.gameResult;
    if (gameResult == null) return;

    // Ensure the game is saved for all game types
    if (!_gameProvider.isOnlineGame) {
      // For local games (CPU or local multiplayer), manually trigger save
      _gameProvider.checkGameOver(userId: widget.user.uid);
    }

    // delete chat messages
    if (_gameProvider.isOnlineGame) {
      final gameRoom = _gameProvider.onlineGameRoom;
      if (gameRoom != null) {
        final opponentId =
            gameRoom.player1Id == widget.user.uid
                ? gameRoom.player2Id
                : gameRoom.player1Id;
        if (opponentId != null) {
          _gameProvider.deleteChatMessages(widget.user.uid!, opponentId);
        }
      }
    }

    Future.delayed(const Duration(milliseconds: 500));

    AnimatedDialog.show(
      context: context,
      title: 'Game Over!',
      maxWidth: 400,
      child: GameOverDialog(
        result: _gameProvider.gameResult,
        user: widget.user,
        playerColor: _gameProvider.player,
      ),
    ).then((action) {
      if (action == null) return; // Dialog was dismissed

      final isOnline = _gameProvider.isOnlineGame;

      switch (action) {
        case GameOverAction.rematch:
          // This is now handled in the dialog for local games.
          // For online games, it's also handled in the dialog.
          break;
        case GameOverAction.newGame:
          _gameProvider.disposeStockfish();
          if (isOnline) {
            // For online, properly leave the game room before navigating.
            _gameProvider.cancelOnlineGameSearch();
          }
          // For all modes, a new game means going back to the play screen.
          if (mounted) {
            Navigator.of(context).pop();
          }
          break;
        case GameOverAction.none:
          // Do nothing
          break;
      }
    });
  }

  void _onMove(Move move) async {
    // Make a squared move and set the squares state
    await _gameProvider.makeSquaresMove(move, userId: widget.user.uid!);

    // Check if VS CPU mode is enabled
    if (_gameProvider.vsCPU) {
      _gameProvider.makeStockfishMove();
    } else if (_gameProvider.localMultiplayer) {
      // In local multiplayer, no external notification is needed, we just make the move
      // The makeSquaresMove already handles turn switching and timer updates
    } else if (_gameProvider.isOnlineGame) {
      // For online games, the move is handled by the GameProvider's Firestore update
      // The opponent will receive the update via the stream
    }
  }

  /// Handles the user's attempt to pop the screen (e.g., via back button).
  /// Prompts the user to confirm resigning the game.
  Future<bool> _onWillPop() async {
    // If game is already over, allow popping
    if (_gameProvider.isGameOver) {
      return true;
    }

    final bool? confirmLeave = await AnimatedDialog.show<bool>(
      context: context,
      title: 'Quit Game?',
      maxWidth: 400,
      child: const ConfirmationDialog(
        message:
            'Are you sure you want to quit? This will count as a resignation.',
        confirmButtonText: 'Resign',
        cancelButtonText: 'Cancel',
      ),
    );

    if (confirmLeave == true) {
      await _gameProvider.resignGame(
        userId: widget.user.uid,
      ); // Await resignation for online games

      return true;
    }
    return false;
  }

  /// Shows a confirmation dialog for resigning the game.
  void _showResignDialog() async {
    final bool? confirmResign = await AnimatedDialog.show<bool>(
      context: context,
      title: 'Resign Game?',
      maxWidth: 400,
      child: const ConfirmationDialog(
        message: 'Are you sure you want to resign?',
        confirmButtonText: 'Resign',
        cancelButtonText: 'Cancel',
      ),
    );

    if (confirmResign == true) {
      await _gameProvider.resignGame(
        userId: widget.user.uid,
      ); // Await resignation for online games
      // show game over dialog after resigning
      _handleGameOver();
    }
  }

  /// Shows a confirmation dialog for offering a draw.
  void _showDrawOfferDialog() async {
    if (_gameProvider.localMultiplayer) {
      // For local multiplayer, show a dialog to accept or reject the draw immediately.
      final bool? acceptDraw = await AnimatedDialog.show<bool>(
        context: context,
        title: 'Draw Offer',
        maxWidth: 400,
        child: const ConfirmationDialog(
          message: 'The opponent offers a draw. Do you accept?',
          confirmButtonText: 'Accept',
          cancelButtonText: 'Reject',
        ),
      );
      if (acceptDraw == true) {
        _gameProvider.endGameAsDraw();
      }
    } else {
      // For online games, show a confirmation to send the draw offer.
      final bool? confirmDraw = await AnimatedDialog.show<bool>(
        context: context,
        title: 'Offer Draw?',
        maxWidth: 400,
        child: const ConfirmationDialog(
          message: 'Are you sure you want to offer a draw?',
          confirmButtonText: 'Offer Draw',
          cancelButtonText: 'Cancel',
        ),
      );

      if (confirmDraw == true) {
        await _gameProvider.offerDraw();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final removeAds =
        widget.user.removeAds == null ? false : widget.user.removeAds!;
    // Access the settings provider
    final settingsProvider = context.read<SettingsProvider>();

    return PopScope(
      canPop: _gameProvider.isGameOver,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final bool shouldPop = await _onWillPop();
        if (shouldPop) {
          if (context.mounted) Navigator.of(context).pop();
          _handleGameOver();
        }
      },
      child: Consumer<GameProvider>(
        builder: (context, gameProvider, _) {
          return Scaffold(
            appBar: AppBar(
              title: Text(
                gameProvider.vsCPU
                    ? 'VS CPU'
                    : gameProvider.localMultiplayer
                    ? 'Local'
                    : 'Online',
              ),
              actions: [
                IconButton(
                  onPressed: gameProvider.flipTheBoard,
                  icon: const Icon(Icons.rotate_left),
                  tooltip: 'Flip Board',
                ),
                if (!gameProvider.vsCPU)
                  IconButton(
                    onPressed: _showDrawOfferDialog,
                    icon: const Icon(Icons.handshake),
                    tooltip: 'Offer Draw',
                  ),
                IconButton(
                  onPressed: _showResignDialog,
                  icon: const Icon(Icons.flag),
                  tooltip: 'Resign',
                ),
                if (gameProvider.isOnlineGame)
                  Builder(
                    builder: (context) {
                      final gameRoom = gameProvider.onlineGameRoom;
                      if (gameRoom == null) return const SizedBox.shrink();

                      final opponentId =
                          gameRoom.player1Id == widget.user.uid
                              ? gameRoom.player2Id
                              : gameRoom.player1Id;

                      if (opponentId == null) return const SizedBox.shrink();

                      final chatRoomId = gameProvider.chatService.getChatRoomId(
                        widget.user.uid!,
                        opponentId,
                      );

                      return StreamBuilder<int>(
                        stream: gameProvider.chatService.getUnreadMessageCount(
                          chatRoomId,
                          widget.user.uid!,
                        ),
                        builder: (context, snapshot) {
                          final unreadCount = snapshot.data ?? 0;
                          return Padding(
                            padding: const EdgeInsets.only(right: 16.0),
                            child: UnreadBadgeWidget(
                              count: unreadCount,
                              child: GestureDetector(
                                onTap:
                                    () =>
                                        _showInGameChat(context, gameProvider),
                                child: Icon(Icons.chat),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
              ],
            ),
            body: Stack(
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    // Opponent data, time, and captured pieces
                    if (gameProvider.localMultiplayer)
                      _localMultiplayerOpponentDataAndTime(
                        context,
                        gameProvider,
                        settingsProvider,
                      )
                    else if (gameProvider.isOnlineGame)
                      _onlineOpponentDataAndTime(
                        context,
                        gameProvider,
                        settingsProvider,
                      )
                    else
                      _opponentsDataAndTime(
                        context,
                        gameProvider,
                        settingsProvider,
                      ),

                    // Chess board
                    Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: BoardController(
                        state:
                            gameProvider.flipBoard
                                ? gameProvider.state.board.flipped()
                                : gameProvider.state.board,
                        playState: gameProvider.state.state,
                        pieceSet: settingsProvider.getPieceSet(),
                        theme: settingsProvider.boardTheme,
                        animatePieces: settingsProvider.animatePieces,
                        labelConfig:
                            settingsProvider.showLabels
                                ? LabelConfig.standard
                                : LabelConfig.disabled,
                        moves: gameProvider.state.moves,
                        onMove: _onMove,
                        onPremove: _onMove,
                        markerTheme: MarkerTheme(
                          empty: MarkerTheme.dot,
                          piece: MarkerTheme.corners(),
                        ),
                        promotionBehaviour: PromotionBehaviour.autoPremove,
                      ),
                    ),

                    // First move countdown for online games
                    if (gameProvider.isOnlineGame &&
                        gameProvider.onlineGameRoom != null)
                      Center(
                        child: FirstMoveCountdownWidget(
                          isVisible: gameProvider.shouldShowFirstMoveCountdown,
                          playerToMove: gameProvider.firstMoveCountdownPlayer,
                          onTimeout: () {
                            // Handle timeout by calling the GameProvider method
                            final winner =
                                gameProvider.firstMoveCountdownPlayer ==
                                        Squares.white
                                    ? Squares.black
                                    : Squares.white;
                            gameProvider.handleFirstMoveTimeout(winner: winner);
                          },
                        ),
                      ),

                    // Current user data, time, and captured pieces
                    if (gameProvider.localMultiplayer)
                      _localMultiplayerCurrentUserDataAndTime(
                        context,
                        gameProvider,
                        settingsProvider,
                      )
                    else
                      _currentUserDataAndTime(
                        context,
                        gameProvider,
                        settingsProvider,
                      ),
                    // // Display scores for online games
                    // if (gameProvider.isOnlineGame &&
                    //     gameProvider.onlineGameRoom != null)
                    //   Padding(
                    //     padding: const EdgeInsets.symmetric(vertical: 8.0),
                    //     child: Row(
                    //       mainAxisAlignment: MainAxisAlignment.spaceAround,
                    //       children: [
                    //         Text(
                    //           '${gameProvider.onlineGameRoom!.player1DisplayName}: ${gameProvider.player1OnlineScore}',
                    //           style: Theme.of(context).textTheme.titleMedium,
                    //         ),
                    //         Text(
                    //           '${gameProvider.onlineGameRoom!.player2DisplayName ?? 'Opponent'}: ${gameProvider.player2OnlineScore}',
                    //           style: Theme.of(context).textTheme.titleMedium,
                    //         ),
                    //       ],
                    //     ),
                    //   ),
                  ],
                ),
                if (gameProvider.drawOfferReceived)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: DrawOfferWidget(
                      onAccept: () => gameProvider.handleDrawOffer(true),
                      onDecline: () => gameProvider.handleDrawOffer(false),
                    ),
                  ),
                if (gameProvider.friendRequestReceived)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: FriendRequestWidget(
                      onAccept:
                          () => gameProvider.handleFriendRequest(
                            widget.user.uid!,
                            gameProvider.friendRequestSenderId!,
                            true,
                          ),
                      onDecline:
                          () => gameProvider.handleFriendRequest(
                            widget.user.uid!,
                            gameProvider.friendRequestSenderId!,
                            false,
                          ),
                    ),
                  ),
              ],
            ),
            bottomNavigationBar:
                _bannerAd == null
                    ? SizedBox.shrink()
                    : removeAds == true
                    ? SizedBox.shrink()
                    : Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      height: 52,
                      child: AdWidget(ad: _bannerAd!),
                    ),
          );
        },
      ),
    );
  }

  Widget _opponentsDataAndTime(
    BuildContext context,
    GameProvider gameProvider,
    SettingsProvider settingsProvider,
  ) {
    final int opponentColor =
        gameProvider.player == Squares.white ? Squares.black : Squares.white;
    final bool isOpponentsTurn = gameProvider.game.state.turn == opponentColor;
    final List<String> opponentCaptured =
        opponentColor == Squares.white
            ? gameProvider.whiteCapturedPieces
            : gameProvider.blackCapturedPieces;
    final int materialAdvantage = gameProvider.getMaterialAdvantageForPlayer(
      opponentColor,
    );

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Row(
            children: [
              ProfileImageWidget(
                imageUrl: null,
                countryCode: 'US',
                radius: 20,
                isEditable: false,
                backgroundColor:
                    Theme.of(context).colorScheme.secondaryContainer,
                placeholderIcon:
                    gameProvider.vsCPU ? Icons.computer : Icons.person,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gameProvider.vsCPU
                          ? 'CPU (${['', 'Easy', 'Normal', 'Hard'][gameProvider.gameLevel]})'
                          : 'Opponent Name',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Row(
                      children: [
                        Text(
                          'Rating: ${gameProvider.vsCPU ? [0, 800, 1200, 1600][gameProvider.gameLevel] : 1200}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: CapturedPiecesWidget(
                            capturedPieces: opponentCaptured,
                            materialAdvantage:
                                materialAdvantage > 0 ? materialAdvantage : 0,
                            isWhite: opponentColor == Squares.white,
                            pieceSet: settingsProvider.getPieceSet(),
                            isCompact: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color:
                      isOpponentsTurn
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  gameProvider.getFormattedTime(
                    gameProvider.player == Squares.white
                        ? gameProvider.blacksTime
                        : gameProvider.whitesTime,
                  ),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _onlineOpponentDataAndTime(
    BuildContext context,
    GameProvider gameProvider,
    SettingsProvider settingsProvider,
  ) {
    final GameRoom? gameRoom = gameProvider.onlineGameRoom;
    if (gameRoom == null) {
      return const SizedBox(); // Should not happen in online game
    }

    final bool isPlayer1 = gameProvider.player == gameRoom.player1Color;
    final String opponentDisplayName =
        isPlayer1
            ? (gameRoom.player2DisplayName ?? 'Opponent')
            : gameRoom.player1DisplayName;
    final String? opponentPhotoUrl =
        isPlayer1 ? gameRoom.player2PhotoUrl : gameRoom.player1PhotoUrl;
    final int opponentRating =
        isPlayer1 ? (gameRoom.player2Rating ?? 1200) : gameRoom.player1Rating;
    final int? opponentColor =
        isPlayer1 ? gameRoom.player2Color : gameRoom.player1Color;
    final String? opponentId =
        isPlayer1 ? gameRoom.player2Id : gameRoom.player1Id;
    final String? opponentFlag = gameRoom.player2Flag;

    final bool isOpponentsTurn = gameProvider.game.state.turn == opponentColor;
    final List<String> opponentCaptured =
        opponentColor == Squares.white
            ? gameProvider.whiteCapturedPieces
            : gameProvider.blackCapturedPieces;
    final int materialAdvantage = gameProvider.getMaterialAdvantageForPlayer(
      opponentColor,
    );

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Row(
            children: [
              ProfileImageWidget(
                imageUrl: opponentPhotoUrl,
                countryCode: opponentFlag,
                radius: 20,
                isEditable: false,
                backgroundColor:
                    Theme.of(context).colorScheme.secondaryContainer,
                placeholderIcon: Icons.person,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          opponentDisplayName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(width: 8),
                        // Audio room controls
                        if (_isInAudioRoom) ...[
                          // Speaker mute/unmute button
                          IconButton(
                            icon: Icon(
                              _isSpeakerMuted
                                  ? Icons.volume_off
                                  : Icons.volume_up,
                              size: 20,
                            ),
                            onPressed: _toggleSpeakerMute,
                            tooltip:
                                _isSpeakerMuted
                                    ? 'Unmute Speaker'
                                    : 'Mute Speaker',
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                          ),
                          // Exit audio room button
                          IconButton(
                            icon: const Icon(
                              Icons.call_end,
                              size: 20,
                              color: Colors.red,
                            ),
                            onPressed: _exitAudioRoom,
                            tooltip: 'Leave Audio Room',
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                          ),
                        ],
                        if (!gameProvider.isOpponentFriend &&
                            !gameProvider.friendRequestReceived)
                          IconButton(
                            icon: const Icon(Icons.person_add),
                            onPressed: () {
                              showFriendRequestDialog(
                                opponentId: opponentId!,
                                opponentDisplayName: opponentDisplayName,
                              );
                            },
                          ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          'Rating: $opponentRating',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: CapturedPiecesWidget(
                            capturedPieces: opponentCaptured,
                            materialAdvantage:
                                materialAdvantage > 0 ? materialAdvantage : 0,
                            isWhite: opponentColor == Squares.white,
                            pieceSet: settingsProvider.getPieceSet(),
                            isCompact: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color:
                      isOpponentsTurn
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  gameProvider.getFormattedTime(
                    opponentColor == Squares.white
                        ? gameProvider.whitesTime
                        : gameProvider.blacksTime,
                  ),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void showFriendRequestDialog({
    required String opponentId,
    required String opponentDisplayName,
  }) async {
    final friendService = FriendService();
    await AnimatedDialog.show(
      context: context,
      title: 'Send Friend Request',
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            friendService.sendFriendRequest(
              currentUserId: widget.user.uid!,
              friendUserId: opponentId,
            );
            // pop the dialog
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
          ),
          child: const Text('Send'),
        ),
      ],
      child: Text(
        'Send a friend request to $opponentDisplayName',
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _currentUserDataAndTime(
    BuildContext context,
    GameProvider gameProvider,
    SettingsProvider settingsProvider,
  ) {
    final bool isPlayersTurn =
        gameProvider.game.state.turn == gameProvider.player;
    final List<String> playerCaptured =
        gameProvider.player == Squares.white
            ? gameProvider.whiteCapturedPieces
            : gameProvider.blackCapturedPieces;
    final int materialAdvantage = gameProvider.getMaterialAdvantageForPlayer(
      gameProvider.player,
    );

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Row(
            children: [
              ProfileImageWidget(
                imageUrl: widget.user.photoUrl,
                countryCode: widget.user.countryCode,
                radius: 20,
                isEditable: false,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          gameProvider.isOnlineGame &&
                                  gameProvider.onlineGameRoom != null
                              ? (gameProvider.isHost
                                  ? gameProvider
                                      .onlineGameRoom!
                                      .player1DisplayName
                                  : gameProvider
                                          .onlineGameRoom!
                                          .player2DisplayName ??
                                      widget.user.displayName)
                              : widget.user.displayName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(width: 8),
                        // Audio room controls for online games only
                        if (gameProvider.isOnlineGame) ...[
                          if (!_isInAudioRoom)
                            // Join audio room button (microphone icon)
                            IconButton(
                              icon: Icon(
                                Icons.mic,
                                size: 20,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              onPressed: _showJoinAudioRoomDialog,
                              tooltip: 'Join Audio Room',
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                            )
                          else ...[
                            // Microphone toggle when in audio room
                            IconButton(
                              icon: Icon(
                                _isMicrophoneEnabled
                                    ? Icons.mic
                                    : Icons.mic_off,
                                size: 20,
                                color:
                                    _isMicrophoneEnabled
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.grey,
                              ),
                              onPressed: _toggleMicrophone,
                              tooltip:
                                  _isMicrophoneEnabled
                                      ? 'Mute Microphone'
                                      : 'Unmute Microphone',
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          'Rating: ${gameProvider.isOnlineGame && gameProvider.onlineGameRoom != null ? (gameProvider.isHost ? gameProvider.onlineGameRoom!.player1Rating : gameProvider.onlineGameRoom!.player2Rating ?? widget.user.classicalRating) : widget.user.classicalRating}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: CapturedPiecesWidget(
                            capturedPieces: playerCaptured,
                            materialAdvantage:
                                materialAdvantage > 0 ? materialAdvantage : 0,
                            isWhite: gameProvider.player == Squares.white,
                            pieceSet: settingsProvider.getPieceSet(),
                            isCompact: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color:
                      isPlayersTurn
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  gameProvider.getFormattedTime(
                    gameProvider.player == Squares.white
                        ? gameProvider.whitesTime
                        : gameProvider.blacksTime,
                  ),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontFamily: 'monospace',
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showJoinAudioRoomDialog() {
    AnimatedDialog.show(
      context: context,
      title: 'Join Audio Room',
      maxWidth: 400,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Start voice chat with your opponent during the game.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          // Future: Add premium/ads condition here
          Text(
            '🎵 Premium Feature',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            _joinAudioRoom();
          },
          child: const Text('Join'),
        ),
      ],
    );
  }

  void _joinAudioRoom() async {
    try {
      // TODO: Add premium/ads check here
      // if (!userHasPremium && !hasWatchedAd) {
      //   _showWatchAdDialog();
      //   return;
      // }

      // Initialize Zego Express Engine
      await _initializeZegoEngine();

      setState(() {
        _isInAudioRoom = true;
        _isMicrophoneEnabled = false; // Start with mic disabled
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Joined audio room'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Handle error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to join audio room: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _exitAudioRoom() async {
    try {
      // Zego engine cleanup
      await _cleanupZegoEngine();

      setState(() {
        _isInAudioRoom = false;
        _isMicrophoneEnabled = false;
        _isSpeakerMuted = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Left audio room'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Handle error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error leaving audio room: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _toggleMicrophone() async {
    try {
      if (_isMicrophoneEnabled) {
        // Disable microphone in Zego
        await ZegoExpressEngine.instance.muteMicrophone(true);
      } else {
        // Enable microphone in Zego
        await ZegoExpressEngine.instance.muteMicrophone(false);
      }

      setState(() {
        _isMicrophoneEnabled = !_isMicrophoneEnabled;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to toggle microphone: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _toggleSpeakerMute() async {
    try {
      if (_isSpeakerMuted) {
        // Unmute speaker in Zego
        await ZegoExpressEngine.instance.muteSpeaker(false);
      } else {
        // Mute speaker in Zego
        await ZegoExpressEngine.instance.muteSpeaker(true);
      }

      setState(() {
        _isSpeakerMuted = !_isSpeakerMuted;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to toggle speaker: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 5. Add Zego engine initialization methods (placeholder implementations)
  Future<void> _initializeZegoEngine() async {
    // Zego Express Engine initialization
    await ZegoExpressEngine.createEngineWithProfile(
      ZegoEngineProfile(
        Env.zegoAppId,
        ZegoScenario.Default,
        appSign: Env.zegoAppSign,
      ),
    );

    // Join room
    final roomID =
        _gameProvider.onlineGameRoom?.gameId ??
        'room_${DateTime.now().millisecondsSinceEpoch}';
    final userID = widget.user.uid!;
    final userName = widget.user.displayName;

    await ZegoExpressEngine.instance.loginRoom(
      roomID,
      ZegoUser(userID, userName),
    );
  }

  Future<void> _cleanupZegoEngine() async {
    // Zego Express Engine cleanup
    await ZegoExpressEngine.instance.logoutRoom();
    await ZegoExpressEngine.destroyEngine();
  }

  Widget _localMultiplayerOpponentDataAndTime(
    BuildContext context,
    GameProvider gameProvider,
    SettingsProvider settingsProvider,
  ) {
    final bool isOpponentWhite = gameProvider.player == Squares.black;
    final bool isOpponentsTurn =
        gameProvider.game.state.turn ==
        (isOpponentWhite ? Squares.white : Squares.black);
    final List<String> opponentCaptured =
        isOpponentWhite
            ? gameProvider.whiteCapturedPieces
            : gameProvider.blackCapturedPieces;
    final int materialAdvantage = gameProvider.getMaterialAdvantageForPlayer(
      isOpponentWhite ? Squares.white : Squares.black,
    );

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Row(
            children: [
              ProfileImageWidget(
                imageUrl: null,
                countryCode: 'US',
                radius: 20,
                isEditable: false,
                backgroundColor:
                    Theme.of(context).colorScheme.secondaryContainer,
                placeholderIcon:
                    gameProvider.vsCPU ? Icons.computer : Icons.person,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isOpponentWhite ? 'P1 (White)' : 'P2 (Black)',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),

                    Row(
                      children: [
                        Text(
                          'Rating: ${gameProvider.vsCPU ? [0, 800, 1200, 1600][gameProvider.gameLevel] : 1200}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: CapturedPiecesWidget(
                            capturedPieces: opponentCaptured,
                            materialAdvantage:
                                materialAdvantage > 0 ? materialAdvantage : 0,
                            isWhite: isOpponentWhite,
                            pieceSet: settingsProvider.getPieceSet(),
                            isCompact: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color:
                      isOpponentsTurn
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  gameProvider.getFormattedTime(
                    gameProvider.player == Squares.white
                        ? gameProvider.blacksTime
                        : gameProvider.whitesTime,
                  ),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _localMultiplayerCurrentUserDataAndTime(
    BuildContext context,
    GameProvider gameProvider,
    SettingsProvider settingsProvider,
  ) {
    final bool isPlayerWhite = gameProvider.player == Squares.white;
    final bool isPlayersTurn =
        gameProvider.game.state.turn ==
        (isPlayerWhite ? Squares.white : Squares.black);
    final List<String> playerCaptured =
        isPlayerWhite
            ? gameProvider.whiteCapturedPieces
            : gameProvider.blackCapturedPieces;
    final int materialAdvantage = gameProvider.getMaterialAdvantageForPlayer(
      gameProvider.player,
    );

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Row(
            children: [
              ProfileImageWidget(
                imageUrl: widget.user.photoUrl,
                countryCode: widget.user.countryCode,
                radius: 20,
                isEditable: false,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.user.displayName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Row(
                      children: [
                        Text(
                          isPlayerWhite ? 'P1 (White)' : 'P2 (Black)',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),

                        const SizedBox(width: 8),
                        Expanded(
                          child: CapturedPiecesWidget(
                            capturedPieces: playerCaptured,
                            materialAdvantage:
                                materialAdvantage > 0 ? materialAdvantage : 0,
                            isWhite: gameProvider.player == Squares.white,
                            pieceSet: settingsProvider.getPieceSet(),
                            isCompact: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color:
                      isPlayersTurn
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  gameProvider.getFormattedTime(
                    gameProvider.player == Squares.white
                        ? gameProvider.whitesTime
                        : gameProvider.blacksTime,
                  ),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontFamily: 'monospace',
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showInGameChat(BuildContext context, GameProvider gameProvider) {
    final opponent =
        gameProvider.onlineGameRoom?.player1Id == widget.user.uid
            ? ChessUser(
              uid: gameProvider.onlineGameRoom?.player2Id,
              displayName:
                  gameProvider.onlineGameRoom?.player2DisplayName ?? 'Opponent',
              photoUrl: gameProvider.onlineGameRoom?.player2PhotoUrl,
            )
            : ChessUser(
              uid: gameProvider.onlineGameRoom?.player1Id,
              displayName:
                  gameProvider.onlineGameRoom?.player1DisplayName ?? 'Opponent',
              photoUrl: gameProvider.onlineGameRoom?.player1PhotoUrl,
            );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: ChatScreen(currentUser: widget.user, otherUser: opponent),
        );
      },
    );
  }
}
