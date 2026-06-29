import 'dart:convert';
import 'package:isar/isar.dart';
import '../../shared/models/medicine_model.dart';
import '../../shared/models/reminder_model.dart';
import '../../shared/models/history_model.dart';
import '../../shared/models/prescription_model.dart';

class BackupService {
  final Isar isar;

  BackupService(this.isar);

  Future<String> exportBackup() async {
    final medicines = await isar.collection<Medicine>().where().findAll();
    final reminders = await isar.collection<Reminder>().where().findAll();
    final histories = await isar.collection<History>().where().findAll();
    final prescriptions = await isar.collection<Prescription>().where().findAll();

    final backupData = {
      'backupVersion': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'medicines': medicines.map((e) => e.toJson()).toList(),
      'reminders': reminders.map((e) => e.toJson()).toList(),
      'histories': histories.map((e) => e.toJson()).toList(),
      'prescriptions': prescriptions.map((e) => e.toJson()).toList(),
    };

    return jsonEncode(backupData);
  }

  Future<void> importBackup(String jsonContent) async {
    final Map<String, dynamic> backupData = jsonDecode(jsonContent);
    
    final medicinesJson = backupData['medicines'] as List? ?? [];
    final remindersJson = backupData['reminders'] as List? ?? [];
    final historiesJson = backupData['histories'] as List? ?? [];
    final prescriptionsJson = backupData['prescriptions'] as List? ?? [];

    await isar.writeTxn(() async {
      // Clear database collections first
      await isar.collection<Medicine>().clear();
      await isar.collection<Reminder>().clear();
      await isar.collection<History>().clear();
      await isar.collection<Prescription>().clear();

      // Insert new records
      final medicines = medicinesJson.map((e) => Medicine.fromJson(Map<String, dynamic>.from(e))).toList();
      await isar.collection<Medicine>().putAll(medicines);

      final reminders = remindersJson.map((e) => Reminder.fromJson(Map<String, dynamic>.from(e))).toList();
      await isar.collection<Reminder>().putAll(reminders);

      final histories = historiesJson.map((e) => History.fromJson(Map<String, dynamic>.from(e))).toList();
      await isar.collection<History>().putAll(histories);

      final prescriptions = prescriptionsJson.map((e) => Prescription.fromJson(Map<String, dynamic>.from(e))).toList();
      await isar.collection<Prescription>().putAll(prescriptions);
    });
  }
}
