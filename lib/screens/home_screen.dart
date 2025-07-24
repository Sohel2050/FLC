import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chess_app/models/game_room_model.dart';
import 'package:flutter_chess_app/providers/game_provider.dart';
import 'package:flutter_chess_app/screens/game_screen.dart';
import 'package:flutter_chess_app/screens/profile_screen.dart';
import 'package:flutter_chess_app/screens/rating_screen.dart';
import 'package:flutter_chess_app/screens/saved_games_screen.dart';
import 'package:flutter_chess_app/screens/statistics_screen.dart';
import 'package:flutter_chess_app/services/user_service.dart';
import 'package:flutter_chess_app/widgets/animated_dialog.dart';
import 'package:flutter_chess_app/widgets/loading_dialog.dart';
import 'package:flutter_chess_app/widgets/profile_image_widget.dart';
import 'package:provider/provider.dart';
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

    _initializeCloudMessaging();

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

  // Initialize cloud messaging
  void _initializeCloudMessaging() async {
    final userService = UserService();

    // Generate fcmToke
    final fcmToken = await FirebaseMessaging.instance.getToken();

    if (fcmToken != null) {
      await userService.saveFcmToken(fcmToken);
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');

      if (message.notification != null) {
        print('Message also contained a notification: ${message.notification}');
      }
    });
  }

  // setup notification interaction
  // It is assumed that all messages contain a data field with the key 'type'
  Future<void> setupInteractedMessage() async {
    // Get any messages which caused the application to open from
    // a terminated state.
    RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();

    // If the message also contains a data property with a "type" of "chat",
    // navigate to a chat screen
    if (initialMessage != null) {
      _handleMessage(initialMessage);
    }

    // Also handle any interaction when the app is in the background via a
    // Stream listener
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);
  }

  void _handleMessage(RemoteMessage message) {
    if (message.data['type'] == 'chat') {
      // Navigate to chat messages
    }
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
                ProfileImageWidget(
                  imageUrl: invite.player1PhotoUrl,
                  radius: 20,
                  isEditable: false,
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
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
        userId: widget.user.uid!,
        displayName: widget.user.displayName,
        photoUrl: widget.user.photoUrl,
        userRating: widget.user.classicalRating,
        gameMode: invite.gameMode,
      );

      if (context.mounted) {
        LoadingDialog.updateMessage(context, 'Game ready! Starting...');
      }

      if (isAvailable) {
        // Lets have a small delay to ensure UI is updated
        await Future.delayed(const Duration(milliseconds: 500));

        if (context.mounted) {
          LoadingDialog.hide(context);
          // Navigate to game
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GameScreen(user: widget.user),
            ),
          );
        }
      } else {
        if (context.mounted) {
          LoadingDialog.hide(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Game not found or is no longer available.'),
              backgroundColor: Colors.orange,
            ),
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

      await gameProvider.declineGameInvite(invite.gameId, widget.user.uid!);

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

  @override
  Widget build(BuildContext context) {
    final gameService = GameService();

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
                stream: gameService.streamGameInvites(widget.user.uid!),
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
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (invites.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.all(32.0),
                                    child: Text(
                                      'No pending invites',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                  )
                                else
                                  ...invites.map(
                                    (invite) =>
                                        _buildInviteCard(context, invite),
                                  ),
                              ],
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
