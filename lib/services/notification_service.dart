import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    tz.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (details) {},
    );

    _initialized = true;
  }

  Future<void> requestPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  // Show immediate notification
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'taskflow_channel',
      'TaskFlow Notifications',
      channelDescription: 'Task reminders and updates',
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(''),
      color: Color(0xFF6C63FF),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(id, title, body, details, payload: payload);
  }

  // Schedule a notification
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    if (scheduledDate.isBefore(DateTime.now())) return;

    const androidDetails = AndroidNotificationDetails(
      'taskflow_reminders',
      'Task Reminders',
      channelDescription: 'Scheduled task due date reminders',
      importance: Importance.high,
      priority: Priority.high,
      color: Color(0xFF6C63FF),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  // Schedule task due reminder (1 day before)
  Future<void> scheduleTaskReminder({
    required String taskId,
    required String taskTitle,
    required DateTime dueDate,
  }) async {
    final reminderDate = dueDate.subtract(const Duration(days: 1));
    final id = taskId.hashCode;

    await scheduleNotification(
      id: id,
      title: '⏰ Task Due Tomorrow!',
      body: '"$taskTitle" is due tomorrow. Don\'t forget to submit!',
      scheduledDate: reminderDate,
      payload: taskId,
    );

    // Also schedule a same-day reminder
    final sameDayReminder = DateTime(
      dueDate.year,
      dueDate.month,
      dueDate.day,
      9,
      0,
    );
    await scheduleNotification(
      id: id + 1,
      title: '🚨 Task Due Today!',
      body: '"$taskTitle" is due today!',
      scheduledDate: sameDayReminder,
      payload: taskId,
    );
  }

  Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id);
    await _plugin.cancel(id + 1);
  }

  Future<void> cancelAllNotifications() async {
    await _plugin.cancelAll();
  }

  // Notify student when task is assigned
  Future<void> notifyTaskAssigned(String taskTitle) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: '📋 New Task Assigned',
      body: 'You have been assigned: "$taskTitle"',
    );
  }

  // Notify manager when student completes task
  Future<void> notifyTaskCompleted(String studentName, String taskTitle) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: '✅ Task Completed',
      body: '$studentName completed: "$taskTitle"',
    );
  }
}
