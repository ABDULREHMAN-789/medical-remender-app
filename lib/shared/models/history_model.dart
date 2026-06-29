import 'package:isar/isar.dart';

part 'history_model.g.dart';

@Collection()
class History {
  Id id = Isar.autoIncrement;

  @Index()
  late int medicineId;
  
  late String medicineName;
  late String dosage;
  
  @Index()
  late DateTime scheduledTime;
  
  DateTime? actionTime;
  
  late String status; // 'taken', 'skipped', 'missed'

  Map<String, dynamic> toJson() {
    return {
      'id': id == Isar.autoIncrement ? null : id,
      'medicineId': medicineId,
      'medicineName': medicineName,
      'dosage': dosage,
      'scheduledTime': scheduledTime.toIso8601String(),
      'actionTime': actionTime?.toIso8601String(),
      'status': status,
    };
  }

  static History fromJson(Map<String, dynamic> json) {
    final history = History()
      ..medicineId = json['medicineId'] as int
      ..medicineName = json['medicineName'] as String
      ..dosage = json['dosage'] as String
      ..scheduledTime = DateTime.parse(json['scheduledTime'] as String)
      ..actionTime = json['actionTime'] != null ? DateTime.parse(json['actionTime'] as String) : null
      ..status = json['status'] as String;
    
    if (json['id'] != null) {
      history.id = json['id'] as int;
    }
    return history;
  }
}
