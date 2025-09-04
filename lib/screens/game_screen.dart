import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_chess_app/env.dart';
import 'package:flutter_chess_app/models/user_model.dart';
import 'package:flutter_chess_app/models/game_room_model.dart';
import 'package:flutter_chess_app/providers/game_provider.dart';
import 'package:flutter_chess_app/providers/settings_provoder.dart';
import 'package:flutter_chess_app/services/admob_service.dart';
import 'package:flutter_chess_app/services/assets_manager.dart';
import 'package:flutter_chess_app/services/permission_service.dart';
import 'package:flutter_chess_app/utils/constants.dart';
import 'package:flutter_chess_app/widgets/animated_dialog.dart';
import 'package:flutter_chess_app/widgets/audio_access_dialog.dart';
import 'package:flutter_chess_app/widgets/audio_controls_widget.dart';
import 'package:flutter_chess_app/widgets/audio_room_invitation_dialog.dart';
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
  bool _hasTemporaryAudioAccess = false; // For rewarded ad access
  bool _isZegoEngineInitialized = false;
  String? _currentAudioRoomId;
  StreamSubscription<GameRoom>? _audioRoomSubscription;

  // Audio stream management
  String? _publishStreamId;
  Set<String> _playingStreams = <String>{};

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

    // Set up audio room monitoring for online games
    if (_gameProvider.isOnlineGame && _gameProvider.onlineGameRoom != null) {
      _setupAudioRoomListener();
    }
  }

  void _createBannerAd() {
    if (!AdMobService.shouldShowAds(context, widget.user.removeAds)) {
      return; // Don't create ads for premium users or if ads are disabled
    }

    final bannerAdId = AdMobService.getBannerAdUnitId(context);
    if (bannerAdId != null) {
      _bannerAd = BannerAd(
        adUnitId: bannerAdId,
        request: const AdRequest(),
        size: AdSize.banner,
        listener: AdMobService.bannerAdListener,
      )..load();
    }
  }

  void _createInterstitialAd() {
    if (!AdMobService.shouldShowAds(context, widget.user.removeAds)) {
      return; // Don't create ads for premium users or if ads are disabled
    }

    final interstitialAdId = AdMobService.getInterstitialAdUnitId(context);
    if (interstitialAdId != null) {
      InterstitialAd.load(
        adUnitId: interstitialAdId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (InterstitialAd ad) {
            _interstitialAd = ad;
          },
          onAdFailedToLoad: (LoadAdError error) => _interstitialAd = null,
        ),
      );
    }
  }

  void _showInterstitialAd() {
    // Don't show ads for premium users
    if (!AdMobService.shouldShowAds(context, widget.user.removeAds)) {
      return;
    }

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

    // Cancel audio room subscription
    _audioRoomSubscription?.cancel();

    _bannerAd?.dispose();
    _interstitialAd?.dispose();

    super.dispose();
  }

  void _setupAudioRoomListener() {
    if (_gameProvider.onlineGameRoom == null) return;

    _audioRoomSubscription = _gameProvider.gameService
        .streamGameRoom(_gameProvider.onlineGameRoom!.gameId)
        .listen(
          (gameRoom) => _handleAudioRoomUpdates(gameRoom),
          onError: (error) {
            _gameProvider.logger.e(
              'Error listening to audio room updates: $error',
            );
          },
        );
  }

  void _handleAudioRoomUpdates(GameRoom gameRoom) {
    final currentUserId = widget.user.uid!;
    final audioRoomStatus = gameRoom.audioRoomStatus;
    final audioRoomParticipants = gameRoom.audioRoomParticipants;
    final audioRoomInvitedBy = gameRoom.audioRoomInvitedBy;

    // Handle audio room invitation
    if (audioRoomStatus == Constants.audioStatusInvitePending &&
        audioRoomInvitedBy != currentUserId) {
      _showAudioRoomInvitation(gameRoom);
    }

    // Handle when audio room becomes active
    if (audioRoomStatus == Constants.audioStatusActive &&
        audioRoomParticipants.contains(currentUserId) &&
        !_isInAudioRoom) {
      _autoJoinAudioRoom();
    }

    // Handle when audio room ends or user is removed from audio room
    if (audioRoomStatus == Constants.audioStatusEnded && _isInAudioRoom) {
      _autoLeaveAudioRoom();
    } else if (!audioRoomParticipants.contains(currentUserId) &&
        _isInAudioRoom) {
      _autoLeaveAudioRoom();
    }

    // Notify user when opponent starts audio
    if (audioRoomStatus == Constants.audioStatusInvitePending &&
        audioRoomInvitedBy != currentUserId) {
      _showAudioStartedNotification(gameRoom);
    }
  }

  void _showAudioRoomInvitation(GameRoom gameRoom) async {
    final invitingUserId = gameRoom.audioRoomInvitedBy;
    if (invitingUserId == null) return;

    // Get inviting user details
    final invitingUser = gameRoom.player1Id == invitingUserId
        ? ChessUser(
            uid: gameRoom.player1Id,
            displayName: gameRoom.player1DisplayName,
            photoUrl: gameRoom.player1PhotoUrl,
            countryCode: gameRoom.player1Flag,
          )
        : ChessUser(
            uid: gameRoom.player2Id,
            displayName: gameRoom.player2DisplayName ?? 'Opponent',
            photoUrl: gameRoom.player2PhotoUrl,
            countryCode: gameRoom.player2Flag,
          );

    final result = await AudioRoomInvitationDialog.show(
      context: context,
      invitingUser: invitingUser,
    );

    if (result == AudioRoomAction.join) {
      await _handleAudioRoomJoin();
    } else if (result == AudioRoomAction.reject) {
      await _gameProvider.handleAudioRoomInvitation(widget.user.uid!, false);
    }
  }

  void _showAudioStartedNotification(GameRoom gameRoom) {
    final invitingUserName = gameRoom.player1Id == gameRoom.audioRoomInvitedBy
        ? gameRoom.player1DisplayName
        : gameRoom.player2DisplayName ?? 'Opponent';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.mic, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text('$invitingUserName started audio room')),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        duration: Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Join',
          textColor: Colors.white,
          onPressed: _handleAudioRoomJoin,
        ),
      ),
    );
  }

  Future<void> _handleAudioRoomJoin() async {
    // Check microphone permission first
    final permissionService = PermissionService();
    final permissionResult = await permissionService
        .requestMicrophonePermission(context);

    if (permissionResult == PermissionResult.denied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Microphone permission is required for voice chat'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    } else if (permissionResult == PermissionResult.permanentlyDenied) {
      await permissionService.handlePermanentlyDeniedPermission(
        context,
        'Microphone',
      );
      return;
    }

    // Check if user has premium or temporary access
    if (!_hasAudioAccess()) {
      final result = await AudioAccessDialog.show(context: context);

      if (result == AudioAccessAction.watchAd) {
        _hasTemporaryAudioAccess = true;
      } else if (result == AudioAccessAction.premium) {
        // Navigate to premium screen or show premium info
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Visit Profile screen to upgrade to Premium'),
            duration: Duration(seconds: 3),
          ),
        );
        return;
      } else {
        return; // User cancelled
      }
    }

    try {
      // Accept the audio room invitation
      await _gameProvider.handleAudioRoomInvitation(widget.user.uid!, true);

      // Initialize ZegoCloud if not already done
      await _initializeZegoEngineIfNeeded();

      // Check if there are existing participants and start playing their streams
      final participants = _gameProvider.getAudioRoomParticipants();
      for (final participantId in participants) {
        if (participantId != widget.user.uid) {
          await _startPlayingOpponentStream(participantId);
        }
      }

      setState(() {
        _isInAudioRoom = true;
        _isMicrophoneEnabled = true; // Start with mic enabled
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Joined audio room'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to join audio room: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _autoJoinAudioRoom() async {
    if (_isInAudioRoom) return;

    // Check microphone permission before auto-joining
    final permissionService = PermissionService();
    final hasPermission = await permissionService
        .isMicrophonePermissionGranted();

    if (!hasPermission) {
      _gameProvider.logger.w(
        'Cannot auto-join audio room: microphone permission not granted',
      );
      return;
    }

    try {
      await _initializeZegoEngineIfNeeded();

      // Check if there are existing participants and start playing their streams
      final participants = _gameProvider.getAudioRoomParticipants();
      for (final participantId in participants) {
        if (participantId != widget.user.uid) {
          await _startPlayingOpponentStream(participantId);
        }
      }

      setState(() {
        _isInAudioRoom = true;
        _isMicrophoneEnabled = true;
      });
    } catch (e) {
      _gameProvider.logger.e('Failed to auto-join audio room: $e');
    }
  }

  Future<void> _autoLeaveAudioRoom() async {
    if (!_isInAudioRoom) return;

    try {
      await _cleanupZegoEngine();

      setState(() {
        _isInAudioRoom = false;
        _isMicrophoneEnabled = false;
        _isSpeakerMuted = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.mic_off, color: Colors.white),
                SizedBox(width: 8),
                Text('Audio room ended'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      _gameProvider.logger.e('Failed to auto-leave audio room: $e');
    }
  }

  bool _hasAudioAccess() {
    return widget.user.removeAds == true || _hasTemporaryAudioAccess;
  }

  void _handleGameOver() {
    // Check if dialog is already showing to prevent multiple dialogs
    if (ModalRoute.of(context)?.isCurrent != true) {
      return;
    }

    // Show interstitial ad (respects premium status internally)
    _showInterstitialAd();

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
        final opponentId = gameRoom.player1Id == widget.user.uid
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

                      final opponentId = gameRoom.player1Id == widget.user.uid
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
                                onTap: () =>
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
                        state: gameProvider.flipBoard
                            ? gameProvider.state.board.flipped()
                            : gameProvider.state.board,
                        playState: gameProvider.state.state,
                        pieceSet: settingsProvider.getPieceSet(),
                        theme: settingsProvider.boardTheme,
                        animatePieces: settingsProvider.animatePieces,
                        labelConfig: settingsProvider.showLabels
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
                      onAccept: () => gameProvider.handleFriendRequest(
                        widget.user.uid!,
                        gameProvider.friendRequestSenderId!,
                        true,
                      ),
                      onDecline: () => gameProvider.handleFriendRequest(
                        widget.user.uid!,
                        gameProvider.friendRequestSenderId!,
                        false,
                      ),
                    ),
                  ),
              ],
            ),
            bottomNavigationBar: _bannerAd == null
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
    final int opponentColor = gameProvider.player == Squares.white
        ? Squares.black
        : Squares.white;
    final bool isOpponentsTurn = gameProvider.game.state.turn == opponentColor;
    final List<String> opponentCaptured = opponentColor == Squares.white
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
              // Opponent profile and info (left side)
              ProfileImageWidget(
                imageUrl: null,
                countryCode: 'US',
                radius: 20,
                isEditable: false,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.secondaryContainer,
                placeholderIcon: gameProvider.vsCPU
                    ? Icons.computer
                    : Icons.person,
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    gameProvider.vsCPU
                        ? 'CPU (${['', 'Easy', 'Normal', 'Hard'][gameProvider.gameLevel]})'
                        : 'Opponent Name',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    'Rating: ${gameProvider.vsCPU ? [0, 800, 1200, 1600][gameProvider.gameLevel] : 1200}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),

              // Empty space for consistency (center)
              const Expanded(child: SizedBox()),

              // Captured pieces and timer (right side)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isOpponentsTurn
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
                  const SizedBox(height: 4),
                  CapturedPiecesWidget(
                    capturedPieces: opponentCaptured,
                    materialAdvantage: materialAdvantage > 0
                        ? materialAdvantage
                        : 0,
                    isWhite: opponentColor == Squares.white,
                    pieceSet: settingsProvider.getPieceSet(),
                    isCompact: true,
                  ),
                ],
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
    final String opponentDisplayName = isPlayer1
        ? (gameRoom.player2DisplayName ?? 'Opponent')
        : gameRoom.player1DisplayName;
    final String? opponentPhotoUrl = isPlayer1
        ? gameRoom.player2PhotoUrl
        : gameRoom.player1PhotoUrl;
    final int opponentRating = isPlayer1
        ? (gameRoom.player2Rating ?? 1200)
        : gameRoom.player1Rating;
    final int? opponentColor = isPlayer1
        ? gameRoom.player2Color
        : gameRoom.player1Color;
    final String? opponentId = isPlayer1
        ? gameRoom.player2Id
        : gameRoom.player1Id;
    final String? opponentFlag = gameRoom.player2Flag;

    final bool isOpponentsTurn = gameProvider.game.state.turn == opponentColor;
    final List<String> opponentCaptured = opponentColor == Squares.white
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
              // Opponent profile and info (left side)
              ProfileImageWidget(
                imageUrl: opponentPhotoUrl,
                countryCode: opponentFlag,
                radius: 20,
                isEditable: false,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.secondaryContainer,
                placeholderIcon: Icons.person,
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        opponentDisplayName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(width: 8),
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
                  Text(
                    'Rating: $opponentRating',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),

              // Audio status indicator (center)
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isInAudioRoom) ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primaryContainer.withAlpha(77),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              AssetsManager.micIcon,
                              width: 16,
                              height: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'In Audio',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Captured pieces and timer (right side)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isOpponentsTurn
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
                  const SizedBox(height: 4),
                  CapturedPiecesWidget(
                    capturedPieces: opponentCaptured,
                    materialAdvantage: materialAdvantage > 0
                        ? materialAdvantage
                        : 0,
                    isWhite: opponentColor == Squares.white,
                    pieceSet: settingsProvider.getPieceSet(),
                    isCompact: true,
                  ),
                ],
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
    final List<String> playerCaptured = gameProvider.player == Squares.white
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
              // User profile and info (left side)
              ProfileImageWidget(
                imageUrl: widget.user.photoUrl,
                countryCode: widget.user.countryCode,
                radius: 20,
                isEditable: false,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    gameProvider.isOnlineGame &&
                            gameProvider.onlineGameRoom != null
                        ? (gameProvider.isHost
                              ? gameProvider.onlineGameRoom!.player1DisplayName
                              : gameProvider
                                        .onlineGameRoom!
                                        .player2DisplayName ??
                                    widget.user.displayName)
                        : widget.user.displayName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    'Rating: ${gameProvider.isOnlineGame && gameProvider.onlineGameRoom != null ? (gameProvider.isHost ? gameProvider.onlineGameRoom!.player1Rating : gameProvider.onlineGameRoom!.player2Rating ?? widget.user.classicalRating) : widget.user.classicalRating}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),

              // Audio controls (center)
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (gameProvider.isOnlineGame) ...[
                      if (_isInAudioRoom) ...[
                        AudioControlsWidget(
                          isInAudioRoom: _isInAudioRoom,
                          isMicrophoneEnabled: _isMicrophoneEnabled,
                          isSpeakerMuted: _isSpeakerMuted,
                          participants: gameProvider.getAudioRoomParticipants(),
                          onToggleMicrophone: _toggleMicrophone,
                          onToggleSpeaker: _toggleSpeakerMute,
                          onLeaveAudio: _leaveAudioRoom,
                        ),
                      ] else ...[
                        GestureDetector(
                          onTap: _showAudioRoomInvitationDialog,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                                  .withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Image.asset(
                              AssetsManager.micIcon,
                              width: 24,
                              height: 24,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),

              // Captured pieces and timer (right side)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isPlayersTurn
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
                  const SizedBox(height: 4),
                  CapturedPiecesWidget(
                    capturedPieces: playerCaptured,
                    materialAdvantage: materialAdvantage > 0
                        ? materialAdvantage
                        : 0,
                    isWhite: gameProvider.player == Squares.white,
                    pieceSet: settingsProvider.getPieceSet(),
                    isCompact: true,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _toggleMicrophone() async {
    // Ensure engine is initialized before attempting to control microphone
    if (!_isZegoEngineInitialized) {
      _gameProvider.logger.w(
        'Attempted to toggle microphone before ZegoCloud engine initialization',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Voice chat not initialized. Please try joining the audio room again.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Check if microphone permission is still granted
    final permissionService = PermissionService();
    final hasPermission = await permissionService
        .isMicrophonePermissionGranted();

    if (!hasPermission) {
      _gameProvider.logger.w('Microphone permission revoked during runtime');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission is required for voice chat'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    // Store the current state to revert if operation fails
    final bool previousState = _isMicrophoneEnabled;
    final bool newState = !_isMicrophoneEnabled;

    try {
      // Update UI state optimistically
      setState(() {
        _isMicrophoneEnabled = newState;
      });

      // Apply the change to ZegoCloud
      await ZegoExpressEngine.instance.muteMicrophone(!newState);

      _gameProvider.logger.i(
        newState ? 'Microphone unmuted' : 'Microphone muted',
      );

      // Verify the state was applied correctly by checking ZegoCloud state
      // Note: ZegoCloud doesn't provide a direct way to query microphone state,
      // so we rely on the success of the API call
    } catch (e) {
      // Revert UI state on failure
      if (mounted) {
        setState(() {
          _isMicrophoneEnabled = previousState;
        });
      }

      // Handle the error with user-friendly feedback
      _handleAudioControlFailure(
        '${newState ? 'unmute' : 'mute'} microphone',
        e,
        previousState,
      );
    }
  }

  void _toggleSpeakerMute() async {
    // Ensure engine is initialized before attempting to control speaker
    if (!_isZegoEngineInitialized) {
      _gameProvider.logger.w(
        'Attempted to toggle speaker before ZegoCloud engine initialization',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Voice chat not initialized. Please try joining the audio room again.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Store the current state to revert if operation fails
    final bool previousState = _isSpeakerMuted;
    final bool newState = !_isSpeakerMuted;

    try {
      // Update UI state optimistically
      setState(() {
        _isSpeakerMuted = newState;
      });

      // Apply the change to ZegoCloud
      await ZegoExpressEngine.instance.muteSpeaker(newState);

      _gameProvider.logger.i(newState ? 'Speaker muted' : 'Speaker unmuted');

      // Verify the state was applied correctly by checking ZegoCloud state
      // Note: ZegoCloud doesn't provide a direct way to query speaker state,
      // so we rely on the success of the API call
    } catch (e) {
      // Revert UI state on failure
      if (mounted) {
        setState(() {
          _isSpeakerMuted = previousState;
        });
      }

      // Handle the error with user-friendly feedback
      _handleAudioControlFailure(
        '${newState ? 'mute' : 'unmute'} speaker',
        e,
        previousState,
      );
    }
  }

  // 5. Add Zego engine initialization methods
  Future<void> _initializeZegoEngine() async {
    if (_isZegoEngineInitialized) return;

    // Check microphone permission before initializing ZegoCloud engine
    final permissionService = PermissionService();
    final hasPermission = await permissionService
        .isMicrophonePermissionGranted();

    if (!hasPermission) {
      throw Exception('Microphone permission is required for voice chat');
    }

    try {
      _gameProvider.logger.i('Starting ZegoCloud engine initialization...');

      // Step 1: Create engine with profile
      await ZegoExpressEngine.createEngineWithProfile(
        ZegoEngineProfile(
          Env.zegoAppId,
          ZegoScenario.Default,
          appSign: Env.zegoAppSign,
        ),
      );
      _gameProvider.logger.i('ZegoCloud engine created successfully');

      // Step 2: Set up stream event listeners before login
      _setupZegoStreamEventListeners();

      // Step 3: Login to room
      final roomID =
          _gameProvider.onlineGameRoom?.gameId ??
          'room_${DateTime.now().millisecondsSinceEpoch}';
      final userID = widget.user.uid!;
      final userName = widget.user.displayName ?? 'User';

      await ZegoExpressEngine.instance.loginRoom(
        roomID,
        ZegoUser(userID, userName),
      );
      _gameProvider.logger.i(
        'Successfully logged into ZegoCloud room: $roomID',
      );

      // Step 4: Start publishing stream for sending audio
      _publishStreamId = '${userID}_audio_stream';
      await ZegoExpressEngine.instance.startPublishingStream(_publishStreamId!);
      _gameProvider.logger.i(
        'Started publishing audio stream: $_publishStreamId',
      );

      _isZegoEngineInitialized = true;
      _currentAudioRoomId = roomID;

      // Initialize audio states to default values
      await _initializeAudioStates();

      // Sync audio states to ensure consistency
      await _syncAudioStates();

      _gameProvider.logger.i(
        'ZegoCloud engine initialization completed successfully',
      );
    } catch (e) {
      _gameProvider.logger.e('Failed to initialize ZegoCloud engine: $e');

      // Cleanup on failure
      try {
        await _cleanupZegoEngineOnFailure();
      } catch (cleanupError) {
        _gameProvider.logger.e(
          'Error during cleanup after initialization failure: $cleanupError',
        );
      }

      _isZegoEngineInitialized = false;
      _currentAudioRoomId = null;
      _publishStreamId = null;

      // Show user-friendly error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize voice chat: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }

      rethrow;
    }
  }

  Future<void> _initializeZegoEngineIfNeeded() async {
    if (!_isZegoEngineInitialized) {
      try {
        await _initializeZegoEngine();
      } catch (e) {
        _gameProvider.logger.e(
          'Failed to initialize ZegoCloud engine when needed: $e',
        );
        throw Exception('Voice chat initialization failed. Please try again.');
      }
    }
  }

  /// Initialize audio states to ensure UI reflects ZegoCloud state
  Future<void> _initializeAudioStates() async {
    try {
      // Set initial microphone state (start with microphone disabled for better UX)
      await ZegoExpressEngine.instance.muteMicrophone(true);

      // Set initial speaker state (start with speaker enabled)
      await ZegoExpressEngine.instance.muteSpeaker(false);

      // Update UI state to match ZegoCloud state
      if (mounted) {
        setState(() {
          _isMicrophoneEnabled = true; // Microphone starts enabled
          _isSpeakerMuted = false; // Speaker starts unmuted
        });
      }

      _gameProvider.logger.i(
        'Audio states initialized: mic=muted, speaker=unmuted',
      );
    } catch (e) {
      _gameProvider.logger.w('Failed to initialize audio states: $e');
      // Don't throw error as this is not critical for engine initialization
    }
  }

  /// Synchronize UI state with ZegoCloud audio state
  /// This method can be called to ensure UI reflects actual ZegoCloud state
  Future<void> _syncAudioStates() async {
    if (!_isZegoEngineInitialized) {
      _gameProvider.logger.w(
        'Cannot sync audio states: ZegoCloud engine not initialized',
      );
      return;
    }

    try {
      // Note: ZegoCloud SDK doesn't provide direct methods to query current audio states
      // So we rely on our internal state tracking and the success of API calls
      // If there are discrepancies, they will be corrected when users interact with controls

      _gameProvider.logger.i(
        'Audio states synced: mic=${_isMicrophoneEnabled ? 'enabled' : 'disabled'}, '
        'speaker=${_isSpeakerMuted ? 'muted' : 'unmuted'}',
      );
    } catch (e) {
      _gameProvider.logger.w('Failed to sync audio states: $e');
    }
  }

  /// Handle audio control failures with appropriate user feedback and recovery
  void _handleAudioControlFailure(
    String operation,
    dynamic error,
    bool revertToState,
  ) {
    _gameProvider.logger.e('Audio control failure - $operation: $error');

    if (mounted) {
      // Show user-friendly error message
      String userMessage;
      if (error.toString().contains('permission')) {
        userMessage = 'Microphone permission required for voice chat';
      } else if (error.toString().contains('network') ||
          error.toString().contains('connection')) {
        userMessage =
            'Network error. Please check your connection and try again';
      } else if (error.toString().contains('engine') ||
          error.toString().contains('initialize')) {
        userMessage =
            'Voice chat not ready. Please try rejoining the audio room';
      } else {
        userMessage = 'Failed to $operation. Please try again';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text(userMessage)),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () {
              // Provide retry option for critical operations
              if (operation.contains('microphone')) {
                _toggleMicrophone();
              } else if (operation.contains('speaker')) {
                _toggleSpeakerMute();
              }
            },
          ),
        ),
      );
    }
  }

  void _setupZegoStreamEventListeners() {
    // Listen for remote users joining/leaving the room
    ZegoExpressEngine.onRoomUserUpdate = (roomID, updateType, userList) {
      _gameProvider.logger.i(
        'Room user update - Room: $roomID, Type: $updateType, Users: ${userList.map((u) => u.userID).join(', ')}',
      );

      for (final user in userList) {
        if (user.userID != widget.user.uid) {
          if (updateType == ZegoUpdateType.Add) {
            // User joined - start playing their stream
            _startPlayingOpponentStream(user.userID);
          } else {
            // User left - stop playing their stream
            _stopPlayingOpponentStream(user.userID);
          }
        }
      }
    };

    // Listen for stream updates (when users start/stop publishing)
    ZegoExpressEngine
        .onRoomStreamUpdate = (roomID, updateType, streamList, extendedData) {
      _gameProvider.logger.i(
        'Stream update - Room: $roomID, Type: $updateType, Streams: ${streamList.map((s) => s.streamID).join(', ')}',
      );

      for (final stream in streamList) {
        final streamUserId = _extractUserIdFromStreamId(stream.streamID);
        if (streamUserId != widget.user.uid) {
          if (updateType == ZegoUpdateType.Add) {
            // New stream available - start playing it
            _startPlayingStream(stream.streamID);
          } else {
            // Stream ended - stop playing it
            _stopPlayingStream(stream.streamID);
          }
        }
      }
    };
  }

  String _extractUserIdFromStreamId(String streamId) {
    // Stream IDs are in format: "userId_audio_stream"
    return streamId.split('_').first;
  }

  Future<void> _startPlayingOpponentStream(String opponentUserId) async {
    final streamId = '${opponentUserId}_audio_stream';
    await _startPlayingStream(streamId);
  }

  Future<void> _startPlayingStream(String streamId) async {
    if (_playingStreams.contains(streamId)) {
      _gameProvider.logger.i('Already playing stream: $streamId');
      return;
    }

    try {
      await ZegoExpressEngine.instance.startPlayingStream(streamId);
      _playingStreams.add(streamId);
      _gameProvider.logger.i('Started playing audio stream: $streamId');
    } catch (e) {
      _gameProvider.logger.e('Failed to start playing stream $streamId: $e');
    }
  }

  Future<void> _stopPlayingOpponentStream(String opponentUserId) async {
    final streamId = '${opponentUserId}_audio_stream';
    await _stopPlayingStream(streamId);
  }

  Future<void> _stopPlayingStream(String streamId) async {
    if (!_playingStreams.contains(streamId)) {
      return;
    }

    try {
      await ZegoExpressEngine.instance.stopPlayingStream(streamId);
      _playingStreams.remove(streamId);
      _gameProvider.logger.i('Stopped playing audio stream: $streamId');
    } catch (e) {
      _gameProvider.logger.e('Failed to stop playing stream $streamId: $e');
    }
  }

  Future<void> _cleanupZegoEngine() async {
    try {
      if (_isZegoEngineInitialized) {
        _gameProvider.logger.i('Starting ZegoCloud engine cleanup...');

        // Step 1: Stop all playing streams
        final playingStreamsCopy = Set<String>.from(_playingStreams);
        for (final streamId in playingStreamsCopy) {
          try {
            await _stopPlayingStream(streamId);
          } catch (e) {
            _gameProvider.logger.w(
              'Error stopping playing stream $streamId: $e',
            );
          }
        }

        // Step 2: Stop publishing stream
        if (_publishStreamId != null) {
          try {
            await ZegoExpressEngine.instance.stopPublishingStream();
            _gameProvider.logger.i(
              'Stopped publishing audio stream: $_publishStreamId',
            );
            _publishStreamId = null;
          } catch (e) {
            _gameProvider.logger.w('Error stopping publishing stream: $e');
          }
        }

        // Step 3: Logout from room
        try {
          await ZegoExpressEngine.instance.logoutRoom();
          _gameProvider.logger.i('Successfully logged out from ZegoCloud room');
        } catch (e) {
          _gameProvider.logger.w('Error logging out from room: $e');
        }

        // Step 4: Clear event listeners
        ZegoExpressEngine.onRoomUserUpdate = null;
        ZegoExpressEngine.onRoomStreamUpdate = null;

        // Step 5: Destroy engine
        try {
          await ZegoExpressEngine.destroyEngine();
          _gameProvider.logger.i('ZegoCloud engine destroyed successfully');
        } catch (e) {
          _gameProvider.logger.w('Error destroying engine: $e');
        }

        _isZegoEngineInitialized = false;
        _currentAudioRoomId = null;
        _playingStreams.clear();

        _gameProvider.logger.i('ZegoCloud engine cleanup completed');
      }
    } catch (e) {
      _gameProvider.logger.e('Error during ZegoCloud cleanup: $e');

      // Force reset state even if cleanup failed
      _isZegoEngineInitialized = false;
      _currentAudioRoomId = null;
      _publishStreamId = null;
      _playingStreams.clear();
    }
  }

  Future<void> _cleanupZegoEngineOnFailure() async {
    try {
      if (_isZegoEngineInitialized) {
        await ZegoExpressEngine.destroyEngine();
      }
    } catch (e) {
      _gameProvider.logger.w('Error during failure cleanup: $e');
    }

    // Clear event listeners
    ZegoExpressEngine.onRoomUserUpdate = null;
    ZegoExpressEngine.onRoomStreamUpdate = null;
  }

  Future<void> _leaveAudioRoom() async {
    try {
      if (_gameProvider.isOnlineGame) {
        // End the audio room for all participants instead of just leaving
        await _gameProvider.endAudioRoom(widget.user.uid!);
      }

      await _cleanupZegoEngine();

      setState(() {
        _isInAudioRoom = false;
        _isMicrophoneEnabled = false;
        _isSpeakerMuted = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Audio room ended'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error leaving audio room: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showAudioRoomInvitationDialog() {
    if (!_gameProvider.isOnlineGame) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Audio room is only available in online games'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    AnimatedDialog.show(
      context: context,
      title: 'Start Audio Room?',
      maxWidth: 400,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.mic,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          const Text(
            'Invite your opponent to voice chat',
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Your opponent will receive an invitation to join the audio room.',
            textAlign: TextAlign.center,
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
            _sendAudioRoomInvitation();
          },
          child: const Text('Invite'),
        ),
      ],
    );
  }

  Future<void> _sendAudioRoomInvitation() async {
    // Check microphone permission first
    final permissionService = PermissionService();
    final permissionResult = await permissionService
        .requestMicrophonePermission(context);

    if (permissionResult == PermissionResult.denied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Microphone permission is required for voice chat'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    } else if (permissionResult == PermissionResult.permanentlyDenied) {
      await permissionService.handlePermanentlyDeniedPermission(
        context,
        'Microphone',
      );
      return;
    }

    // Check if user has access first
    if (!_hasAudioAccess()) {
      final result = await AudioAccessDialog.show(context: context);

      if (result == AudioAccessAction.watchAd) {
        _hasTemporaryAudioAccess = true;
      } else if (result == AudioAccessAction.premium) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Visit Profile screen to upgrade to Premium'),
            duration: Duration(seconds: 3),
          ),
        );
        return;
      } else {
        return; // User cancelled
      }
    }

    try {
      await _gameProvider.inviteToAudioRoom(widget.user.uid!);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Audio room invitation sent!'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send invitation: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
    final List<String> opponentCaptured = isOpponentWhite
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
              // Opponent profile and info (left side)
              ProfileImageWidget(
                imageUrl: null,
                countryCode: 'US',
                radius: 20,
                isEditable: false,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.secondaryContainer,
                placeholderIcon: gameProvider.vsCPU
                    ? Icons.computer
                    : Icons.person,
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isOpponentWhite ? 'P1 (White)' : 'P2 (Black)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    'Rating: ${gameProvider.vsCPU ? [0, 800, 1200, 1600][gameProvider.gameLevel] : 1200}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),

              // Empty space for consistency (center)
              const Expanded(child: SizedBox()),

              // Captured pieces and timer (right side)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isOpponentsTurn
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
                  const SizedBox(height: 4),
                  CapturedPiecesWidget(
                    capturedPieces: opponentCaptured,
                    materialAdvantage: materialAdvantage > 0
                        ? materialAdvantage
                        : 0,
                    isWhite: isOpponentWhite,
                    pieceSet: settingsProvider.getPieceSet(),
                    isCompact: true,
                  ),
                ],
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
    final List<String> playerCaptured = isPlayerWhite
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
              // User profile and info (left side)
              ProfileImageWidget(
                imageUrl: widget.user.photoUrl,
                countryCode: widget.user.countryCode,
                radius: 20,
                isEditable: false,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.user.displayName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    isPlayerWhite ? 'P1 (White)' : 'P2 (Black)',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),

              // Empty space for consistency (center)
              const Expanded(child: SizedBox()),

              // Captured pieces and timer (right side)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isPlayersTurn
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
                  const SizedBox(height: 4),
                  CapturedPiecesWidget(
                    capturedPieces: playerCaptured,
                    materialAdvantage: materialAdvantage > 0
                        ? materialAdvantage
                        : 0,
                    isWhite: gameProvider.player == Squares.white,
                    pieceSet: settingsProvider.getPieceSet(),
                    isCompact: true,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showInGameChat(BuildContext context, GameProvider gameProvider) {
    final opponent = gameProvider.onlineGameRoom?.player1Id == widget.user.uid
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
