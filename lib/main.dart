import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chess_app/firebase_options.dart';
import 'package:flutter_chess_app/providers/game_provider.dart';
import 'package:flutter_chess_app/providers/settings_provoder.dart';
import 'package:flutter_chess_app/providers/user_provider.dart';
import 'package:flutter_chess_app/providers/admob_provider.dart';
import 'package:flutter_chess_app/services/migration_service.dart';
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

  /// Show app launch interstitial ad for non-premium users
  void _showAppLaunchAd(ChessUser user) {
    final adMobProvider = Provider.of<AdMobProvider>(context, listen: false);

    // Check if we should show the ad
    if (!adMobProvider.shouldShowAppLaunchAd(user.removeAds)) {
      return;
    }

    // Load and show the ad
    AdMobService.loadAndShowInterstitialAd(
      context: context,
      onAdClosed: () {
        // Mark that we've shown the app launch ad
        adMobProvider.markAppLaunchAdShown();
      },
      onAdFailedToLoad: () {
        // Mark as shown even if failed to prevent retry loops
        adMobProvider.markAppLaunchAdShown();
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

                      // set user online status
                      if (!user.isGuest) {
                        userService.updateUserStatusOnline(user.uid!, true);
                      }

                      // Show app launch ad for non-premium users
                      _showAppLaunchAd(user);
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
