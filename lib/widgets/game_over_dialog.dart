import 'dart:async';
import 'package:bishop/bishop.dart' as bishop;
import 'package:flutter/material.dart';
import 'package:flutter_chess_app/models/game_room_model.dart';
import 'package:flutter_chess_app/models/user_model.dart';
import 'package:flutter_chess_app/providers/game_provider.dart';
import 'package:flutter_chess_app/providers/game_provider.dart' as bishop;
import 'package:flutter_chess_app/services/admob_service.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

enum GameOverAction { rematch, newGame, none }

class GameOverDialog extends StatefulWidget {
  final bishop.GameResult? result;
  final ChessUser user;
  final int playerColor;

  const GameOverDialog({
    super.key,
    required this.result,
    required this.user,
    required this.playerColor,
  });

  @override
  State<GameOverDialog> createState() => _GameOverDialogState();
}

class _GameOverDialogState extends State<GameOverDialog> {
  String? _rematchStatus; // e.g., 'waiting', 'rejected'
  Timer? _statusClearTimer;
  late GameProvider gameProvider;
  RewardedAd? _rewardedAd;
  int _rewardedScore = 0;

  @override
  void initState() {
    super.initState();
    gameProvider = context.read<GameProvider>();
    _createRewardedAd();
  }

  @override
  void dispose() {
    _statusClearTimer?.cancel();
    super.dispose();
  }

  void _createRewardedAd() {
    RewardedAd.load(
      adUnitId: AdMobService.getRewardedAdUnitId(context)!,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) => setState(() => _rewardedAd = ad),
        onAdFailedToLoad:
            (LoadAdError error) => setState(() => _rewardedAd = null),
      ),
    );
  }

  bool _isRematchAllowed() {
    // Check if user has removeAds or has watched rewarded ad
    return widget.user.removeAds == true || _rewardedScore > 0;
  }

  String _getResultText(BuildContext context) {
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    final onlineGameRoom = gameProvider.onlineGameRoom;

    if (widget.result == null) return 'Game Over';

    if (widget.result is bishop.WonGame) {
      final winner = (widget.result as bishop.WonGame).winner;
      String winnerName = '';
      if (onlineGameRoom != null) {
        if (onlineGameRoom.player1Color == winner) {
          winnerName = onlineGameRoom.player1DisplayName;
        } else if (onlineGameRoom.player2Color == winner) {
          winnerName = onlineGameRoom.player2DisplayName ?? 'Opponent';
        }
      } else {
        winnerName = (winner == widget.playerColor) ? 'You' : 'Opponent';
      }

      String winType = '';
      if (widget.result is bishop.WonGameCheckmate) {
        winType = 'by Checkmate';
      } else if (widget.result is bishop.WonGameTimeout) {
        winType = 'by Timeout';
      } else if (widget.result is bishop.WonGameResignation) {
        winType = 'by Resignation';
      } else if (widget.result is bishop.WonGameAborted) {
        return 'Game Aborted';
      } else if (widget.result is bishop.WonGameElimination) {
        winType = 'by Elimination';
      } else if (widget.result is bishop.WonGameStalemate) {
        winType = 'by Stalemate (opponent won)';
      } else if (widget.result is bishop.WonGameCheckLimit) {
        winType = 'by Check Limit';
      }

      return '$winnerName Won $winType!';
    } else if (widget.result is bishop.DrawnGame) {
      String drawType = '';
      if (widget.result is bishop.DrawnGameInsufficientMaterial) {
        drawType = 'Insufficient Material';
      } else if (widget.result is bishop.DrawnGameRepetition) {
        drawType = 'Threefold Repetition';
      } else if (widget.result is bishop.DrawnGameLength) {
        drawType = '50-Move Rule';
      } else if (widget.result is bishop.DrawnGameStalemate) {
        drawType = 'Stalemate';
      } else if (widget.result is bishop.DrawnGameElimination) {
        drawType = 'by Elimination';
      } else if (widget.result is DrawnGameAgreement) {
        drawType = 'by Agreement';
      }
      return 'Game Drawn ($drawType)';
    }
    return 'Game Over';
  }

  void _showRematchStatus(String status) {
    setState(() {
      _rematchStatus = status;
    });
    _statusClearTimer?.cancel();
    _statusClearTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _rematchStatus = null;
        });
      }
    });
  }

  void _showRewardedAd() {
    if (_rewardedAd != null) {
      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _createRewardedAd();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _createRewardedAd();
        },
      );
      _rewardedAd!.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
          setState(() {
            _rewardedScore = reward.amount.toInt();
          });
        },
      );

      _rewardedAd = null;
      _createRewardedAd();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, gameProvider, child) {
        final onlineGameRoom = gameProvider.onlineGameRoom;

        // DIALOG DEBUG: Log when dialog rebuilds and game state
        gameProvider.logger.i(
          'DIALOG DEBUG: Dialog rebuilding - gameResult: ${gameProvider.gameResult}, isGameOver: ${gameProvider.isGameOver}',
        );

        // DIALOG DEBUG: Check if dialog should close due to rematch
        if (gameProvider.gameResult == null && !gameProvider.isGameOver) {
          gameProvider.logger.i(
            'DIALOG DEBUG: Game result is null and game is not over - dialog should close',
          );
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              gameProvider.logger.i(
                'DIALOG DEBUG: Closing dialog due to rematch',
              );
              Navigator.of(context).pop();
            }
          });
        }

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
            if (onlineGameRoom != null)
              _buildOnlinePlayerData(context, gameProvider)
            else
              _buildLocalPlayerData(context, widget.user),
            const SizedBox(height: 24),
            if (onlineGameRoom != null)
              _buildRematchSection(context, gameProvider, onlineGameRoom)
            else
              _buildLocalRematchButtons(context, gameProvider),
          ],
        );
      },
    );
  }

  Widget _buildRematchSection(
    BuildContext context,
    GameProvider gameProvider,
    GameRoom onlineGameRoom,
  ) {
    final currentUserId = widget.user.uid;
    final rematchOfferedBy = onlineGameRoom.rematchOfferedBy;

    // Case 1: A rematch offer is active
    if (rematchOfferedBy != null) {
      // Subcase 1.1: The current user sent the offer
      if (rematchOfferedBy == currentUserId) {
        return Column(
          children: [
            const Text('Waiting for opponent...'),
            const SizedBox(height: 10),
            const CircularProgressIndicator(),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () async {
                await gameProvider.handleRematch(false);
                _showRematchStatus('Rematch offer cancelled');
              },
              child: const Text('Cancel Rematch Offer'),
            ),
          ],
        );
      }
      // Subcase 1.2: The opponent sent the offer
      else {
        return Column(
          children: [
            Text(
              '${onlineGameRoom.player1Id == rematchOfferedBy ? onlineGameRoom.player1DisplayName : onlineGameRoom.player2DisplayName ?? 'Opponent'} wants a rematch!',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    await gameProvider.handleRematch(true);
                  },
                  child: const Text('Accept'),
                ),
                OutlinedButton(
                  onPressed: () async {
                    await gameProvider.handleRematch(false);
                    _showRematchStatus('Rematch rejected');
                  },
                  child: const Text('Decline'),
                ),
              ],
            ),
          ],
        );
      }
    }
    // Case 2: No active rematch offer
    else {
      return Column(
        children: [
          if (_rematchStatus != null) ...[
            Text(
              _rematchStatus!,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _isRematchAllowed()
                  ? ElevatedButton(
                    onPressed: () async {
                      await gameProvider.offerRematch();
                    },
                    child: const Text('Rematch'),
                  )
                  : ElevatedButton(
                    onPressed: _rewardedAd != null ? _showRewardedAd : null,
                    child: const Text('Watch Ad for Rematch'),
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
  }

  Widget _buildLocalRematchButtons(
    BuildContext context,
    GameProvider gameProvider,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _isRematchAllowed()
            ? ElevatedButton(
              onPressed: () {
                gameProvider.resetGame(true);
              },
              child: const Text('Rematch'),
            )
            : Column(
              children: [
                ElevatedButton(
                  onPressed: _rewardedAd != null ? _showRewardedAd : null,
                  child: const Text('Watch Ad for Rematch'),
                ),
                const SizedBox(height: 8),
                Text(
                  'Watch an ad to enable rematch',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
        OutlinedButton(
          onPressed: () {
            Navigator.of(context).pop(GameOverAction.newGame);
          },
          child: const Text('New Game'),
        ),
      ],
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

    // final String player1Name = onlineGameRoom.player1DisplayName;
    // final String player2Name = onlineGameRoom.player2DisplayName ?? 'Opponent';

    // final int player1Score = onlineGameRoom.player1Score;
    // final int player2Score = onlineGameRoom.player2Score;

    return Text(
      isHost
          ? 'Your Rating: ${onlineGameRoom.player1Rating}'
          : 'Your Rating: ${onlineGameRoom.player2Rating ?? widget.user.classicalRating}',
      style: Theme.of(context).textTheme.titleMedium,
    );
  }
}
