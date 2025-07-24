import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chess_app/providers/user_provider.dart';
import 'package:flutter_chess_app/screens/chat_screen.dart';
import 'package:flutter_chess_app/screens/friends_screen.dart';
import 'package:flutter_chess_app/services/user_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';

// A global navigator key is needed to navigate from a background service
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class NotificationService {
  static final FlutterLocalNotificationsPlugin
  _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;
  static final UserService _userService = GetIt.instance<UserService>();

  static final AndroidNotificationChannel _chatChannel =
      const AndroidNotificationChannel(
        'chat_messages_channel',
        'Chat Messages',
        description: 'This channel is used for chat message notifications.',
        importance: Importance.max,
      );

  static final AndroidNotificationChannel _friendRequestChannel =
      const AndroidNotificationChannel(
        'friend_requests_channel',
        'Friend Requests',
        description: 'This channel is used for friend request notifications.',
        importance: Importance.high,
      );

  static Future<void> initialize() async {
    // Create notification channels
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_chatChannel);

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_friendRequestChannel);

    // Initialization settings for local notifications
    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: onNotificationTapped,
      onDidReceiveBackgroundNotificationResponse: onNotificationTapped,
    );

    // Request permissions for iOS
    await _firebaseMessaging.requestPermission();

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message);
    });

    // Handle background/terminated messages that are tapped
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleMessage(message.data);
    });

    // Handle initial message if app is opened from a terminated state
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        _handleMessage(message.data);
      }
    });
  }

  static void _showLocalNotification(RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;
    Map<String, dynamic> data = message.data;

    if (notification != null && android != null) {
      _flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _getChannel(data['type']).id,
            _getChannel(data['type']).name,
            channelDescription: _getChannel(data['type']).description,
            icon: android.smallIcon,
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
          ),
        ),
        payload: jsonEncode(data),
      );
    }
  }

  static AndroidNotificationChannel _getChannel(String? type) {
    switch (type) {
      case 'chat':
        return _chatChannel;
      case 'friend_request':
      case 'friend_request_accepted':
        return _friendRequestChannel;
      default:
        return _chatChannel; // Default channel
    }
  }

  static void onNotificationTapped(NotificationResponse notificationResponse) {
    if (notificationResponse.payload != null) {
      final Map<String, dynamic> data = jsonDecode(
        notificationResponse.payload!,
      );
      _handleMessage(data);
    }
  }

  static Future<void> _handleMessage(Map<String, dynamic> data) async {
    final String? type = data['type'];
    final BuildContext? context = navigatorKey.currentContext;

    if (context == null) return;

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentUser = userProvider.user;

    if (currentUser == null) return;

    switch (type) {
      case 'chat':
        final String? senderId = data['senderId'];
        if (senderId != null) {
          final otherUser = await _userService.getUserById(senderId);
          if (otherUser != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) => ChatScreen(
                      currentUser: currentUser,
                      otherUser: otherUser,
                    ),
              ),
            );
          }
        }
        break;
      case 'friend_request':
      case 'friend_request_accepted':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) =>
                    FriendsScreen(user: currentUser, initialTabIndex: 1),
          ),
        );
        break;
    }
  }
}
