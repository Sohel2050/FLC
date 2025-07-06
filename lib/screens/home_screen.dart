import 'package:flutter/material.dart';
import 'package:flutter_chess_app/models/game_room_model.dart';
import 'package:flutter_chess_app/screens/profile_screen.dart';
import 'package:flutter_chess_app/screens/rating_screen.dart';
import 'package:flutter_chess_app/screens/saved_games_screen.dart';
import 'package:flutter_chess_app/screens/statistics_screen.dart';
import 'package:flutter_chess_app/services/user_service.dart';
import 'package:flutter_chess_app/widgets/animated_dialog.dart';
import 'package:flutter_chess_app/widgets/game_invite_dialog.dart';
import 'package:flutter_chess_app/widgets/profile_image_widget.dart';
import 'package:upgrader/upgrader.dart';
import '../models/user_model.dart';
import 'friends_screen.dart';
import 'options_screen.dart';
import 'play_screen.dart';
import 'rules_info_screen.dart';
import 'package:flutter_chess_app/services/game_service.dart';

class HomeScreen extends StatefulWidget {
  final ChessUser user;

  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _selectedTab = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _screens = [
      PlayScreen(user: widget.user),
      FriendsScreen(user: widget.user),
      OptionsScreen(user: widget.user),
    ];
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    final userService = UserService();

    switch (state) {
      case AppLifecycleState.resumed:
        if (!widget.user.isGuest) {
          userService.updateUserStatusOnline(widget.user.uid!, true);
        }
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        if (!widget.user.isGuest) {
          userService.updateUserStatusOnline(widget.user.uid!, false);
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final _gameService = GameService();

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
            // Game Invites Icon
            if (!widget.user.isGuest)
              StreamBuilder<List<GameRoom>>(
                stream: _gameService.streamGameInvites(widget.user.uid!),
                builder: (context, snapshot) {
                  final invites = snapshot.data ?? [];
                  final hasInvites = invites.isNotEmpty;

                  if (!hasInvites) {
                    return SizedBox();
                  }

                  return Stack(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.mail_outline),
                        onPressed: () {
                          AnimatedDialog.show(
                            context: context,
                            title: 'Game Invites',
                            maxWidth: 400,
                            child: GameInvitesDialog(
                              user: widget.user,
                              invites: invites,
                            ),
                          );
                        },
                      ),
                      if (hasInvites)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              '${invites.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'rules') {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const RulesInfoScreen(),
                    ),
                  );
                } else if (value == 'stats') {
                  if (!widget.user.isGuest) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder:
                            (context) => StatisticsScreen(user: widget.user),
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
                } else if (value == 'saved') {
                  if (!widget.user.isGuest) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder:
                            (context) => SavedGamesScreen(user: widget.user),
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
                } else if (value == 'ranking') {
                  if (!widget.user.isGuest) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const RatingScreen(),
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
