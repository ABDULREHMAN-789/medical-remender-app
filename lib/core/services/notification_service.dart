import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_10y.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../../shared/models/medicine_model.dart';
import '../../shared/models/reminder_model.dart';
import '../../shared/models/history_model.dart';
import '../../shared/models/prescription_model.dart';

// Top-level or static background callback required for notification actions
@pragma('vm:entry-point')
void notificationActionBackgroundCallback(NotificationResponse response) {
  NotificationService.handleNotificationAction(response);
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    try {
      final String timeZoneName = (await FlutterTimezone.getLocalTimezone()).identifier;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      print("Timezone initialized successfully to: $timeZoneName");
    } catch (e) {
      print("Failed to initialize device timezone, falling back to UTC: $e");
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        handleNotificationAction(response);
      },
      onDidReceiveBackgroundNotificationResponse: notificationActionBackgroundCallback,
    );

    // Create a high-priority channel for medicine reminders
    const androidChannel = AndroidNotificationChannel(
      'medicine_reminders_channel',
      'Medicine Reminders',
      description: 'Alerts for scheduled medicine doses',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  /// Helper to get local tz.TZDateTime
  static tz.TZDateTime _toTZDateTime(DateTime dateTime) {
    return tz.TZDateTime.from(dateTime, tz.local);
  }

  /// Schedule a notification
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    required String payload,
  }) async {
    final tzTime = _toTZDateTime(scheduledTime);
    if (tzTime.isBefore(tz.TZDateTime.now(tz.local))) {
      return; // Do not schedule in the past
    }

    final androidDetails = AndroidNotificationDetails(
      'medicine_reminders_channel',
      'Medicine Reminders',
      channelDescription: 'Alerts for scheduled medicine doses',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          'action_taken',
          'Taken',
          showsUserInterface: false,
          cancelNotification: true,
        ),
        const AndroidNotificationAction(
          'action_skip',
          'Skip',
          showsUserInterface: false,
          cancelNotification: true,
        ),
        const AndroidNotificationAction(
          'action_snooze',
          'Snooze',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
    );

    final iosDetails = const DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      categoryIdentifier: 'medicine_reminder_category',
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    AndroidScheduleMode scheduleMode = AndroidScheduleMode.exactAllowWhileIdle;
    try {
      final isExactGranted = await Permission.scheduleExactAlarm.isGranted;
      if (!isExactGranted) {
        scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
      }
    } catch (_) {
      scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
    }

    print("[NotificationService] Attempting to schedule notification ID $id for '$title' at $tzTime (mode: $scheduleMode)");

    try {
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tzTime,
        details,
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
      print("[NotificationService] Successfully scheduled notification ID $id at $tzTime");
    } catch (e) {
      if (scheduleMode == AndroidScheduleMode.exactAllowWhileIdle &&
          e is PlatformException &&
          e.code == 'exact_alarms_not_permitted') {
        print("[NotificationService] Exact alarms denied, falling back to inexact for ID $id");
        try {
          await _notificationsPlugin.zonedSchedule(
            id,
            title,
            body,
            tzTime,
            details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            payload: payload,
          );
          print("[NotificationService] Successfully scheduled fallback inexact notification ID $id at $tzTime");
        } catch (fallbackError) {
          print("[NotificationService] Fallback notification scheduling failed for ID $id: $fallbackError");
        }
      } else {
        print("[NotificationService] Notification scheduling failed for ID $id: $e");
      }
    }
  }

  /// Cancel specific notification
  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }

  /// Static handler that executes database update for Notification Action Buttons.
  /// Works in foreground and background isolates.
  static Future<void> handleNotificationAction(NotificationResponse response) async {
    final actionId = response.actionId;
    final payloadStr = response.payload;
    if (payloadStr == null) return;

    try {
      final payload = jsonDecode(payloadStr) as Map<String, dynamic>;
      final medicineId = payload['medicineId'] as int;
      final medicineName = payload['medicineName'] as String;
      final dosage = payload['dosage'] as String;
      final scheduledTimeStr = payload['scheduledTime'] as String;
      final scheduledTime = DateTime.parse(scheduledTimeStr);
      final reminderId = payload['reminderId'] as int;

      // Initialize Isar for this isolate if not already initialized
      Isar isar;
      if (Isar.instanceNames.isEmpty) {
        final dir = await getApplicationDocumentsDirectory();
        isar = await Isar.open(
          [
            MedicineSchema,
            ReminderSchema,
            HistorySchema,
            PrescriptionSchema,
          ],
          directory: dir.path,
        );
      } else {
        isar = Isar.getInstance()!;
      }

      if (actionId == 'action_taken') {
        await isar.writeTxn(() async {
          // 1. Record Dose History
          final history = History()
            ..medicineId = medicineId
            ..medicineName = medicineName
            ..dosage = dosage
            ..scheduledTime = scheduledTime
            ..actionTime = DateTime.now()
            ..status = 'taken';
          await isar.collection<History>().put(history);

          // 2. Reduce Stock
          final medicine = await isar.collection<Medicine>().get(medicineId);
          if (medicine != null) {
            medicine.remainingQuantity = (medicine.remainingQuantity - 1).clamp(0, medicine.quantity);
            medicine.updatedAt = DateTime.now();
            await isar.collection<Medicine>().put(medicine);
          }
        });

        // 3. Cancel Retries (retry IDs: standard ID + 1, standard ID + 2)
        await _notificationsPlugin.cancel(response.id ?? idFromDose(reminderId, scheduledTime));
        await _notificationsPlugin.cancel((response.id ?? idFromDose(reminderId, scheduledTime)) + 1);
        await _notificationsPlugin.cancel((response.id ?? idFromDose(reminderId, scheduledTime)) + 2);
      } 
      
      else if (actionId == 'action_skip') {
        await isar.writeTxn(() async {
          // Record Dose History as Skipped
          final history = History()
            ..medicineId = medicineId
            ..medicineName = medicineName
            ..dosage = dosage
            ..scheduledTime = scheduledTime
            ..actionTime = DateTime.now()
            ..status = 'skipped';
          await isar.collection<History>().put(history);
        });

        // Cancel Retries
        await _notificationsPlugin.cancel(response.id ?? idFromDose(reminderId, scheduledTime));
        await _notificationsPlugin.cancel((response.id ?? idFromDose(reminderId, scheduledTime)) + 1);
        await _notificationsPlugin.cancel((response.id ?? idFromDose(reminderId, scheduledTime)) + 2);
      } 
      
      else if (actionId == 'action_snooze') {
        // Reschedule notification for 15 minutes later
        final snoozeTime = DateTime.now().add(const Duration(minutes: 15));
        
        final service = NotificationService();
        await service.scheduleNotification(
          id: (response.id ?? idFromDose(reminderId, scheduledTime)) + 10000, // Make a unique snooze ID
          title: "Snoozed: $medicineName ($dosage)",
          body: "It's time to take your snoozed medicine.",
          scheduledTime: snoozeTime,
          payload: payloadStr,
        );
      }
    } catch (e) {
      // Background logger
      print("Error handling background notification action: $e");
    }
  }

  /// Deterministic notification ID for a reminder instance at a specific datetime
  static int idFromDose(int reminderId, DateTime scheduledTime) {
    // Combine reminderId and hours/minutes into a unique 31-bit integer
    final timeSum = scheduledTime.day * 10000 + scheduledTime.hour * 100 + scheduledTime.minute;
    return (reminderId * 100000 + timeSum).hashCode & 0x7FFFFFFF;
  }
}
