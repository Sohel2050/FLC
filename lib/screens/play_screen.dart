import 'package:flutter/material.dart';
import 'package:flutter_chess_app/utils/constants.dart';
import 'package:flutter_chess_app/widgets/profile_image_widget.dart';
import '../models/user_model.dart';
import '../widgets/game_mode_card.dart';
import '../widgets/custom_button.dart';

class PlayScreen extends StatefulWidget {
  final ChessUser user;

  const PlayScreen({super.key, required this.user});

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> {
  int _selectedGameMode = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Game Modes Carousel
          SizedBox(
            height: 180,
            child: PageView.builder(
              controller: PageController(viewportFraction: 0.8),
              onPageChanged: (index) {
                setState(() {
                  _selectedGameMode = index;
                });
              },
              itemCount: Constants.gameModes.length,
              itemBuilder: (context, index) {
                final mode = Constants.gameModes[index];
                return GameModeCard(
                  title: mode[Constants.title],
                  timeControl: mode[Constants.timeControl],
                  icon: mode[Constants.icon],
                  isSelected: _selectedGameMode == index,
                  onTap: () {
                    setState(() {
                      _selectedGameMode = index;
                    });
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 32),
          Spacer(),

          // Play Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                PlayModeButton(
                  text: 'Play Online',
                  icon: Icons.public,
                  onPressed: () {
                    // TODO: Implement online play
                  },
                  isFullWidth: true,
                ),
                const SizedBox(height: 16),
                PlayModeButton(
                  text: 'Play vs CPU',
                  icon: Icons.computer,
                  onPressed: () {
                    // TODO: Implement CPU play
                  },
                  isPrimary: false,
                  isFullWidth: true,
                ),
                const SizedBox(height: 16),
                PlayModeButton(
                  text: 'Local Multiplayer',
                  icon: Icons.people,
                  onPressed: () {
                    // TODO: Implement local multiplayer
                  },
                  isPrimary: false,
                  isFullWidth: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
