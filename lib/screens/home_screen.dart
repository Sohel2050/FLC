import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../widgets/game_mode_card.dart';
import '../widgets/custom_button.dart';

class HomeScreen extends StatefulWidget {
  final ChessUser user;

  const HomeScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedGameMode = 0;
  int _selectedTab = 0;

  final List<Map<String, dynamic>> _gameModes = [
    {'title': 'Classical', 'timeControl': '60 sec/move', 'icon': Icons.timer},
    {'title': 'Blitz', 'timeControl': '5 min + 3 sec', 'icon': Icons.bolt},
    {'title': 'Tempo', 'timeControl': '20 sec/move', 'icon': Icons.speed},
    {'title': 'Quick Blitz', 'timeControl': '3 min', 'icon': Icons.flash_on},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage:
                  widget.user.photoUrl != null
                      ? NetworkImage(widget.user.photoUrl!)
                      : null,
              child:
                  widget.user.photoUrl == null
                      ? const Icon(Icons.person)
                      : null,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
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
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              // TODO: Handle menu item selection
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: 'rules',
                    child: Text('Game Rules'),
                  ),
                  const PopupMenuItem(
                    value: 'stats',
                    child: Text('Statistics'),
                  ),
                  const PopupMenuItem(
                    value: 'saved',
                    child: Text('Saved Games'),
                  ),
                  const PopupMenuItem(
                    value: 'ranking',
                    child: Text('Rankings'),
                  ),
                ],
          ),
        ],
      ),
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
              itemCount: _gameModes.length,
              itemBuilder: (context, index) {
                final mode = _gameModes[index];
                return GameModeCard(
                  title: mode['title'],
                  timeControl: mode['timeControl'],
                  icon: mode['icon'],
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

          // Play Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                CustomButton(
                  text: 'Play Online',
                  icon: Icons.public,
                  onPressed: () {
                    // TODO: Implement online play
                  },
                  isFullWidth: true,
                ),
                const SizedBox(height: 16),
                CustomButton(
                  text: 'Play vs CPU',
                  icon: Icons.computer,
                  onPressed: () {
                    // TODO: Implement CPU play
                  },
                  isPrimary: false,
                  isFullWidth: true,
                ),
                const SizedBox(height: 16),
                CustomButton(
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: (index) {
          setState(() {
            _selectedTab = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.sports_esports),
            label: 'Play',
          ),
          NavigationDestination(icon: Icon(Icons.people), label: 'Friends'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Options'),
        ],
      ),
    );
  }
}
