import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/providers/service_providers.dart';
import '../../../shared/providers/theme_provider.dart';
import '../../../shared/providers/medicine_provider.dart';
import '../../../shared/providers/history_provider.dart';
import '../../../shared/providers/prescription_provider.dart';
import '../../../shared/providers/reminder_provider.dart';
import '../../../shared/widgets/custom_card.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notificationSound = true;
  bool _notificationVibrate = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotificationSettings();
  }

  Future<void> _loadNotificationSettings() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/theme_settings.json');
      if (await file.exists()) {
        final contents = await file.readAsString();
        final data = jsonDecode(contents) as Map<String, dynamic>;
        setState(() {
          _notificationSound = data['notificationSound'] as bool? ?? true;
          _notificationVibrate = data['notificationVibrate'] as bool? ?? true;
        });
      }
    } catch (_) {}
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _saveNotificationSetting(String key, bool val) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/theme_settings.json');
      Map<String, dynamic> data = {};
      if (await file.exists()) {
        final contents = await file.readAsString();
        data = Map<String, dynamic>.from(jsonDecode(contents));
      }
      data[key] = val;
      await file.writeAsString(jsonEncode(data));
    } catch (_) {}
  }

  Future<void> _exportBackup() async {
    try {
      final backupJson = await ref.read(backupServiceProvider).exportBackup();
      
      // Save it locally inside application documents directory first
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/medminder_backup_$timestamp.json');
      await file.writeAsString(backupJson);

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Backup Exported"),
            content: Text("Your backup file has been successfully generated and saved to:\n\n${file.path}"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Okay"),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export backup: $e')),
      );
    }
  }

  Future<void> _importBackup() async {
    // Request storage permission
    final permissionService = ref.read(permissionServiceProvider);
    final granted = await permissionService.requestStoragePermission();
    if (!granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Storage permission required to read backups.')),
        );
      }
      return;
    }

    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final contents = await file.readAsString();

        // Perform import restore
        await ref.read(backupServiceProvider).importBackup(contents);

        // Re-read schedules into notifications
        await ref.read(medicineSchedulerServiceProvider).rescheduleAllActiveMedicines();

        // Refresh all providers
        await ref.read(medicineProvider.notifier).loadMedicines();
        await ref.read(historyProvider.notifier).loadHistory();
        await ref.read(prescriptionProvider.notifier).loadPrescriptions();
        await ref.read(reminderProvider.notifier).loadReminders();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Database restored successfully from backup!')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to import backup: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = ref.watch(themeProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Appearance card
            const Text("Appearance", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            CustomCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded, color: AppColors.primaryBlue),
                title: const Text("Dark Theme Mode", style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text("Switch application visual mode"),
                trailing: Switch(
                  value: isDarkMode,
                  activeColor: AppColors.primaryBlueDark,
                  onChanged: (val) {
                    ref.read(themeProvider.notifier).toggleTheme();
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Notifications card
            const Text("Notification Preferences", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            CustomCard(
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.volume_up_rounded, color: AppColors.primaryBlue),
                    title: const Text("Notification Sound", style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text("Play sound on medicine schedule"),
                    trailing: Switch(
                      value: _notificationSound,
                      activeColor: AppColors.primaryBlueDark,
                      onChanged: (val) {
                        setState(() {
                          _notificationSound = val;
                        });
                        _saveNotificationSetting('notificationSound', val);
                      },
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.vibration_rounded, color: AppColors.primaryBlue),
                    title: const Text("Notification Vibration", style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text("Vibrate device on alerts"),
                    trailing: Switch(
                      value: _notificationVibrate,
                      activeColor: AppColors.primaryBlueDark,
                      onChanged: (val) {
                        setState(() {
                          _notificationVibrate = val;
                        });
                        _saveNotificationSetting('notificationVibrate', val);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Backup / Restore card
            const Text("Data Backup & Recovery", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            CustomCard(
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.cloud_upload_rounded, color: AppColors.secondaryGreen),
                    title: const Text("Export Backup", style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text("Generate and save local JSON database file"),
                    onTap: _exportBackup,
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.cloud_download_rounded, color: AppColors.secondaryGreen),
                    title: const Text("Import Backup", style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text("Choose JSON file and restore local database"),
                    onTap: _importBackup,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // About Card
            const Text("About App", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            CustomCard(
              color: isDark ? const Color(0xFF141B2D) : const Color(0xFFF1F5F9),
              borderSide: BorderSide.none,
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 28, color: AppColors.primaryBlue),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          "MedMinder v1.0.0",
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: -0.1),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "100% Offline-first local medicine reminder app, keeping your health logs completely private.",
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
