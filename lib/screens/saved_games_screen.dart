import 'package:flutter/material.dart';
import 'package:flutter_chess_app/models/saved_game_model.dart';
import 'package:flutter_chess_app/models/user_model.dart';
import 'package:flutter_chess_app/services/saved_game_service.dart';
import 'package:flutter_chess_app/utils/constants.dart';
import 'package:intl/intl.dart';

class SavedGamesScreen extends StatefulWidget {
  final ChessUser user;

  const SavedGamesScreen({super.key, required this.user});

  @override
  State<SavedGamesScreen> createState() => _SavedGamesScreenState();
}

class _SavedGamesScreenState extends State<SavedGamesScreen> {
  final SavedGameService _savedGameService = SavedGameService();
  late Future<List<SavedGame>> _savedGamesFuture;

  @override
  void initState() {
    super.initState();
    _savedGamesFuture = _savedGameService.getSavedGamesForUser(
      widget.user.uid!,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved Games')),
      body: FutureBuilder<List<SavedGame>>(
        future: _savedGamesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('You have no saved games.'));
          } else {
            final savedGames = snapshot.data!;
            return ListView.builder(
              itemCount: savedGames.length,
              itemBuilder: (context, index) {
                final game = savedGames[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ListTile(
                    title: Text(
                      'vs. ${game.opponentDisplayName} (${game.gameMode})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Result: ${game.result.toUpperCase()}'),
                        Text(
                          'Date: ${DateFormat('MMM d, yyyy HH:mm').format(game.createdAt.toDate())}',
                        ),
                      ],
                    ),
                    trailing: _buildResultIcon(game.result),
                    onTap: () {
                      // TODO: Implement replay functionality
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Replay functionality coming soon!'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }

  Widget _buildResultIcon(String result) {
    IconData icon;
    Color color;
    switch (result) {
      case Constants.win:
        icon = Icons.emoji_events;
        color = Colors.green;
        break;
      case Constants.loss:
        icon = Icons.cancel;
        color = Colors.red;
        break;
      case Constants.draw:
        icon = Icons.handshake;
        color = Colors.blueGrey;
        break;
      default:
        icon = Icons.help_outline;
        color = Colors.grey;
    }
    return Icon(icon, color: color);
  }
}
