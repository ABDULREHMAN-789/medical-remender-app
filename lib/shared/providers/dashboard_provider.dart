import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import '../models/medicine_model.dart';
import '../models/reminder_model.dart';
import '../models/history_model.dart';
import 'medicine_provider.dart';
import 'reminder_provider.dart';
import 'history_provider.dart';
import '../../core/utils/date_helpers.dart';

class DashboardDose {
  final Medicine medicine;
  final Reminder reminder;
  final DateTime scheduledTime;
  final String status; // 'taken', 'skipped', 'missed', 'scheduled'
  final History? historyLog;

  DashboardDose({
    required this.medicine,
    required this.reminder,
    required this.scheduledTime,
    required this.status,
    this.historyLog,
  });
}

class DashboardState {
  final List<DashboardDose> todayDoses;
  final DashboardDose? nextDose;
  final int activeMedicinesCount;
  final double todayProgress;
  final List<Medicine> stockAlerts;

  DashboardState({
    required this.todayDoses,
    required this.nextDose,
    required this.activeMedicinesCount,
    required this.todayProgress,
    required this.stockAlerts,
  });
}

final dashboardProvider = Provider<DashboardState>((ref) {
  final medicines = ref.watch(medicineProvider);
  final reminders = ref.watch(reminderProvider);
  final history = ref.watch(historyProvider);

  final now = DateTime.now();
  final startOfToday = DateHelpers.startOfDay(now);
  final endOfToday = DateHelpers.endOfDay(now);

  // 1. Calculate active medicines
  final activeMedicines = medicines.where((m) => !m.isArchived && m.endDate.isAfter(now)).toList();
  final activeCount = activeMedicines.length;

  // 2. Generate stock alerts
  final stockAlerts = medicines.where((m) => !m.isArchived && m.remainingQuantity <= 5).toList();

  // 3. Generate today's schedule
  final List<DashboardDose> todayDoses = [];

  for (final med in medicines) {
    if (med.isArchived) continue;
    // Check if medicine course overlaps with today
    if (med.startDate.isAfter(endOfToday) || med.endDate.isBefore(startOfToday)) continue;

    final medReminders = reminders.where((r) => r.medicineId == med.id && r.isActive).toList();

    for (final rem in medReminders) {
      final times = _calculateTodayTimes(med, rem, startOfToday, endOfToday);
      for (final time in times) {
        final log = history.firstWhere(
          (h) => h.medicineId == med.id && 
                 DateHelpers.isSameDay(h.scheduledTime, time) && 
                 h.scheduledTime.hour == time.hour && 
                 h.scheduledTime.minute == time.minute,
          orElse: () => History()..id = Isar.autoIncrement..status = 'scheduled',
        );

        String status = log.id == Isar.autoIncrement ? 'scheduled' : log.status;
        // If it's more than 2 hours in the past and no history log, it is automatically skipped
        if (status == 'scheduled' && time.isBefore(now.subtract(const Duration(hours: 2)))) {
          status = 'skipped';
        }

        todayDoses.add(DashboardDose(
          medicine: med,
          reminder: rem,
          scheduledTime: time,
          status: status,
          historyLog: log.id == Isar.autoIncrement ? null : log,
        ));
      }
    }
  }

  // Sort today's doses by scheduled time
  todayDoses.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));

  // 4. Calculate next upcoming dose
  DashboardDose? nextDose;
  for (final dose in todayDoses) {
    if (dose.scheduledTime.isAfter(now) && dose.status == 'scheduled') {
      nextDose = dose;
      break;
    }
  }

  // 5. Calculate today's adherence progress
  final totalToday = todayDoses.length;
  final takenToday = todayDoses.where((d) => d.status == 'taken').length;
  final progress = totalToday > 0 ? (takenToday / totalToday) : 0.0;

  return DashboardState(
    todayDoses: todayDoses,
    nextDose: nextDose,
    activeMedicinesCount: activeCount,
    todayProgress: progress,
    stockAlerts: stockAlerts,
  );
});

List<DateTime> _calculateTodayTimes(Medicine medicine, Reminder reminder, DateTime startOfToday, DateTime endOfToday) {
  final List<DateTime> times = [];

  if (reminder.reminderType == 'manual') {
    final doseTime = DateHelpers.combineDateAndTime(startOfToday, reminder.timeOfDay);
    if (doseTime.isAfter(medicine.startDate.subtract(const Duration(seconds: 1))) &&
        doseTime.isBefore(medicine.endDate.add(const Duration(seconds: 1)))) {
      times.add(doseTime);
    }
  } else if (reminder.reminderType == 'interval' && reminder.intervalHours != null) {
    final hours = reminder.intervalHours!;
    var currentDose = medicine.startDate;
    while (currentDose.isBefore(medicine.endDate) || currentDose.isAtSameMomentAs(medicine.endDate)) {
      if (currentDose.isAfter(startOfToday.subtract(const Duration(seconds: 1))) &&
          currentDose.isBefore(endOfToday.add(const Duration(seconds: 1)))) {
        times.add(currentDose);
      }
      currentDose = currentDose.add(Duration(hours: hours));
    }
  }

  return times;
}
