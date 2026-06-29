import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  Future<bool> requestNotificationPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  Future<bool> requestStoragePermission() async {
    // Check photos for media/image access, storage for files
    final photosStatus = await Permission.photos.request();
    if (photosStatus.isGranted || photosStatus.isLimited) return true;
    
    final storageStatus = await Permission.storage.request();
    return storageStatus.isGranted || storageStatus.isLimited;
  }

  Future<bool> hasNotificationPermission() async {
    return await Permission.notification.isGranted;
  }

  Future<bool> hasExactAlarmPermission() async {
    return await Permission.scheduleExactAlarm.isGranted;
  }

  Future<bool> requestExactAlarmPermission() async {
    final status = await Permission.scheduleExactAlarm.request();
    return status.isGranted;
  }

  Future<bool> checkAndRequestAll() async {
    final notification = await requestNotificationPermission();
    final camera = await requestCameraPermission();
    final storage = await requestStoragePermission();
    return notification && camera && storage;
  }
}
