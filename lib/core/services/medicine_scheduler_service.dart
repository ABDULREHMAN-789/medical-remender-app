import 'dart:convert';
import 'package:isar/isar.dart';
import '../utils/date_helpers.dart';
import '../../shared/models/medicine_model.dart';
import '../../shared/models/reminder_model.dart';
import '../../shared/models/history_model.dart';
import 'notification_service.dart';

class MedicineSchedulerService {
  final Isar isar;
  final NotificationService notificationService;

  MedicineSchedulerService({
    required this.isar,
    required this.notificationService,
  });

  /// Schedule reminders for a medicine for the next 7 days (to prevent hitting notification limits)
  Future<void> scheduleRemindersForMedicine(Medicine medicine) async {
    print("[MedicineSchedulerService] Starting reminder scheduling for: ${medicine.medicineName} (ID: ${medicine.id})");
    final reminders = await isar.collection<Reminder>()
        .filter()
        .medicineIdEqualTo(medicine.id)
        .isActiveEqualTo(true)
        .findAll();

    print("[MedicineSchedulerService] Found ${reminders.length} active reminder configurations for '${medicine.medicineName}'");
    final now = DateTime.now();
    final limitDate = now.add(const Duration(days: 7));
    
    // Determine start boundary: either startDate or now, whichever is later
    DateTime scanStart = medicine.startDate.isBefore(now) ? now : medicine.startDate;
    // Determine end boundary: either endDate or limitDate, whichever is earlier
    DateTime scanEnd = medicine.endDate.isBefore(limitDate) ? medicine.endDate : limitDate;

    if (scanStart.isAfter(scanEnd)) {
      print("[MedicineSchedulerService] Scan start ($scanStart) is after scan end ($scanEnd). No reminders to schedule.");
      return;
    }

    for (final reminder in reminders) {
      final List<DateTime> timesToSchedule = _calculateDoseTimes(medicine, reminder, scanStart, scanEnd);
      print("[MedicineSchedulerService] Calculated ${timesToSchedule.length} dose times for reminder ${reminder.id} (type: ${reminder.reminderType}) between $scanStart and $scanEnd");

      for (final scheduledTime in timesToSchedule) {
        if (scheduledTime.isBefore(now)) {
          print("[MedicineSchedulerService] Skipping past scheduled dose time: $scheduledTime (current time is: $now)");
          continue;
        }

        final payload = jsonEncode({
          'medicineId': medicine.id,
          'medicineName': medicine.medicineName,
          'dosage': medicine.dosage,
          'scheduledTime': scheduledTime.toIso8601String(),
          'reminderId': reminder.id,
        });

        final baseId = NotificationService.idFromDose(reminder.id, scheduledTime);

        // 1. Schedule Primary Notification
        print("[MedicineSchedulerService] Queuing primary notification (ID: $baseId) at $scheduledTime");
        await notificationService.scheduleNotification(
          id: baseId,
          title: "Time for ${medicine.medicineName}!",
          body: "Take your dosage of ${medicine.dosage}.",
          scheduledTime: scheduledTime,
          payload: payload,
        );

        // 2. Schedule Smart Retry 1: +15 minutes
        print("[MedicineSchedulerService] Queuing Smart Retry 1 (ID: ${baseId + 1}) at ${scheduledTime.add(const Duration(minutes: 15))}");
        await notificationService.scheduleNotification(
          id: baseId + 1,
          title: "Reminder: ${medicine.medicineName} (${medicine.dosage})",
          body: "You missed your dose 15 minutes ago. Please take it.",
          scheduledTime: scheduledTime.add(const Duration(minutes: 15)),
          payload: payload,
        );

        // 3. Schedule Smart Retry 2: +30 minutes
        print("[MedicineSchedulerService] Queuing Smart Retry 2 (ID: ${baseId + 2}) at ${scheduledTime.add(const Duration(minutes: 30))}");
        await notificationService.scheduleNotification(
          id: baseId + 2,
          title: "Urgent Reminder: ${medicine.medicineName}",
          body: "Second reminder to take your ${medicine.dosage}.",
          scheduledTime: scheduledTime.add(const Duration(minutes: 30)),
          payload: payload,
        );
      }
    }
  }

  /// Cancels all notifications scheduled for a medicine
  Future<void> cancelRemindersForMedicine(int medicineId) async {
    final reminders = await isar.collection<Reminder>()
        .filter()
        .medicineIdEqualTo(medicineId)
        .findAll();

    for (final reminder in reminders) {
      // Since notifications are scheduled for the next 7 days, cancel all possible IDs
      // A safe way is to cancel notifications using saved IDs or cancel all, but to avoid cancelling others,
      // we can rebuild the schedule from now to now+8 days and cancel those specific calculated IDs.
      final now = DateTime.now();
      final medicine = await isar.collection<Medicine>().get(medicineId);
      if (medicine != null) {
        final scanEnd = now.add(const Duration(days: 8));
        final times = _calculateDoseTimes(medicine, reminder, medicine.startDate, scanEnd);
        for (final time in times) {
          final baseId = NotificationService.idFromDose(reminder.id, time);
          await notificationService.cancelNotification(baseId);
          await notificationService.cancelNotification(baseId + 1);
          await notificationService.cancelNotification(baseId + 2);
        }
      }
    }
  }

  /// Re-schedules reminders for all active medicines
  Future<void> rescheduleAllActiveMedicines() async {
    await notificationService.cancelAllNotifications();
    final activeMedicines = await isar.collection<Medicine>()
        .filter()
        .isArchivedEqualTo(false)
        .endDateGreaterThan(DateTime.now())
        .findAll();

    for (final medicine in activeMedicines) {
      await scheduleRemindersForMedicine(medicine);
    }
  }

  /// Scans the last 7 days of scheduled times. If a schedule has passed by 45 minutes
  /// and has no corresponding history log, mark it as 'missed'.
  Future<void> checkAndMarkMissedDoses() async {
    final activeMedicines = await isar.collection<Medicine>()
        .filter()
        .isArchivedEqualTo(false)
        .findAll();

    final now = DateTime.now();
    final scanStart = now.subtract(const Duration(days: 7));
    // Doses scheduled at least 2 hours ago are eligible to be marked auto-skipped
    final scanEnd = now.subtract(const Duration(hours: 2));

    await isar.writeTxn(() async {
      for (final medicine in activeMedicines) {
        // Only scan within the medicine's schedule bounds
        final startBound = medicine.startDate.isAfter(scanStart) ? medicine.startDate : scanStart;
        final endBound = medicine.endDate.isBefore(scanEnd) ? medicine.endDate : scanEnd;

        if (startBound.isAfter(endBound)) continue;

        final reminders = await isar.collection<Reminder>()
            .filter()
            .medicineIdEqualTo(medicine.id)
            .isActiveEqualTo(true)
            .findAll();

        for (final reminder in reminders) {
          final doseTimes = _calculateDoseTimes(medicine, reminder, startBound, endBound);

          for (final time in doseTimes) {
            // Check if there is already a history log for this specific time
            final exists = await isar.collection<History>()
                .filter()
                .medicineIdEqualTo(medicine.id)
                .scheduledTimeEqualTo(time)
                .isNotEmpty();

            if (!exists) {
              // Record auto-skipped dose
              final skippedHistory = History()
                ..medicineId = medicine.id
                ..medicineName = medicine.medicineName
                ..dosage = medicine.dosage
                ..scheduledTime = time
                ..actionTime = null
                ..status = 'skipped';
              await isar.collection<History>().put(skippedHistory);
            }
          }
        }
      }
    });
  }

  /// Helper to compute dose times between two dates based on reminder type
  List<DateTime> _calculateDoseTimes(
    Medicine medicine,
    Reminder reminder,
    DateTime start,
    DateTime end,
  ) {
    final List<DateTime> times = [];
    final startDay = DateHelpers.startOfDay(start);
    final endDay = DateHelpers.endOfDay(end);

    if (reminder.reminderType == 'manual') {
      // Step day by day
      var currentDay = startDay;
      while (currentDay.isBefore(endDay) || DateHelpers.isSameDay(currentDay, endDay)) {
        final doseTime = DateHelpers.combineDateAndTime(currentDay, reminder.timeOfDay);
        // Ensure it lies within medicine start/end boundaries and target boundaries
        if (doseTime.isAfter(medicine.startDate.subtract(const Duration(seconds: 1))) &&
            doseTime.isBefore(medicine.endDate.add(const Duration(seconds: 1))) &&
            doseTime.isAfter(start.subtract(const Duration(seconds: 1))) &&
            doseTime.isBefore(end.add(const Duration(seconds: 1)))) {
          times.add(doseTime);
        }
        currentDay = currentDay.add(const Duration(days: 1));
      }
    } else if (reminder.reminderType == 'interval' && reminder.intervalHours != null) {
      final hours = reminder.intervalHours!;
      // Start scheduling from medicine's start date
      var currentDose = medicine.startDate;
      while (currentDose.isBefore(medicine.endDate) || currentDose.isAtSameMomentAs(medicine.endDate)) {
        if (currentDose.isAfter(start.subtract(const Duration(seconds: 1))) &&
            currentDose.isBefore(end.add(const Duration(seconds: 1)))) {
          times.add(currentDose);
        }
        currentDose = currentDose.add(Duration(hours: hours));
      }
    }

    return times;
  }
}
