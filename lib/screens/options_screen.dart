import 'package:flutter/material.dart';
import 'package:flutter_chess_app/providers/settings_provoder.dart';
import 'package:provider/provider.dart';
import 'package:squares/squares.dart';
import '../models/user_model.dart';

class OptionsScreen extends StatelessWidget {
  final ChessUser user;

  const OptionsScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.read<SettingsProvider>();

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
              // TODO: Need to add sharing logic here
            },
          ),
          _buildListTile(
            title: 'Invite a Friend',
            icon: Icons.person_add,
            onTap: () {
              // TODO: Need to add friend invitation logic here
            },
          ),
          _buildListTile(
            title: 'Community Poll',
            icon: Icons.poll,
            onTap: () {
              // TODO: Need to add community poll logic here
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
              DropdownMenuItem(value: 'xiangqi', child: Text('Xiangqi')),
              DropdownMenuItem(
                value: 'xiangqiIcons',
                child: Text('Xiangqi Icons'),
              ),
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
