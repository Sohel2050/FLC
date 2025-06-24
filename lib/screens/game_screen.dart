import 'dart:math';
import 'package:flutter/material.dart';
import 'package:bishop/bishop.dart' as bishop;
import 'package:flutter_chess_app/models/user_model.dart';
import 'package:flutter_chess_app/widgets/profile_image_widget.dart';
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
                    imageUrl: null, // No image for CPU
                    radius: 20,
                    isEditable: false,
                    backgroundColor:
                        Theme.of(context).colorScheme.secondaryContainer,
                    placeholderIcon: Icons.computer,
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.vsCPU
                            ? 'CPU'
                            : 'Opponent Name', // Placeholder for opponent name
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        'Rating: 1200', // Placeholder for opponent rating
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    widget.timeControl,
                    style: Theme.of(context).textTheme.titleLarge,
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
                  Text(
                    widget.timeControl,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            OutlinedButton(
              onPressed: _resetGame,
              child: const Text('New Game'),
            ),
            IconButton(
              onPressed: _flipBoard,
              icon: const Icon(Icons.rotate_left),
            ),
          ],
        ),
      ),
    );
  }
}
