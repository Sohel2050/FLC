import 'package:flutter/material.dart';
import 'package:flutter_chess_app/screens/profile_screen.dart';
import 'package:flutter_chess_app/widgets/profile_image_widget.dart';
import 'package:upgrader/upgrader.dart';
import '../models/user_model.dart';
import 'friends_screen.dart';
import 'options_screen.dart';
import 'play_screen.dart';
import 'rules_info_screen.dart';

class HomeScreen extends StatefulWidget {
  final ChessUser user;

  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedTab = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      PlayScreen(user: widget.user),
      FriendsScreen(user: widget.user),
      OptionsScreen(user: widget.user),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return UpgradeAlert(
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ProfileScreen(user: widget.user),
                    ),
                  );
                },
                child: ProfileImageWidget(
                  imageUrl: widget.user.photoUrl,
                  radius: 24,
                  isEditable: false,
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                ),
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
                if (value == 'rules') {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const RulesInfoScreen(),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('This feature requires an account.'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
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
        body: IndexedStack(index: _selectedTab, children: _screens),
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
      ),
    );
  }
}
