import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chess_app/models/game_room_model.dart';
import 'package:flutter_chess_app/providers/game_provider.dart';
import 'package:flutter_chess_app/providers/user_provider.dart';
import 'package:flutter_chess_app/push_notification/notification_service.dart';
import 'package:flutter_chess_app/screens/game_screen.dart';
import 'package:flutter_chess_app/screens/profile_screen.dart';
import 'package:flutter_chess_app/screens/rating_screen.dart';
import 'package:flutter_chess_app/screens/saved_games_screen.dart';
import 'package:flutter_chess_app/screens/statistics_screen.dart';
import 'package:flutter_chess_app/screens/zego_audio_test_screen.dart';
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

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    // Set user online immediately when home screen loads
    _setUserOnline();

    _initializeCloudMessaging();
  }

  @override
  void dispose() {
    // Set user offline when home screen is disposed
    _setUserOffline();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Set user online status
  void _setUserOnline() {
    if (!widget.user.isGuest && widget.user.uid != null) {
      final userService = UserService();
      userService.updateUserStatusOnline(widget.user.uid!, true);
    }
  }

  // Set user offline status
  void _setUserOffline() {
    if (!widget.user.isGuest && widget.user.uid != null) {
      final userService = UserService();
      userService.updateUserStatusOnline(widget.user.uid!, false);
    }
  }

  // Initialize cloud messaging
  void _initializeCloudMessaging() async {
    final userService = UserService();

    await NotificationService.initialize();

    if (Platform.isIOS) {
      if (await NotificationService.isRunningOnIosSimulator()) {
        print("📱 Skipping APNs token setup — running on iOS simulator.");
        return;
      } else {
        // Generate fcmToke
        final fcmToken = await FirebaseMessaging.instance.getToken();

        if (fcmToken != null) {
          await userService.saveFcmToken(fcmToken);
        }
      }
    } else {
      // Generate fcmToke
      final fcmToken = await FirebaseMessaging.instance.getToken();

      if (fcmToken != null) {
        await userService.saveFcmToken(fcmToken);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Only update status for logged-in users
    if (widget.user.isGuest || widget.user.uid == null) {
      return;
    }

    final userService = UserService();

    switch (state) {
      case AppLifecycleState.resumed:
        // App comes to foreground - set user online
        userService.updateUserStatusOnline(widget.user.uid!, true);
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // App goes to background or is minimized - set user offline
        userService.updateUserStatusOnline(widget.user.uid!, false);
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
        playerFlag: widget.user.countryCode ?? '',
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

    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        // Use the current user from the provider, fallback to widget.user if null
        final currentUser = userProvider.user ?? widget.user;

        return UpgradeAlert(
          child: Scaffold(
            appBar: AppBar(
              title: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder:
                              (context) => ProfileScreen(user: currentUser),
                        ),
                      );
                    },
                    child: ProfileImageWidget(
                      imageUrl: currentUser.photoUrl,
                      radius: 24,
                      isEditable: false,
                      countryCode: currentUser.countryCode,
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
                        currentUser.displayName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        'Rating: ${currentUser.classicalRating}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                // IconButton(
                //   icon: const Icon(Icons.star_border),
                //   onPressed: () {
                //     Navigator.push(
                //       context,
                //       MaterialPageRoute(
                //         builder:
                //             (context) => ZegoAudioTestScreen(
                //               userId: widget.user.uid!,
                //               userName: widget.user.displayName,
                //             ),
                //       ),
                //     );
                //   },
                // ),

                // Game Invites Icon
                if (!currentUser.isGuest)
                  StreamBuilder<List<GameRoom>>(
                    stream: gameService.streamGameInvites(currentUser.uid!),
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
                      if (!currentUser.isGuest) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder:
                                (context) =>
                                    StatisticsScreen(user: currentUser),
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
                      if (!currentUser.isGuest) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder:
                                (context) =>
                                    SavedGamesScreen(user: currentUser),
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
                      if (!currentUser.isGuest) {
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
            body: IndexedStack(
              index: _selectedTab,
              children: [
                PlayScreen(user: currentUser, isVisible: _selectedTab == 0),
                FriendsScreen(user: currentUser, isVisible: _selectedTab == 1),
                OptionsScreen(user: currentUser),
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
                NavigationDestination(
                  icon: Icon(Icons.people),
                  label: 'Friends',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings),
                  label: 'Options',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
