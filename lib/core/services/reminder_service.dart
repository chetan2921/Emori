import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:uuid/uuid.dart';
import '../database/database.dart';
import '../models/reminder.dart';

/// Service for scheduling and managing reminder notifications.
/// Works with the existing NotificationService infrastructure.
class ReminderService {
  static final ReminderService instance = ReminderService._();
  ReminderService._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  // Notification IDs: 0 = weekly, 1 = monthly, 100+ = reminders
  static const int _reminderIdOffset = 100;

  /// Check for upcoming reminders and schedule notifications.
  /// Called on app start and after new reminders are saved.
  Future<void> checkAndScheduleReminders() async {
    try {
      final reminders = await AppDatabase.instance
          .getRemindersNeedingNotification();

      for (final reminder in reminders) {
        await _scheduleReminderNotification(reminder);
        await AppDatabase.instance.markReminderNotified(reminder.id);
      }

      // Also check for reminders due today that haven't been notified
      final allUpcoming = await AppDatabase.instance.getUpcomingReminders();
      for (final reminder in allUpcoming) {
        final now = DateTime.now();
        final dueDate = reminder.dueDate;
        final hoursUntilDue = dueDate.difference(now).inHours;

        // If due within 24 hours and not yet notified, send immediate
        if (hoursUntilDue <= 24 && hoursUntilDue >= 0 && !reminder.isNotified) {
          await _sendImmediateNotification(reminder);
          await AppDatabase.instance.markReminderNotified(reminder.id);
        }
      }
    } catch (e) {
      debugPrint('Error checking reminders: $e');
    }
  }

  /// Schedule a notification for a specific reminder at its exact exact due date.
  /// Also schedules a pre-reminder the day before at 9 AM if applicable.
  Future<void> _scheduleReminderNotification(Reminder reminder) async {
    final dueDate = reminder.dueDate;
    final now = DateTime.now();

    // Schedule for day before at 9 AM
    final dayBefore = DateTime(
      dueDate.year,
      dueDate.month,
      dueDate.day - 1,
      9, // 9 AM
    );

    // Exact time
    final exactTime = dueDate;

    final notifId = reminder.id.hashCode.abs() % 10000 + _reminderIdOffset;

    // Schedule day-before notification if it's still in the future
    if (dayBefore.isAfter(now)) {
      await _notifications.zonedSchedule(
        id: notifId,
        title: '📅 Reminder: ${reminder.title}',
        body: 'Due tomorrow — ${reminder.description}',
        scheduledDate: tz.TZDateTime.from(dayBefore, tz.local),
        notificationDetails: _reminderNotificationDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }

    // Schedule exact time notification if it's still in the future
    if (exactTime.isAfter(now)) {
      final timeStr = _formatTime(exactTime);
      await _notifications.zonedSchedule(
        id: notifId + 50000,
        title: '⏰ $timeStr: ${reminder.title}',
        body: reminder.description,
        scheduledDate: tz.TZDateTime.from(exactTime, tz.local),
        notificationDetails: _reminderNotificationDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }
  }

  String _formatTime(DateTime dt) {
    int h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final p = h >= 12 ? 'PM' : 'AM';
    if (h > 12) h -= 12;
    if (h == 0) h = 12;
    return '$h:$m $p';
  }

  /// Send an immediate notification for an urgent reminder.
  Future<void> _sendImmediateNotification(Reminder reminder) async {
    final hoursLeft = reminder.dueDate.difference(DateTime.now()).inHours;
    final timeText = hoursLeft <= 0
        ? 'Due now!'
        : hoursLeft == 1
        ? 'Due in 1 hour'
        : 'Due in $hoursLeft hours';

    final notifId = reminder.id.hashCode.abs() % 10000 + _reminderIdOffset;

    await _notifications.show(
      id: notifId + 90000,
      title: '🔔 $timeText: ${reminder.title}',
      body: reminder.description,
      notificationDetails: _reminderNotificationDetails(),
    );
  }

  NotificationDetails _reminderNotificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'reminders_channel',
        'Reminders',
        channelDescription: 'Reminders from your conversations with Emori',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  /// Save reminders extracted by AI from a conversation.
  Future<void> saveExtractedReminders(
    List<Map<String, dynamic>> reminderData,
  ) async {
    for (final data in reminderData) {
      try {
        final title = data['title'] as String? ?? '';
        final description = data['description'] as String? ?? '';
        final dateStr = data['due_date'] as String? ?? '';

        if (title.isEmpty || dateStr.isEmpty) continue;

        final dueDate = _parseDate(dateStr);
        if (dueDate == null) continue;

        // Skip if exact due date has already passed
        final now = DateTime.now();
        if (dueDate.isBefore(now)) continue;

        final reminder = Reminder(
          id: const Uuid().v4(),
          title: title,
          description: description,
          dueDate: dueDate,
          createdAt: DateTime.now(),
        );

        await AppDatabase.instance.insertReminder(reminder);
        debugPrint('Saved reminder: $title on $dueDate');
      } catch (e) {
        debugPrint('Failed to save reminder: $e');
      }
    }

    // Schedule after saving
    await checkAndScheduleReminders();
  }

  /// Parse an ISO date string or common date formats.
  DateTime? _parseDate(String dateStr) {
    try {
      // First try to parse exact datetime (e.g., "2026-02-28 14:30:00")
      return DateTime.parse(dateStr);
    } catch (_) {
      try {
        // Fallback for just date "2026-02-28", defaulting to 9:00 AM
        final parts = dateStr.split(' ')[0].split('-');
        if (parts.length == 3) {
          return DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
            9, // Default to 9 AM if no time component exists
          );
        }
      } catch (_) {}
    }
    return null;
  }
}
