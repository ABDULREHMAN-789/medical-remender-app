import 'package:isar/isar.dart';

part 'prescription_model.g.dart';

@Collection()
class Prescription {
  Id id = Isar.autoIncrement;

  late String doctorName;
  late DateTime prescriptionDate;
  late String filePath; // Local path to saved image or PDF
  String? notes;
  late DateTime createdAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id == Isar.autoIncrement ? null : id,
      'doctorName': doctorName,
      'prescriptionDate': prescriptionDate.toIso8601String(),
      'filePath': filePath,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static Prescription fromJson(Map<String, dynamic> json) {
    final prescription = Prescription()
      ..doctorName = json['doctorName'] as String
      ..prescriptionDate = DateTime.parse(json['prescriptionDate'] as String)
      ..filePath = json['filePath'] as String
      ..notes = json['notes'] as String?
      ..createdAt = DateTime.parse(json['createdAt'] as String);
    
    if (json['id'] != null) {
      prescription.id = json['id'] as int;
    }
    return prescription;
  }
}
