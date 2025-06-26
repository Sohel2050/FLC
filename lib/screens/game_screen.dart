import 'package:flutter/material.dart';
import 'package:flutter_chess_app/models/user_model.dart';
import 'package:flutter_chess_app/providers/game_provider.dart';
import 'package:flutter_chess_app/widgets/animated_dialog.dart';
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
        // Navigate back to play screen or home screen for a completely new game
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
      _gameProvider.makeRandomMove();
    } else {
      // If it's a multiplayer game, notify the opponent about the move
      // This could be done via a WebSocket or similar real-time communication
      // For now, we just print the move
      print('Move made: ${move.from} to ${move.to}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, gameProvider, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Game Screen')),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Opponent (CPU or Human) data and time
                _opponentsDataAndTime(context, gameProvider),

                Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: BoardController(
                    state:
                        gameProvider.flipBoard
                            ? gameProvider.state.board.flipped()
                            : gameProvider.state.board,
                    playState: gameProvider.state.state,
                    pieceSet: PieceSet.merida(),
                    theme: BoardTheme.brown,
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

                // Current user data and time
                _currentUserDataAndTime(context, gameProvider),

                const SizedBox(height: 32),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: () => gameProvider.resetGame(true),
                      child: const Text('New Game'),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      onPressed: gameProvider.flipTheBoard,
                      icon: const Icon(Icons.rotate_left),
                      tooltip: 'Flip Board',
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  _opponentsDataAndTime(BuildContext context, GameProvider gameProvider) {
    // Determine opponent's color based on player's color
    final int opponentColor =
        gameProvider.player == Squares.white ? Squares.black : Squares.white;

    // Determine if it's the opponent's turn
    final bool isOpponentsTurn = gameProvider.game.state.turn == opponentColor;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          ProfileImageWidget(
            imageUrl: null,
            radius: 20,
            isEditable: false,
            backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
            placeholderIcon: gameProvider.vsCPU ? Icons.computer : Icons.person,
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
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
    );
  }

  Padding _currentUserDataAndTime(
    BuildContext context,
    GameProvider gameProvider,
  ) {
    // Determine if it's the current player's turn
    final bool isPlayersTurn =
        gameProvider.game.state.turn == gameProvider.player;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          ProfileImageWidget(
            imageUrl: widget.user.photoUrl,
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
                'Rating: ${widget.user.classicalRating}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
    );
  }
}
