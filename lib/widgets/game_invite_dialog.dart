import 'package:flutter/material.dart';
import 'package:flutter_chess_app/models/game_room_model.dart';
import 'package:flutter_chess_app/models/user_model.dart';
import 'package:flutter_chess_app/providers/game_provider.dart';
import 'package:flutter_chess_app/screens/game_screen.dart';
import 'package:provider/provider.dart';
import 'package:flutter_chess_app/widgets/loading_dialog.dart';

class GameInvitesDialog extends StatelessWidget {
  final ChessUser user;
  final List<GameRoom> invites;

  const GameInvitesDialog({
    super.key,
    required this.user,
    required this.invites,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (invites.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32.0),
            child: Text('No pending invites', style: TextStyle(fontSize: 16)),
          )
        else
          ...invites.map((invite) => _buildInviteCard(context, invite)),
      ],
    );
  }

  Widget _buildInviteCard(BuildContext context, GameRoom invite) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage:
                      invite.player1PhotoUrl != null
                          ? NetworkImage(invite.player1PhotoUrl!)
                          : null,
                  child:
                      invite.player1PhotoUrl == null
                          ? const Icon(Icons.person)
                          : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invite.player1DisplayName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        'Rating: ${invite.player1Rating}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Game Mode: ${invite.gameMode}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _declineInvite(context, invite),
                  child: const Text('Decline'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _acceptInvite(context, invite),
                  child: const Text('Accept'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _acceptInvite(BuildContext context, GameRoom invite) async {
    final gameProvider = context.read<GameProvider>();

    try {
      Navigator.of(context).pop(); // Close dialog

      // Show loading
      LoadingDialog.show(
        context,
        message: 'Joining game...',
        barrierDismissible: false,
      );

      // Set up the game
      bool isAvailable = await gameProvider.joinPrivateGameRoom(
        context: context,
        userId: user.uid!,
        displayName: user.displayName,
        photoUrl: user.photoUrl,
        userRating: user.classicalRating,
        gameMode: invite.gameMode,
      );

      if (context.mounted) {
        LoadingDialog.hide(context);

        if (isAvailable) {
          // Lets have a small delay to ensure UI is updated
          await Future.delayed(const Duration(milliseconds: 500));
          // Navigate to game
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => GameScreen(user: user)),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        LoadingDialog.hide(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to join game: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _declineInvite(BuildContext context, GameRoom invite) async {
    final gameProvider = context.read<GameProvider>();

    try {
      Navigator.of(context).pop(); // Close dialog

      await gameProvider.declineGameInvite(invite.gameId, user.uid!);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invite declined'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to decline invite: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
