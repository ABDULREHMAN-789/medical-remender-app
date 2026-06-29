import 'package:isar/isar.dart';

part 'medicine_model.g.dart';

@Collection()
class Medicine {
  Id id = Isar.autoIncrement;

  late String medicineName;
  late String medicineType; // Tablet, Capsule, Syrup, Injection, Drops, Other
  late String dosage;
  String? imagePath;
  String? notes;
  
  late int quantity;
  late int remainingQuantity;
  
  late DateTime startDate;
  late DateTime endDate;
  
  @Index()
  late bool isArchived;
  
  late DateTime createdAt;
  late DateTime updatedAt;

  // Manual json conversion helper for backup/restore
  Map<String, dynamic> toJson() {
    return {
      'id': id == Isar.autoIncrement ? null : id,
      'medicineName': medicineName,
      'medicineType': medicineType,
      'dosage': dosage,
      'imagePath': imagePath,
      'notes': notes,
      'quantity': quantity,
      'remainingQuantity': remainingQuantity,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'isArchived': isArchived,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  static Medicine fromJson(Map<String, dynamic> json) {
    final medicine = Medicine()
      ..medicineName = json['medicineName'] as String
      ..medicineType = json['medicineType'] as String
      ..dosage = json['dosage'] as String
      ..imagePath = json['imagePath'] as String?
      ..notes = json['notes'] as String?
      ..quantity = json['quantity'] as int
      ..remainingQuantity = json['remainingQuantity'] as int
      ..startDate = DateTime.parse(json['startDate'] as String)
      ..endDate = DateTime.parse(json['endDate'] as String)
      ..isArchived = json['isArchived'] as bool
      ..createdAt = DateTime.parse(json['createdAt'] as String)
      ..updatedAt = DateTime.parse(json['updatedAt'] as String);
    
    if (json['id'] != null) {
      medicine.id = json['id'] as int;
    }
    return medicine;
  }
}
