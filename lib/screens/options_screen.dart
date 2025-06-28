import 'package:flutter/material.dart';
import 'package:flutter_chess_app/providers/settings_provoder.dart';
import 'package:provider/provider.dart';
import 'package:squares/squares.dart';
import 'package:share_plus/share_plus.dart';
import 'package:in_app_review/in_app_review.dart';
import '../models/user_model.dart';

class OptionsScreen extends StatelessWidget {
  final ChessUser user;

  const OptionsScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Options')),
      body: ListView(
        children: [
          _buildSectionHeader('Appearance'),
          _buildBoardThemeDropdown(context, settingsProvider),
          _buildPieceSetDropdown(context, settingsProvider),
          _buildToggleSwitch(
            title: 'Show Board Labels',
            value: settingsProvider.showLabels,
            onChanged: (value) => settingsProvider.setShowLabels(value),
          ),
          _buildToggleSwitch(
            title: 'Animate Pieces',
            value: settingsProvider.animatePieces,
            onChanged: (value) => settingsProvider.setAnimatePieces(value),
          ),
          const Divider(),
          _buildSectionHeader('Community & Sharing'),
          _buildListTile(
            title: 'Share the App',
            icon: Icons.share,
            onTap: () {
              final appLink =
                  'https://example.com/chess-app'; // Replace with your app link
              SharePlus.instance.share(
                ShareParams(
                  title: 'FLC Chess App',
                  subject: 'Check out this awesome Chess App!',
                  text:
                      "I found this amazing Chess App that I think you'll love! \n$appLink",
                ),
              );
            },
          ),
          _buildListTile(
            title: 'Invite a Friend',
            icon: Icons.person_add,
            onTap: () {
              final appLink =
                  'https://example.com/chess-app'; // Replace with your app link
              SharePlus.instance.share(
                ShareParams(
                  title: 'FLC Chess App',
                  subject: 'Join me on this amazing Chess App!',
                  text: "Join me on this amazing Chess App! \n$appLink",
                ),
              );
            },
          ),
          _buildListTile(
            title: 'Community Poll',
            icon: Icons.poll,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Community Polls coming soon with Firebase integration!',
                  ),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          const Divider(),
          _buildSectionHeader('App Actions'),
          _buildListTile(
            title: 'Notifications',
            icon: Icons.notifications,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Notifications feature coming soon!'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          _buildListTile(
            title: 'Rate the App',
            icon: Icons.star,
            onTap: () async {
              final InAppReview inAppReview = InAppReview.instance;
              if (await inAppReview.isAvailable()) {
                inAppReview.requestReview();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'In-app review is not available on this device.',
                    ),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
          const Divider(),
          _buildSectionHeader('About'),
          _buildListTile(
            title: 'Privacy Policy',
            icon: Icons.privacy_tip,
            onTap: () {
              // TODO: Need to add logic to show your privacy policy
            },
          ),
        ],
      ),
    );
  }

  // Helper methods to build UI components
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildBoardThemeDropdown(
    BuildContext context,
    SettingsProvider provider,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Board Theme'),
          DropdownButton<BoardTheme>(
            value: provider.boardTheme,
            onChanged: (BoardTheme? newTheme) {
              if (newTheme != null) {
                provider.setBoardTheme(newTheme);
              }
            },
            items: [
              const DropdownMenuItem(
                value: BoardTheme.brown,
                child: Text('Brown'),
              ),
              const DropdownMenuItem(
                value: BoardTheme.blueGrey,
                child: Text('Blue Grey'),
              ),
              const DropdownMenuItem(
                value: BoardTheme.pink,
                child: Text('Pink'),
              ),
              const DropdownMenuItem(
                value: BoardTheme.dart,
                child: Text('Dart'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPieceSetDropdown(
    BuildContext context,
    SettingsProvider provider,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Piece Set'),
          DropdownButton<String>(
            value: provider.pieceSet,
            onChanged: (String? newPieceSet) {
              if (newPieceSet != null) {
                provider.setPieceSet(newPieceSet);
              }
            },
            items: const [
              DropdownMenuItem(value: 'merida', child: Text('Merida')),
              DropdownMenuItem(value: 'letters', child: Text('Letters')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToggleSwitch({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(title),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _buildListTile({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ListTile(leading: Icon(icon), title: Text(title), onTap: onTap);
  }
}
