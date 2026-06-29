import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import '../models/medicine_model.dart';
import '../models/reminder_model.dart';
import '../models/history_model.dart';
import 'service_providers.dart';

class MedicineNotifier extends StateNotifier<List<Medicine>> {
  final Ref _ref;

  MedicineNotifier(this._ref) : super([]) {
    loadMedicines();
  }

  Isar get _isar => _ref.read(isarServiceProvider).isar;

  Future<void> loadMedicines() async {
    final medicines = await _isar.collection<Medicine>().where().findAll();
    state = medicines;
  }

  Future<Medicine> addMedicine({
    required String name,
    required String type,
    required String dosage,
    required int quantity,
    required DateTime startDate,
    required DateTime endDate,
    String? notes,
    String? imagePath,
    required List<Reminder> reminderSchedules,
  }) async {
    final medicine = Medicine()
      ..medicineName = name
      ..medicineType = type
      ..dosage = dosage
      ..quantity = quantity
      ..remainingQuantity = quantity
      ..startDate = startDate
      ..endDate = endDate
      ..notes = notes
      ..imagePath = imagePath
      ..isArchived = false
      ..createdAt = DateTime.now()
      ..updatedAt = DateTime.now();

    await _isar.writeTxn(() async {
      await _isar.collection<Medicine>().put(medicine);
      
      // Assign medicineId to reminders and save them
      for (final r in reminderSchedules) {
        r.medicineId = medicine.id;
        await _isar.collection<Reminder>().put(r);
      }
    });

    // Schedule notifications for this medicine
    await _ref.read(medicineSchedulerServiceProvider).scheduleRemindersForMedicine(medicine);

    await loadMedicines();
    return medicine;
  }

  Future<void> editMedicine({
    required int id,
    required String name,
    required String type,
    required String dosage,
    required int quantity,
    required int remainingQuantity,
    required DateTime startDate,
    required DateTime endDate,
    String? notes,
    String? imagePath,
    required List<Reminder> reminderSchedules,
  }) async {
    final medicine = await _isar.collection<Medicine>().get(id);
    if (medicine == null) return;

    // First cancel existing notifications
    await _ref.read(medicineSchedulerServiceProvider).cancelRemindersForMedicine(id);

    medicine
      ..medicineName = name
      ..medicineType = type
      ..dosage = dosage
      ..quantity = quantity
      ..remainingQuantity = remainingQuantity
      ..startDate = startDate
      ..endDate = endDate
      ..notes = notes
      ..imagePath = imagePath
      ..updatedAt = DateTime.now();

    await _isar.writeTxn(() async {
      await _isar.collection<Medicine>().put(medicine);

      // Remove old reminders
      await _isar.collection<Reminder>().filter().medicineIdEqualTo(id).deleteAll();

      // Put new reminders
      for (final r in reminderSchedules) {
        r.medicineId = id;
        await _isar.collection<Reminder>().put(r);
      }
    });

    // Schedule new notifications
    await _ref.read(medicineSchedulerServiceProvider).scheduleRemindersForMedicine(medicine);

    await loadMedicines();
  }

  Future<void> archiveMedicine(int id) async {
    final medicine = await _isar.collection<Medicine>().get(id);
    if (medicine == null) return;

    await _ref.read(medicineSchedulerServiceProvider).cancelRemindersForMedicine(id);

    medicine.isArchived = true;
    medicine.updatedAt = DateTime.now();

    await _isar.writeTxn(() async {
      await _isar.collection<Medicine>().put(medicine);
    });

    await loadMedicines();
  }

  Future<void> deleteMedicine(int id) async {
    await _ref.read(medicineSchedulerServiceProvider).cancelRemindersForMedicine(id);

    await _isar.writeTxn(() async {
      await _isar.collection<Medicine>().delete(id);
      await _isar.collection<Reminder>().filter().medicineIdEqualTo(id).deleteAll();
      await _isar.collection<History>().filter().medicineIdEqualTo(id).deleteAll();
    });

    await loadMedicines();
  }
}

final medicineProvider = StateNotifierProvider<MedicineNotifier, List<Medicine>>((ref) {
  return MedicineNotifier(ref);
});
