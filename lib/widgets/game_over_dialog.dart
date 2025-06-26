import 'package:bishop/bishop.dart' as bishop;
import 'package:flutter/material.dart';
import 'package:flutter_chess_app/models/user_model.dart';
import 'package:squares/squares.dart';

import '../providers/game_provider.dart' as bishop;

enum GameOverAction { rematch, newGame, none }

class GameOverDialog extends StatelessWidget {
  final bishop.GameResult? result;
  final ChessUser user;
  final int playerColor;

  const GameOverDialog({
    super.key,
    required this.result,
    required this.user,
    required this.playerColor,
  });

  String _getResultText() {
    if (result == null) return 'Game Over';

    if (result is bishop.WonGame) {
      final winner = (result as bishop.WonGame).winner;
      final winnerColor = winner == Squares.white ? 'White' : 'Black';
      final isPlayerWinner =
          (winner == Squares.white && playerColor == Squares.white) ||
          (winner == Squares.black && playerColor == Squares.black);

      String winType = '';
      if (result is bishop.WonGameCheckmate) {
        winType = 'by Checkmate';
      } else if (result is bishop.WonGameTimeout) {
        winType = 'by Timeout';
      } else if (result is bishop.WonGameElimination) {
        winType = 'by Elimination';
      } else if (result is bishop.WonGameStalemate) {
        winType = 'by Stalemate (opponent won)';
      } else if (result is bishop.WonGameCheckLimit) {
        winType = 'by Check Limit';
      }

      return isPlayerWinner
          ? 'You Won $winType!'
          : '$winnerColor Won $winType!';
    } else if (result is bishop.DrawnGame) {
      String drawType = '';
      if (result is bishop.DrawnGameInsufficientMaterial) {
        drawType = 'Insufficient Material';
      } else if (result is bishop.DrawnGameRepetition) {
        drawType = 'Threefold Repetition';
      } else if (result is bishop.DrawnGameLength) {
        drawType = '50-Move Rule';
      } else if (result is bishop.DrawnGameStalemate) {
        drawType = 'Stalemate';
      } else if (result is bishop.DrawnGameElimination) {
        drawType = 'by Elimination';
      }
      return 'Game Drawn ($drawType)';
    }
    return 'Game Over';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _getResultText(),
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        // Display player data for rematch context
        _buildPlayerData(context, user, playerColor),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            ElevatedButton(
              onPressed:
                  () => Navigator.of(context).pop(GameOverAction.rematch),
              child: const Text('Rematch'),
            ),
            OutlinedButton(
              onPressed:
                  () => Navigator.of(context).pop(GameOverAction.newGame),
              child: const Text('New Game'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPlayerData(
    BuildContext context,
    ChessUser user,
    int playerColor,
  ) {
    return Column(
      children: [
        Text(
          'Your Rating: ${user.classicalRating}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        // Add more player data if needed for rematch context
      ],
    );
  }
}
