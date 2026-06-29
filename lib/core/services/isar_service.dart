import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../../shared/models/medicine_model.dart';
import '../../shared/models/reminder_model.dart';
import '../../shared/models/history_model.dart';
import '../../shared/models/prescription_model.dart';

class IsarService {
  late final Isar isar;

  Future<void> init() async {
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
  }

  // Helper clear database for testing or reset
  Future<void> clearDatabase() async {
    await isar.writeTxn(() async {
      await isar.clear();
    });
  }
}
