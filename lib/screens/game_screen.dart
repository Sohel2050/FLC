import 'package:flutter/material.dart';
import 'package:flutter_chess_app/models/user_model.dart';
import 'package:flutter_chess_app/providers/game_provider.dart';
import 'package:flutter_chess_app/providers/settings_provoder.dart';
import 'package:flutter_chess_app/widgets/animated_dialog.dart';
import 'package:flutter_chess_app/widgets/captured_piece_widget.dart';
import 'package:flutter_chess_app/widgets/confirmation_dialog.dart';
import 'package:flutter_chess_app/widgets/game_over_dialog.dart';
import 'package:flutter_chess_app/widgets/profile_image_widget.dart';
import 'package:provider/provider.dart';
import 'package:squares/squares.dart';

class GameScreen extends StatefulWidget {
  final ChessUser user;
  const GameScreen({super.key, required this.user});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late GameProvider _gameProvider;

  @override
  void initState() {
    super.initState();
    _gameProvider = context.read<GameProvider>();
    _gameProvider.gameResultNotifier.addListener(_handleGameOver);

    // We make sure to reset the game state when entering the game screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _gameProvider.resetGame(false); // Start the game and timer
    });
  }

  @override
  void dispose() {
    _gameProvider.gameResultNotifier.removeListener(_handleGameOver);
    super.dispose();
  }

  void _handleGameOver() {
    // Check if dialog is already showing to prevent multiple dialogs
    if (ModalRoute.of(context)?.isCurrent != true) {
      return;
    }

    // Only show dialog if game result is not null
    final gameResult = _gameProvider.gameResult;
    if (gameResult == null) return;

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
      if (action == GameOverAction.rematch) {
        _gameProvider.resetGame(true); // Rematch, flip colors
      } else if (action == GameOverAction.newGame) {
        // Navigate back to play screen a completely new game and dispose stockfish
        // Clean up the Stockfish engine before leaving the screen.
        _gameProvider.disposeStockfish();
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    });
  }

  void _onMove(Move move) async {
    // Make a squared move and set the squares state
    await _gameProvider.makeSquaresMove(move);

    // Check if VS CPU mode is enabled
    if (_gameProvider.vsCPU) {
      _gameProvider.makeStockfishMove();
    } else if (_gameProvider.localMultiplayer) {
      // In local multiplayer, no external notification is needed, we just make the move
      // The makeSquaresMove already handles turn switching and timer updates
    } else {
      // If it's an online multiplayer game, notify the opponent about the move
      // This would be done via a WebSocket or similar real-time communication
      print(
        'Move made: ${move.from} to ${move.to} (Online Multiplayer - Placeholder)',
      );
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
      _gameProvider.resignGame();

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
      _gameProvider.resignGame();
      // show game over dialog after resigning
      _handleGameOver();
    }
  }

  /// Shows a confirmation dialog for offering a draw.
  void _showDrawOfferDialog() async {
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
      _gameProvider.offerDraw();
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
                    ? 'Local Multiplayer'
                    : 'Online Game',
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
              ],
            ),
            body: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                // Opponent data, time, and captured pieces
                if (gameProvider.localMultiplayer)
                  _localMultiplayerOpponentDataAndTime(
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
              ],
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
                          'Rating: ${widget.user.classicalRating}',
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
}
