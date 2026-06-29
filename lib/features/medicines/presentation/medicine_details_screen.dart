import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_helpers.dart';
import '../../../shared/models/medicine_model.dart';
import '../../../shared/models/reminder_model.dart';
import '../../../shared/providers/medicine_provider.dart';
import '../../../shared/providers/reminder_provider.dart';
import '../../../shared/providers/service_providers.dart';
import '../../../shared/widgets/custom_card.dart';

class MedicineDetailsScreen extends ConsumerStatefulWidget {
  final int medicineId;
  const MedicineDetailsScreen({super.key, required this.medicineId});

  @override
  ConsumerState<MedicineDetailsScreen> createState() => _MedicineDetailsScreenState();
}

class _MedicineDetailsScreenState extends ConsumerState<MedicineDetailsScreen> {
  bool _isLoading = true;
  Medicine? _medicine;
  List<Reminder> _reminders = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadData();
  }

  Future<void> _loadData() async {
    final isar = ref.read(isarServiceProvider).isar;
    final med = await isar.collection<Medicine>().get(widget.medicineId);
    
    if (med == null) {
      if (mounted) {
        context.pop();
      }
      return;
    }

    final rems = await ref.read(reminderProvider.notifier).getRemindersForMedicine(widget.medicineId);

    setState(() {
      _medicine = med;
      _reminders = rems;
      _isLoading = false;
    });
  }

  Future<void> _toggleArchive() async {
    if (_medicine == null) return;

    if (_medicine!.isArchived) {
      // Unarchive
      final isar = ref.read(isarServiceProvider).isar;
      _medicine!.isArchived = false;
      _medicine!.updatedAt = DateTime.now();
      await isar.writeTxn(() async {
        await isar.collection<Medicine>().put(_medicine!);
      });
      // Re-schedule notifications
      await ref.read(medicineSchedulerServiceProvider).scheduleRemindersForMedicine(_medicine!);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Medicine unarchived successfully.')));
    } else {
      // Archive
      await ref.read(medicineProvider.notifier).archiveMedicine(_medicine!.id);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Medicine archived and reminders disabled.')));
    }

    await ref.read(medicineProvider.notifier).loadMedicines();
    _loadData();
  }

  Future<void> _deleteMedicine() async {
    if (_medicine == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Medicine?"),
        content: const Text("This will permanently delete this medicine course, all associated schedules, and all taken/missed log history. This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.redAlert),
            child: const Text("Delete permanently"),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await ref.read(medicineProvider.notifier).deleteMedicine(_medicine!.id);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Medicine course deleted permanently.')));
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _medicine == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final stockPercent = _medicine!.quantity > 0 ? _medicine!.remainingQuantity / _medicine!.quantity : 0.0;
    final isLowStock = _medicine!.remainingQuantity <= 5;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Medicine Details"),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => context.push('/medicines/edit/${_medicine!.id}').then((_) => _loadData()),
          ),
          IconButton(
            icon: Icon(_medicine!.isArchived ? Icons.unarchive_rounded : Icons.archive_rounded),
            onPressed: _toggleArchive,
          ),
          IconButton(
            icon: const Icon(Icons.delete_rounded, color: AppColors.redAlert),
            onPressed: _deleteMedicine,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image header if available
            if (_medicine!.imagePath != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.file(
                  File(_medicine!.imagePath!),
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 200,
                    width: double.infinity,
                    color: isDark ? AppColors.surfaceDark : const Color(0xFFF1F5F9),
                    child: const Icon(Icons.broken_image_rounded, size: 64, color: AppColors.textSecondary),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Title block
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _medicine!.medicineName,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${_medicine!.medicineType} • ${_medicine!.dosage}",
                        style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (_medicine!.isArchived)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.textSecondary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      "ARCHIVED",
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                    ),
                  )
              ],
            ),
            const Divider(height: 32),

            // Duration Details
            const Text("Course Duration", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            CustomCard(
              child: Row(
                children: [
                  const Icon(Icons.date_range_rounded, color: AppColors.primaryBlue),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Start: ${DateHelpers.formatReadableDate(_medicine!.startDate)}",
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "End: ${DateHelpers.formatReadableDate(_medicine!.endDate)}",
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Reminders
            const Text("Reminder Schedule", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ..._reminders.map((reminder) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: CustomCard(
                  child: Row(
                    children: [
                      Icon(
                        reminder.reminderType == 'manual' ? Icons.alarm_rounded : Icons.replay_rounded,
                        color: reminder.isActive ? AppColors.secondaryGreen : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              reminder.reminderType == 'manual'
                                  ? "Scheduled Time"
                                  : "Interval Timer",
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              reminder.timeOfDay,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: reminder.isActive,
                        activeColor: AppColors.secondaryGreen,
                        onChanged: _medicine!.isArchived
                            ? null
                            : (val) async {
                                await ref.read(reminderProvider.notifier).toggleReminderActive(reminder.id);
                                _loadData();
                              },
                      )
                    ],
                  ),
                ),
              );
            }).toList(),
            const SizedBox(height: 12),

            // Stock Tracking
            const Text("Inventory Stock", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            CustomCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${_medicine!.remainingQuantity} of ${_medicine!.quantity} left",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (isLowStock && !_medicine!.isArchived)
                        Text(
                          _medicine!.remainingQuantity == 0 ? "Out of Stock" : "Low Stock Alert!",
                          style: const TextStyle(color: AppColors.redAlert, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: stockPercent,
                      minHeight: 10,
                      backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isLowStock && !_medicine!.isArchived ? AppColors.redAlert : AppColors.primaryBlue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Notes
            if (_medicine!.notes != null && _medicine!.notes!.isNotEmpty) ...[
              const Text("Instructional Notes", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.1)),
              const SizedBox(height: 8),
              CustomCard(
                color: isDark ? const Color(0xFF141B2D) : const Color(0xFFF1F5F9),
                borderSide: BorderSide.none,
                child: Text(
                  _medicine!.notes!,
                  style: const TextStyle(height: 1.5, fontStyle: FontStyle.italic, fontSize: 13),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }
}
