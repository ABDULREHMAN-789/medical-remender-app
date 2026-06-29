import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import '../models/reminder_model.dart';
import '../models/medicine_model.dart';
import 'service_providers.dart';

class ReminderNotifier extends StateNotifier<List<Reminder>> {
  final Ref _ref;

  ReminderNotifier(this._ref) : super([]) {
    loadReminders();
  }

  Isar get _isar => _ref.read(isarServiceProvider).isar;

  Future<void> loadReminders() async {
    final reminders = await _isar.collection<Reminder>().where().findAll();
    state = reminders;
  }

  Future<List<Reminder>> getRemindersForMedicine(int medicineId) async {
    return await _isar.collection<Reminder>().filter().medicineIdEqualTo(medicineId).findAll();
  }

  Future<void> toggleReminderActive(int reminderId) async {
    final reminder = await _isar.collection<Reminder>().get(reminderId);
    if (reminder == null) return;

    reminder.isActive = !reminder.isActive;

    await _isar.writeTxn(() async {
      await _isar.collection<Reminder>().put(reminder);
    });

    final medicine = await _isar.collection<Medicine>().get(reminder.medicineId);
    if (medicine != null) {
      if (reminder.isActive) {
        await _ref.read(medicineSchedulerServiceProvider).scheduleRemindersForMedicine(medicine);
      } else {
        await _ref.read(medicineSchedulerServiceProvider).cancelRemindersForMedicine(medicine.id);
        await _ref.read(medicineSchedulerServiceProvider).scheduleRemindersForMedicine(medicine);
      }
    }

    await loadReminders();
  }
}

final reminderProvider = StateNotifierProvider<ReminderNotifier, List<Reminder>>((ref) {
  return ReminderNotifier(ref);
});
