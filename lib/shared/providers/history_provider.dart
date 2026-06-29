import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import '../models/history_model.dart';
import '../models/medicine_model.dart';
import 'service_providers.dart';
import '../../core/services/notification_service.dart';
import 'medicine_provider.dart';

class HistoryNotifier extends StateNotifier<List<History>> {
  final Ref _ref;

  HistoryNotifier(this._ref) : super([]) {
    loadHistory();
  }

  Isar get _isar => _ref.read(isarServiceProvider).isar;

  Future<void> loadHistory() async {
    final histories = await _isar.collection<History>().where().findAll();
    state = histories;
  }

  Future<void> logDose({
    required int medicineId,
    required String medicineName,
    required String dosage,
    required DateTime scheduledTime,
    required String status, // taken, skipped, missed
    required int reminderId,
  }) async {
    final existing = await _isar.collection<History>()
        .filter()
        .medicineIdEqualTo(medicineId)
        .scheduledTimeEqualTo(scheduledTime)
        .findFirst();

    final now = DateTime.now();

    await _isar.writeTxn(() async {
      if (existing != null) {
        final oldStatus = existing.status;
        existing.status = status;
        existing.actionTime = now;
        await _isar.collection<History>().put(existing);

        if (oldStatus != 'taken' && status == 'taken') {
          final med = await _isar.collection<Medicine>().get(medicineId);
          if (med != null) {
            med.remainingQuantity = (med.remainingQuantity - 1).clamp(0, med.quantity);
            med.updatedAt = now;
            await _isar.collection<Medicine>().put(med);
          }
        } else if (oldStatus == 'taken' && status != 'taken') {
          final med = await _isar.collection<Medicine>().get(medicineId);
          if (med != null) {
            med.remainingQuantity = (med.remainingQuantity + 1).clamp(0, med.quantity);
            med.updatedAt = now;
            await _isar.collection<Medicine>().put(med);
          }
        }
      } else {
        final history = History()
          ..medicineId = medicineId
          ..medicineName = medicineName
          ..dosage = dosage
          ..scheduledTime = scheduledTime
          ..actionTime = now
          ..status = status;
        await _isar.collection<History>().put(history);

        if (status == 'taken') {
          final med = await _isar.collection<Medicine>().get(medicineId);
          if (med != null) {
            med.remainingQuantity = (med.remainingQuantity - 1).clamp(0, med.quantity);
            med.updatedAt = now;
            await _isar.collection<Medicine>().put(med);
          }
        }
      }
    });

    final notificationService = _ref.read(notificationServiceProvider);
    final baseId = NotificationService.idFromDose(reminderId, scheduledTime);
    await notificationService.cancelNotification(baseId);
    await notificationService.cancelNotification(baseId + 1);
    await notificationService.cancelNotification(baseId + 2);

    await loadHistory();
    await _ref.read(medicineProvider.notifier).loadMedicines();
  }
}

final historyProvider = StateNotifierProvider<HistoryNotifier, List<History>>((ref) {
  return HistoryNotifier(ref);
});
