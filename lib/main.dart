import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chess_app/firebase_options.dart';
import 'package:flutter_chess_app/providers/game_provider.dart';
import 'package:flutter_chess_app/providers/settings_provoder.dart';
import 'package:flutter_chess_app/providers/user_provider.dart';
import 'package:flutter_chess_app/providers/admob_provider.dart';
import 'package:flutter_chess_app/services/app_open_ad_manager.dart';
import 'package:flutter_chess_app/services/app_launch_ad_coordinator.dart';
import 'package:flutter_chess_app/push_notification/notification_service.dart';
import 'package:logger/logger.dart';
import 'package:flutter_chess_app/screens/home_screen.dart';
import 'package:flutter_chess_app/services/user_service.dart';
import 'package:flutter_chess_app/utils/constants.dart';
import 'package:get_it/get_it.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'screens/login_screen.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'models/user_model.dart';

// Global navigator key for navigation management
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // Handle background message processing here
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();
  setupServiceLocator();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Run database migrations
  //await MigrationService.runMigrations();

  await NotificationService.initialize();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GameProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => AdMobProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

void setupServiceLocator() {
  GetIt.instance.registerSingleton<UserProvider>(UserProvider());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final UserService _userService = UserService();
  final Logger _logger = Logger();

  @override
  void initState() {
    super.initState();
    // Add this widget as an observer for app lifecycle changes
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    // Remove this widget as an observer when disposing
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    try {
      _logger.i('App lifecycle state changed to: $state');

      // Handle app lifecycle changes for session management
      if (mounted && context.mounted) {
        final adMobProvider = Provider.of<AdMobProvider>(
          context,
          listen: false,
        );
        adMobProvider.handleAppLifecycleChange(state);

        _logger.i('Session management handled for lifecycle state: $state');
      }
    } catch (e) {
      _logger.e('Error handling app lifecycle state change: $e');
    }
  }

  /// Initialize app open ad manager for the user
  void _initializeAppOpenAdManager(ChessUser user) {
    try {
      // Validate user before proceeding
      if (user.uid == null || user.uid!.isEmpty) {
        _logger.w('Invalid user for app open ad manager, skipping');
        return;
      }

      // Ensure context is still valid
      if (!mounted) {
        _logger.w(
          'Widget not mounted, skipping app open ad manager initialization',
        );
        return;
      }

      _logger.i('Initializing app open ad manager for user: ${user.uid}');
      AppOpenAdManager.initialize(context, user);
    } catch (e) {
      _logger.e('Error initializing app open ad manager: $e');
    }
  }

  /// Handle app launch ad sequence
  void _handleAppLaunchAd(ChessUser user) {
    try {
      // Validate user before proceeding
      if (user.uid == null || user.uid!.isEmpty) {
        _logger.w('Invalid user for app launch ad, skipping');
        return;
      }

      // Ensure context is still valid
      if (!mounted) {
        _logger.w('Widget not mounted, skipping app launch ad');
        return;
      }

      _logger.i('Handling app launch ad for user: ${user.uid}');

      // Use post-frame callback to ensure UI is ready
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && context.mounted) {
          AppLaunchAdCoordinator.handleAppLaunchAd(
            context: context,
            user: user,
            onComplete: () {
              _logger.i('App launch ad sequence completed');
              // App launch ad sequence is complete, normal app flow continues
            },
          );
        }
      });
    } catch (e) {
      _logger.e('Error handling app launch ad: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'FLC Chess',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B5E20),
          brightness: Brightness.light,
        ),
        // Custom theme adjustments
        appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
        navigationBarTheme: NavigationBarThemeData(
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          elevation: 8,
          backgroundColor: Colors.white,
          shadowColor: Colors.black.withValues(alpha: 0.1),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B5E20),
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData && snapshot.data!.emailVerified) {
            // Instead of calling signIn again, directly fetch user data
            return FutureBuilder<DocumentSnapshot>(
              future:
                  FirebaseFirestore.instance
                      .collection(Constants.usersCollection)
                      .doc(snapshot.data!.uid)
                      .get(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                if (userSnapshot.hasData && userSnapshot.data!.exists) {
                  final user = ChessUser.fromMap(
                    userSnapshot.data!.data() as Map<String, dynamic>,
                  );
                  // Set user in provider
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    final userService = UserService();
                    if (context.mounted) {
                      Provider.of<UserProvider>(
                        context,
                        listen: false,
                      ).setUser(user);

                      // set user online status and cleanup any stale status
                      if (!user.isGuest) {
                        userService.cleanupOnlineStatus(user.uid!);
                      }

                      // Initialize app open ad manager
                      _initializeAppOpenAdManager(user);

                      // Handle app launch ad sequence
                      _handleAppLaunchAd(user);
                    }
                  });

                  return HomeScreen(user: user);
                } else {
                  // User document doesn't exist, sign out
                  _userService.signOut();
                  return const LoginScreen();
                }
              },
            );
          }
          return const LoginScreen();
        },
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
