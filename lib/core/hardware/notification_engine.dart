import 'dart:developer' as developer;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Handles scheduling, rescheduling, and cancellation of localized expiry alerts
/// at 30 days, 7 days, and 1 day remaining prior to document expiry without requiring a remote server.
class LocalNotificationEngine {
  LocalNotificationEngine._();
  static final LocalNotificationEngine instance = LocalNotificationEngine._();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      tz.initializeTimeZones();

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      await _notifications.initialize(
        const InitializationSettings(android: androidSettings, iOS: iosSettings),
      );

      _isInitialized = true;
      developer.log('LocalNotificationEngine initialized successfully.');
    } catch (e, stack) {
      developer.log('Failed to initialize LocalNotificationEngine', error: e, stackTrace: stack);
    }
  }

  /// Schedules local notifications at 30 days, 7 days, and 1 day before document expiration.
  Future<void> scheduleExpiryAlerts({
    required String documentId,
    required String title,
    required String vehicleRegNo,
    required DateTime expiryDate,
  }) async {
    await initialize();

    final alertOffsets = [
      const Duration(days: 30),
      const Duration(days: 7),
      const Duration(days: 1),
    ];

    for (final offset in alertOffsets) {
      final scheduledDate = expiryDate.subtract(offset);

      // Only schedule if the reminder date is in the future
      if (scheduledDate.isAfter(DateTime.now())) {
        final tzScheduledTime = tz.TZDateTime.from(
          DateTime(scheduledDate.year, scheduledDate.month, scheduledDate.day, 9, 0), // 09:00 AM local
          tz.local,
        );

        final notificationId = _generateNotificationId(documentId, offset.inDays);

        await _notifications.zonedSchedule(
          notificationId,
          'Vehicle Document Expiring: $title',
          '$vehicleRegNo validity ends in ${offset.inDays} day(s). Tap to review renewal.',
          tzScheduledTime,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'vehicle_doc_expiry_channel',
              'Vehicle Document Expiry Alerts',
              channelDescription: 'Scheduled reminders for vehicle insurance and revenue license renewals',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );

        developer.log('Scheduled expiry notification $notificationId for $tzScheduledTime');
      }
    }
  }

  /// Cancels all scheduled alerts for a specific document ID.
  Future<void> cancelDocumentAlerts(String documentId) async {
    await initialize();
    final alertDays = [30, 7, 1];
    for (final days in alertDays) {
      final notificationId = _generateNotificationId(documentId, days);
      await _notifications.cancel(notificationId);
    }
    developer.log('Cancelled scheduled expiry alerts for document $documentId');
  }

  int _generateNotificationId(String documentId, int days) {
    return (documentId.hashCode ^ days).abs() % 100000;
  }
}
