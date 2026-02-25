import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'dart:io';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  static NotificationService get instance => _instance;

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  NotificationService._();

  Future<void> initialize() async {
    tz.initializeTimeZones();
    final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneInfo.identifier));

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
          requestSoundPermission: true,
          requestBadgePermission: true,
          requestAlertPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
          macOS: initializationSettingsDarwin,
        );

    await _flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tapped logic here if needed
        print("Notification tapped: ${response.payload}");
      },
    );

    // Request permissions and schedule after UI has successfully rendered
    Future.delayed(const Duration(seconds: 2), () async {
      await _requestPermissions();
      await _schedulePeriodicNotifications();

      // Test notification disabled. Periodic notifications will continue as scheduled.
    });
  }

  Future<void> _requestPermissions() async {
    if (Platform.isIOS || Platform.isMacOS) {
      await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } else if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      await androidImplementation?.requestNotificationsPermission();
    }
  }

  Future<void> _schedulePeriodicNotifications() async {
    // We cancel all existing to not duplicate schedules on app launch
    await _flutterLocalNotificationsPlugin.cancelAll();

    // 1. Weekly Reflection (Every Sunday at 8:00 PM)
    await _scheduleWeeklyReflection();

    // 2. Pattern Detection (Every 30 days)
    // To implement "every 30 days" reliably, we can schedule a repeating
    // notification or just schedule the next 12 occurrences manually.
    // For simplicity, we'll schedule a monthly notification.
    await _schedulePatternDetection();
  }

  Future<void> _scheduleWeeklyReflection() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'weekly_reflection_channel',
          'Weekly Reflections',
          channelDescription: 'Reminders for your weekly reflection from Emori',
          importance: Importance.max,
          priority: Priority.high,
        );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: DarwinNotificationDetails(),
    );

    // Schedule for next Sunday at 8 PM (20:00)
    await _flutterLocalNotificationsPlugin.zonedSchedule(
      id: 0,
      title: 'Your Weekly Reflection is ready ✨',
      body: "Let's take a look at how your week went.",
      scheduledDate: _nextInstanceOfDay(DateTime.sunday, 20),
      notificationDetails: platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  Future<void> _schedulePatternDetection() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'pattern_detection_channel',
          'Pattern Detection',
          channelDescription: 'Monthly reminders to check your patterns',
          importance: Importance.max,
          priority: Priority.high,
        );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: DarwinNotificationDetails(),
    );

    // Provide a monthly prompt to check patterns
    // e.g., On the 1st of every month at 9:00 AM
    await _flutterLocalNotificationsPlugin.zonedSchedule(
      id: 1,
      title: 'Pattern Detection 🔍',
      body:
          "It's been a while. Let's see what patterns we can find in your recent entries.",
      scheduledDate: _nextInstanceOfMonthDay(1, 9),
      notificationDetails: platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
    );
  }

  tz.TZDateTime _nextInstanceOfDay(int weekday, int hour) {
    tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
    );

    while (scheduledDate.weekday != weekday || scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  tz.TZDateTime _nextInstanceOfMonthDay(int day, int hour) {
    tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      day,
      hour,
    );

    if (scheduledDate.isBefore(now)) {
      // If the 1st of this month has already passed, schedule for next month
      scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month + 1,
        day,
        hour,
      );
    }
    return scheduledDate;
  }

  Future<void> showTestNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'test_channel',
          'Test Notifications',
          channelDescription: 'Channel for testing notifications',
          importance: Importance.max,
          priority: Priority.high,
        );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: DarwinNotificationDetails(),
    );

    await _flutterLocalNotificationsPlugin.show(
      id: 999,
      title: 'Test Notification 🚀',
      body: 'This is a trial run! Your notifications are working perfectly.',
      notificationDetails: platformChannelSpecifics,
    );
  }
}
