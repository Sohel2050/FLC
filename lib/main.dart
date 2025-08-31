import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chess_app/firebase_options.dart';
import 'package:flutter_chess_app/providers/game_provider.dart';
import 'package:flutter_chess_app/providers/settings_provoder.dart';
import 'package:flutter_chess_app/providers/user_provider.dart';
import 'package:flutter_chess_app/providers/admob_provider.dart';
import 'package:flutter_chess_app/services/admob_service.dart';
import 'package:flutter_chess_app/push_notification/notification_service.dart';
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

  print("Handling a background message: ${message.messageId}");
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

class _MyAppState extends State<MyApp> {
  final UserService _userService = UserService();

  /// Show app launch ad for non-premium users and guest users
  void _showAppLaunchAd(ChessUser user) async {
    final adMobProvider = Provider.of<AdMobProvider>(context, listen: false);

    // Wait for AdMob config to load if it's not already loaded
    if (adMobProvider.adMobConfig == null) {
      await adMobProvider.loadAdMobConfig();
    }

    // Use improved guest user ad logic
    bool shouldShowAd;
    if (user.isGuest) {
      shouldShowAd = adMobProvider.shouldShowAppLaunchAdForGuestUser(user);
    } else {
      shouldShowAd = adMobProvider.shouldShowAppLaunchAd(user.removeAds);
    }

    // Check if we should show the ad
    if (!shouldShowAd) {
      return;
    }

    // Set loading state
    adMobProvider.setInterstitialAdLoading(true);

    // Load and show the app open ad with proper error handling for guest users
    AdMobService.loadAndShowAppOpenAd(
      context: context,
      user: user,
      onAdClosed: () {
        // Clear loading state
        adMobProvider.setInterstitialAdLoading(false);
      },
      onAdFailedToLoad: () {
        // Clear loading state even if failed
        adMobProvider.setInterstitialAdLoading(false);
      },
    );
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

          if (snapshot.hasData) {
            final user = snapshot.data!;

            // Handle anonymous users (guest users)
            if (user.isAnonymous) {
              return FutureBuilder<ChessUser>(
                future: _userService.handleAnonymousUserSession(user),
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (userSnapshot.hasData) {
                    final chessUser = userSnapshot.data!;
                    // Set user in provider
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (context.mounted) {
                        Provider.of<UserProvider>(
                          context,
                          listen: false,
                        ).setUser(chessUser);

                        // Show app launch ad for guest users
                        _showAppLaunchAd(chessUser);
                      }
                    });

                    return HomeScreen(user: chessUser);
                  } else {
                    // Failed to handle anonymous user, go to login
                    return const LoginScreen();
                  }
                },
              );
            }

            // Handle verified email users
            if (user.emailVerified) {
              return FutureBuilder<DocumentSnapshot>(
                future:
                    FirebaseFirestore.instance
                        .collection(Constants.usersCollection)
                        .doc(user.uid)
                        .get(),
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (userSnapshot.hasData && userSnapshot.data!.exists) {
                    final chessUser = ChessUser.fromMap(
                      userSnapshot.data!.data() as Map<String, dynamic>,
                    );
                    // Set user in provider
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      final userService = UserService();
                      if (context.mounted) {
                        Provider.of<UserProvider>(
                          context,
                          listen: false,
                        ).setUser(chessUser);

                        // set user online status and cleanup any stale status
                        if (!chessUser.isGuest) {
                          userService.cleanupOnlineStatus(chessUser.uid!);
                        }

                        // Show app launch ad for non-premium users
                        _showAppLaunchAd(chessUser);
                      }
                    });

                    return HomeScreen(user: chessUser);
                  } else {
                    // User document doesn't exist, sign out
                    _userService.signOut();
                    return const LoginScreen();
                  }
                },
              );
            }
          }

          return const LoginScreen();
        },
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
