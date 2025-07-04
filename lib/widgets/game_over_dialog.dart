import 'package:bishop/bishop.dart' as bishop;
import 'package:flutter/material.dart';
import 'package:flutter_chess_app/models/user_model.dart';
import 'package:flutter_chess_app/providers/game_provider.dart' as bishop;
import 'package:squares/squares.dart';

import 'package:flutter_chess_app/providers/game_provider.dart';
import 'package:provider/provider.dart';

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

  String _getResultText(BuildContext context) {
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    final onlineGameRoom = gameProvider.onlineGameRoom;

    if (result == null) return 'Game Over';

    if (result is bishop.WonGame) {
      final winner = (result as bishop.WonGame).winner;
      String winnerName = '';
      if (onlineGameRoom != null) {
        if (onlineGameRoom.player1Color == winner) {
          winnerName = onlineGameRoom.player1DisplayName;
        } else if (onlineGameRoom.player2Color == winner) {
          winnerName = onlineGameRoom.player2DisplayName ?? 'Opponent';
        }
      } else {
        winnerName = (winner == playerColor) ? 'You' : 'Opponent';
      }

      String winType = '';
      if (result is bishop.WonGameCheckmate) {
        winType = 'by Checkmate';
      } else if (result is bishop.WonGameTimeout) {
        winType = 'by Timeout';
      } else if (result is bishop.WonGameResignation) {
        winType = 'by Resignation';
      } else if (result is bishop.WonGameElimination) {
        winType = 'by Elimination';
      } else if (result is bishop.WonGameStalemate) {
        winType = 'by Stalemate (opponent won)';
      } else if (result is bishop.WonGameCheckLimit) {
        winType = 'by Check Limit';
      }

      return '$winnerName Won $winType!';
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
    return Consumer<GameProvider>(
      builder: (context, gameProvider, child) {
        final onlineGameRoom = gameProvider.onlineGameRoom;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _getResultText(context),
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Display player data for rematch context
            if (onlineGameRoom != null)
              _buildOnlinePlayerData(context, gameProvider)
            else
              _buildLocalPlayerData(context, user),
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
      },
    );
  }

  Widget _buildLocalPlayerData(BuildContext context, ChessUser user) {
    return Column(
      children: [
        Text(
          'Your Rating: ${user.classicalRating}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }

  Widget _buildOnlinePlayerData(
    BuildContext context,
    GameProvider gameProvider,
  ) {
    final onlineGameRoom = gameProvider.onlineGameRoom!;
    final bool isHost = gameProvider.isHost;

    final String player1Name = onlineGameRoom.player1DisplayName;
    final String player2Name = onlineGameRoom.player2DisplayName ?? 'Opponent';

    final int player1Score = onlineGameRoom.player1Score;
    final int player2Score = onlineGameRoom.player2Score;

    return Column(
      children: [
        Text('Scores:', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$player1Name: $player1Score',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(width: 20),
            Text(
              '$player2Name: $player2Score',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          isHost
              ? 'Your Rating: ${onlineGameRoom.player1Rating}'
              : 'Your Rating: ${onlineGameRoom.player2Rating ?? user.classicalRating}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }
}
