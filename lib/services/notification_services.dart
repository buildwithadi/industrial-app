import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    // 1. Setup Android Settings (Icon must exist in drawable/mipmap)
    // Ensure '@mipmap/ic_launcher' is present in your project's Android resources.
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // 2. Initialization Settings
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    // 3. Initialize the plugin
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // This handles what happens when a user taps the notification.
        // You can add navigation logic here to open a specific unit's detail screen.
      },
    );

    _isInitialized = true;
  }

  /// CRITICAL: Request notification permissions for Android 13+ (API 33+)
  /// This must be called from the UI (e.g., in Dashboard initState) on newer Android devices.
  Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      await androidImplementation?.requestNotificationsPermission();
    }
  }

  Future<void> showNotification(int id, String title, String body) async {
    // Define a high-priority channel
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'industrial_alerts_channel', // Channel ID (keep this constant)
      'Critical Sensor Alerts', // Channel Name (visible to user in settings)
      channelDescription: 'Notifications for sensor threshold alerts',
      importance: Importance
          .max, // MAX importance makes it pop up (heads-up notification)
      priority:
          Priority.high, // HIGH priority ensures the system prioritizes it
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      platformChannelSpecifics,
    );
  }
}
