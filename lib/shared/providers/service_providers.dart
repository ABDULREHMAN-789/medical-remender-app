import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/isar_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/medicine_scheduler_service.dart';
import '../../core/services/theme_service.dart';
import '../../core/services/backup_service.dart';
import '../../core/services/permission_service.dart';

final isarServiceProvider = Provider<IsarService>((ref) {
  return IsarService();
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final permissionServiceProvider = Provider<PermissionService>((ref) {
  return PermissionService();
});

final themeServiceProvider = Provider<ThemeService>((ref) {
  return ThemeService();
});

final backupServiceProvider = Provider<BackupService>((ref) {
  final isar = ref.watch(isarServiceProvider).isar;
  return BackupService(isar);
});

final medicineSchedulerServiceProvider = Provider<MedicineSchedulerService>((ref) {
  final isar = ref.watch(isarServiceProvider).isar;
  final notifications = ref.watch(notificationServiceProvider);
  return MedicineSchedulerService(isar: isar, notificationService: notifications);
});
