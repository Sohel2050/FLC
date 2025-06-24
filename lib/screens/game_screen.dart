import 'dart:math';
import 'package:flutter/material.dart';
import 'package:bishop/bishop.dart' as bishop;
import 'package:flutter_chess_app/models/user_model.dart';
import 'package:flutter_chess_app/providers/game_provider.dart';
import 'package:flutter_chess_app/widgets/profile_image_widget.dart';
import 'package:provider/provider.dart';
import 'package:squares/squares.dart';
import 'package:square_bishop/square_bishop.dart';

class GameScreen extends StatefulWidget {
  final ChessUser user;
  final String timeControl;
  final bool vsCPU;
  const GameScreen({
    super.key,
    required this.user,
    required this.timeControl,
    this.vsCPU = false,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late bishop.Game game;
  late SquaresState state;
  int player = Squares.white;
  bool aiThinking = false;
  bool flipBoard = false;

  @override
  void initState() {
    _resetGame(false);
    super.initState();
  }

  void _resetGame([bool ss = true]) {
    game = bishop.Game(variant: bishop.Variant.standard());
    state = game.squaresState(player);
    if (ss) setState(() {});
  }

  void _flipBoard() => setState(() => flipBoard = !flipBoard);

  void _onMove(Move move) async {
    bool result = game.makeSquaresMove(move);
    if (result) {
      setState(() => state = game.squaresState(player));
    }
    if (state.state == PlayState.theirTurn && !aiThinking) {
      setState(() => aiThinking = true);
      await Future.delayed(
        Duration(milliseconds: Random().nextInt(4750) + 250),
      );
      game.makeRandomMove();
      setState(() {
        aiThinking = false;
        state = game.squaresState(player);
      });
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
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      ProfileImageWidget(
                        imageUrl: null,
                        radius: 20,
                        isEditable: false,
                        backgroundColor:
                            Theme.of(context).colorScheme.secondaryContainer,
                        placeholderIcon:
                            widget.vsCPU ? Icons.computer : Icons.person,
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.vsCPU
                                ? 'CPU (${['', 'Easy', 'Normal', 'Hard'][gameProvider.gameLevel]})'
                                : 'Opponent Name',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            'Rating: ${widget.vsCPU ? [0, 800, 1200, 1600][gameProvider.gameLevel] : 1200}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          gameProvider.getFormattedTime(
                            player == Squares.white
                                ? gameProvider.blacksTime
                                : gameProvider.whitesTime,
                          ),
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontFamily: 'monospace'),
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: BoardController(
                    state: flipBoard ? state.board.flipped() : state.board,
                    playState: state.state,
                    pieceSet: PieceSet.merida(),
                    theme: BoardTheme.brown,
                    moves: state.moves,
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
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      ProfileImageWidget(
                        imageUrl: widget.user.photoUrl,
                        radius: 20,
                        isEditable: false,
                        backgroundColor:
                            Theme.of(context).colorScheme.primaryContainer,
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          gameProvider.getFormattedTime(
                            player == Squares.white
                                ? gameProvider.whitesTime
                                : gameProvider.blacksTime,
                          ),
                          style: Theme.of(
                            context,
                          ).textTheme.titleLarge?.copyWith(
                            fontFamily: 'monospace',
                            color:
                                Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: _resetGame,
                      child: const Text('New Game'),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      onPressed: _flipBoard,
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
}
