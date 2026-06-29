import 'package:flutter_test/flutter_test.dart';
import 'package:med_reminder/shared/models/medicine_model.dart';
import 'package:med_reminder/shared/models/reminder_model.dart';

void main() {
  group('Model JSON Serialization & Deserialization Tests', () {
    test('Medicine Model Serialization & Deserialization', () {
      final now = DateTime(2026, 6, 15, 12, 0);
      final medicine = Medicine()
        ..id = 1
        ..medicineName = 'Aspirin'
        ..medicineType = 'Tablet'
        ..dosage = '1 pill'
        ..quantity = 30
        ..remainingQuantity = 25
        ..startDate = now
        ..endDate = now.add(const Duration(days: 7))
        ..isArchived = false
        ..createdAt = now
        ..updatedAt = now;

      final json = medicine.toJson();
      expect(json['id'], 1);
      expect(json['medicineName'], 'Aspirin');
      expect(json['remainingQuantity'], 25);
      expect(json['startDate'], now.toIso8601String());

      final parsed = Medicine.fromJson(json);
      expect(parsed.medicineName, 'Aspirin');
      expect(parsed.medicineType, 'Tablet');
      expect(parsed.dosage, '1 pill');
      expect(parsed.quantity, 30);
      expect(parsed.remainingQuantity, 25);
      expect(parsed.startDate, now);
      expect(parsed.endDate, now.add(const Duration(days: 7)));
      expect(parsed.isArchived, false);
    });

    test('Reminder Model Serialization & Deserialization', () {
      final reminder = Reminder()
        ..id = 5
        ..medicineId = 1
        ..reminderType = 'manual'
        ..timeOfDay = '08:00 AM'
        ..isActive = true;

      final json = reminder.toJson();
      expect(json['id'], 5);
      expect(json['medicineId'], 1);
      expect(json['timeOfDay'], '08:00 AM');
      expect(json['isActive'], true);

      final parsed = Reminder.fromJson(json);
      expect(parsed.medicineId, 1);
      expect(parsed.reminderType, 'manual');
      expect(parsed.timeOfDay, '08:00 AM');
      expect(parsed.isActive, true);
    });
  });
}
