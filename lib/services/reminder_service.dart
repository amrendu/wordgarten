import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class ReminderService {
  final _notifications = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  Future<bool> schedule(int hour, int minute) async {
    if (kIsWeb) return false;
    try {
      if (!_ready) {
        tzdata.initializeTimeZones();
        final zone = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(zone.identifier));
        await _notifications.initialize(
          settings: const InitializationSettings(
            android: AndroidInitializationSettings('@drawable/ic_notification'),
            iOS: DarwinInitializationSettings(
              requestAlertPermission: false,
              requestBadgePermission: false,
              requestSoundPermission: false,
            ),
          ),
        );
        _ready = true;
      }
      final android = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final ios = _notifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (android != null &&
          await android.requestNotificationsPermission() != true) {
        return false;
      }
      if (ios != null &&
          await ios.requestPermissions(
                alert: true,
                sound: true,
                badge: false,
              ) !=
              true) {
        return false;
      }
      final now = tz.TZDateTime.now(tz.local);
      var next = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );
      if (!next.isAfter(now)) {
        next = tz.TZDateTime(
          tz.local,
          now.year,
          now.month,
          now.day + 1,
          hour,
          minute,
        );
      }
      await _notifications.zonedSchedule(
        id: 1,
        title: 'A little German, every day 🌱',
        body: 'Your next few words are waiting in Wortgarten.',
        scheduledDate: next,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_words',
            'Daily vocabulary',
            channelDescription: 'Your daily German practice reminder',
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> cancel() async {
    if (!kIsWeb) await _notifications.cancel(id: 1);
  }
}
