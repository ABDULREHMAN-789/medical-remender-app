import 'package:isar/isar.dart';

part 'reminder_model.g.dart';

@Collection()
class Reminder {
  Id id = Isar.autoIncrement;

  @Index()
  late int medicineId;
  
  late String reminderType; // 'manual' or 'interval'
  late String timeOfDay; // "08:00 AM" or custom label
  int? intervalHours; // e.g. 4, 6, 8, 12 hours
  
  @Index()
  late bool isActive;

  Map<String, dynamic> toJson() {
    return {
      'id': id == Isar.autoIncrement ? null : id,
      'medicineId': medicineId,
      'reminderType': reminderType,
      'timeOfDay': timeOfDay,
      'intervalHours': intervalHours,
      'isActive': isActive,
    };
  }

  static Reminder fromJson(Map<String, dynamic> json) {
    final reminder = Reminder()
      ..medicineId = json['medicineId'] as int
      ..reminderType = json['reminderType'] as String
      ..timeOfDay = json['timeOfDay'] as String
      ..intervalHours = json['intervalHours'] as int?
      ..isActive = json['isActive'] as bool;
    
    if (json['id'] != null) {
      reminder.id = json['id'] as int;
    }
    return reminder;
  }
}
