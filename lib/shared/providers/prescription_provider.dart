import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import '../models/prescription_model.dart';
import 'service_providers.dart';

class PrescriptionNotifier extends StateNotifier<List<Prescription>> {
  final Ref _ref;

  PrescriptionNotifier(this._ref) : super([]) {
    loadPrescriptions();
  }

  Isar get _isar => _ref.read(isarServiceProvider).isar;

  Future<void> loadPrescriptions() async {
    final prescriptions = await _isar.collection<Prescription>().where().findAll();
    state = prescriptions;
  }

  Future<void> addPrescription({
    required String doctorName,
    required DateTime date,
    required String filePath,
    String? notes,
  }) async {
    final prescription = Prescription()
      ..doctorName = doctorName
      ..prescriptionDate = date
      ..filePath = filePath
      ..notes = notes
      ..createdAt = DateTime.now();

    await _isar.writeTxn(() async {
      await _isar.collection<Prescription>().put(prescription);
    });

    await loadPrescriptions();
  }

  Future<void> editPrescription({
    required int id,
    required String doctorName,
    required DateTime date,
    required String filePath,
    String? notes,
  }) async {
    final prescription = await _isar.collection<Prescription>().get(id);
    if (prescription == null) return;

    prescription
      ..doctorName = doctorName
      ..prescriptionDate = date
      ..filePath = filePath
      ..notes = notes;

    await _isar.writeTxn(() async {
      await _isar.collection<Prescription>().put(prescription);
    });

    await loadPrescriptions();
  }

  Future<void> deletePrescription(int id) async {
    await _isar.writeTxn(() async {
      await _isar.collection<Prescription>().delete(id);
    });

    await loadPrescriptions();
  }
}

final prescriptionProvider = StateNotifierProvider<PrescriptionNotifier, List<Prescription>>((ref) {
  return PrescriptionNotifier(ref);
});
