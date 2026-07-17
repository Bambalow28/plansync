import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

import '../models/itinerary_item.dart';
import '../models/trip.dart';

/// Schedules "heads up" local notifications a set time before a plan begins.
/// Until [init] succeeds this is a no-op, so tests and headless runs are safe.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _enabled = false;

  static const _channelId = 'plansync.reminders';

  Future<void> init() async {
    try {
      tzdata.initializeTimeZones();
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));

      const settings = InitializationSettings(
        iOS: DarwinInitializationSettings(),
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      );
      await _plugin.initialize(settings: settings);

      await _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      _enabled = true;
    } catch (e) {
      debugPrint('NotificationService init failed: $e');
      _enabled = false;
    }
  }

  /// Stable per-item notification id.
  int _idFor(ItineraryItem item) => item.id.hashCode & 0x7fffffff;

  /// Cancels all reminders and reschedules every eligible upcoming plan.
  Future<void> syncAll(List<Trip> trips) async {
    if (!_enabled) return;
    try {
      await _plugin.cancelAll();
      final now = DateTime.now();
      for (final trip in trips) {
        for (final item in trip.items) {
          final lead = item.reminderLeadMinutes;
          if (lead == null || item.start == null) continue;
          final fireAt = item.start!.subtract(Duration(minutes: lead));
          if (!fireAt.isAfter(now)) continue;
          await _schedule(item, trip, fireAt);
        }
      }
    } catch (e) {
      debugPrint('NotificationService syncAll failed: $e');
    }
  }

  Future<void> _schedule(ItineraryItem item, Trip trip, DateTime fireAt) async {
    const details = NotificationDetails(
      iOS: DarwinNotificationDetails(),
      android: AndroidNotificationDetails(
        _channelId,
        'Plan reminders',
        channelDescription: 'Heads-up before an upcoming plan',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    await _plugin.zonedSchedule(
      id: _idFor(item),
      title: item.title,
      body: 'Coming up on your ${trip.name} itinerary',
      scheduledDate: tz.TZDateTime.from(fireAt, tz.local),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }
}
