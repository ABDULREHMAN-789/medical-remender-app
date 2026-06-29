import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_helpers.dart';
import '../../../shared/models/reminder_model.dart';
import '../../../shared/providers/medicine_provider.dart';
import '../../../shared/providers/service_providers.dart';

class AddMedicineScreen extends ConsumerStatefulWidget {
  const AddMedicineScreen({super.key});

  @override
  ConsumerState<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends ConsumerState<AddMedicineScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _quantityController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedType = 'Tablet';
  final List<String> _types = ['Tablet', 'Capsule', 'Syrup', 'Injection', 'Drops', 'Other'];

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));

  String? _imagePath;
  final ImagePicker _picker = ImagePicker();

  // Reminders
  String _reminderType = 'manual'; // 'manual' or 'interval'
  final List<String> _manualTimes = ['08:00 AM'];
  int _intervalHours = 8;
  final List<int> _intervalOptions = [4, 6, 8, 12, 24];

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    // Request permission first
    final permissionService = ref.read(permissionServiceProvider);
    bool granted = false;
    if (source == ImageSource.camera) {
      granted = await permissionService.requestCameraPermission();
    } else {
      granted = await permissionService.requestStoragePermission();
    }

    if (!granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera/Storage permission required to pick images.')),
        );
      }
      return;
    }

    try {
      final XFile? photo = await _picker.pickImage(source: source, imageQuality: 70);
      if (photo != null) {
        setState(() {
          _imagePath = photo.path;
        });
      }
    } catch (e, stackTrace) {
      debugPrint("Error picking image: $e\n$stackTrace");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to select image: $e')),
        );
      }
    }
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  Future<void> _addManualTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
    );

    if (picked != null && mounted) {
      final now = DateTime.now();
      final dt = DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
      final formatted = DateHelpers.formatTime(dt);
      
      setState(() {
        if (!_manualTimes.contains(formatted)) {
          _manualTimes.add(formatted);
          _manualTimes.sort((a, b) {
            // Sort times chronologically
            final aTime = DateHelpers.timeFormat.parse(a);
            final bTime = DateHelpers.timeFormat.parse(b);
            return aTime.compareTo(bTime);
          });
        }
      });
    }
  }

  void _removeManualTime(int index) {
    if (_manualTimes.length > 1) {
      setState(() {
        _manualTimes.removeAt(index);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least one reminder time is required.')),
      );
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_startDate.isAfter(_endDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Start Date must be before End Date.')),
      );
      return;
    }

    // Check exact alarm permission
    final permissionService = ref.read(permissionServiceProvider);
    final hasExact = await permissionService.hasExactAlarmPermission();
    if (!hasExact && mounted) {
      final grant = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Exact Alarms Permission"),
          content: const Text(
            "To receive medicine reminders precisely on time, please allow exact alarms in system settings. "
            "If you choose to skip, reminders might be slightly delayed.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Skip / Inexact"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Open Settings"),
            ),
          ],
        ),
      );
      if (grant == true) {
        await permissionService.requestExactAlarmPermission();
      }
    }

    if (!mounted) return;

    final qty = int.parse(_quantityController.text);

    // Build reminders list
    final List<Reminder> reminderSchedules = [];
    if (_reminderType == 'manual') {
      for (final time in _manualTimes) {
        reminderSchedules.add(Reminder()
          ..medicineId = 0 // Will be set in notifier
          ..reminderType = 'manual'
          ..timeOfDay = time
          ..isActive = true);
      }
    } else {
      reminderSchedules.add(Reminder()
        ..medicineId = 0
        ..reminderType = 'interval'
        ..timeOfDay = "Every $_intervalHours Hours"
        ..intervalHours = _intervalHours
        ..isActive = true);
    }

    try {
      await ref.read(medicineProvider.notifier).addMedicine(
            name: _nameController.text.trim(),
            type: _selectedType,
            dosage: _dosageController.text.trim(),
            quantity: qty,
            startDate: _startDate,
            endDate: _endDate,
            notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
            imagePath: _imagePath,
            reminderSchedules: reminderSchedules,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Medicine and schedules added successfully!')),
        );
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add medicine: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Medicine"),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo Picker Card
              Center(
                child: GestureDetector(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (ctx) => SafeArea(
                        child: Wrap(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.photo_camera_rounded),
                              title: const Text('Take Photo'),
                              onTap: () {
                                Navigator.pop(ctx);
                                _pickImage(ImageSource.camera);
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.photo_library_rounded),
                              title: const Text('Choose from Gallery'),
                              onTap: () {
                                Navigator.pop(ctx);
                                _pickImage(ImageSource.gallery);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  child: Container(
                    height: 120,
                    width: 120,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF141B2D) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0),
                        style: _imagePath == null ? BorderStyle.solid : BorderStyle.none,
                      ),
                      image: _imagePath != null
                          ? DecorationImage(
                              image: FileImage(File(_imagePath!)),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _imagePath == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.add_a_photo_rounded, color: AppColors.textSecondary, size: 32),
                              SizedBox(height: 8),
                              Text("Add Photo", style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                            ],
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Medicine Name Form Fields
              TextFormField(
                controller: _nameController,
                validator: (val) => val == null || val.trim().isEmpty ? "Medicine name is required" : null,
                decoration: const InputDecoration(
                  labelText: "Medicine Name *",
                  prefixIcon: Icon(Icons.drive_file_rename_outline_rounded),
                ),
              ),
              const SizedBox(height: 16),

              // Dosage Form Fields
              TextFormField(
                controller: _dosageController,
                validator: (val) => val == null || val.trim().isEmpty ? "Dosage is required (e.g. 1 pill)" : null,
                decoration: const InputDecoration(
                  labelText: "Dosage * (e.g. 1 Tablet, 10 ml)",
                  prefixIcon: Icon(Icons.scale_rounded),
                ),
              ),
              const SizedBox(height: 16),

              // Type & Quantity Row
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedType,
                      decoration: const InputDecoration(
                        labelText: "Type *",
                      ),
                      items: _types
                          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedType = val!;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return "Stock quantity required";
                        if (int.tryParse(val) == null || int.parse(val) <= 0) return "Must be positive int";
                        return null;
                      },
                      decoration: const InputDecoration(
                        labelText: "Initial Stock *",
                        prefixIcon: Icon(Icons.inventory_2_rounded),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Dates Selector Card
              InkWell(
                onTap: _selectDateRange,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF141B2D) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0)),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.calendar_today_rounded, color: AppColors.textSecondary),
                          SizedBox(width: 12),
                          Text("Course Duration", style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Text(
                        "${DateHelpers.formatReadableDate(_startDate)} - ${DateHelpers.formatReadableDate(_endDate)}",
                        style: const TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Reminder Type Chips
              const Text("Reminder Type", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text("Specific Times (Manual)"),
                    selected: _reminderType == 'manual',
                    onSelected: (selected) {
                      if (selected) setState(() => _reminderType = 'manual');
                    },
                  ),
                  ChoiceChip(
                    label: const Text("Interval Schedules"),
                    selected: _reminderType == 'interval',
                    onSelected: (selected) {
                      if (selected) setState(() => _reminderType = 'interval');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Reminder configurations
              if (_reminderType == 'manual') ...[
                const Text("Select Reminder Times", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _manualTimes.length,
                  itemBuilder: (ctx, idx) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_manualTimes[idx], style: const TextStyle(fontWeight: FontWeight.bold)),
                    leading: const Icon(Icons.alarm_rounded, color: AppColors.primaryBlue),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: AppColors.redAlert),
                      onPressed: () => _removeManualTime(idx),
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _addManualTime,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text("Add Reminder Time"),
                ),
              ] else ...[
                const Text("Frequency Interval", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: _intervalHours,
                  decoration: const InputDecoration(
                    labelText: "Repeat Every *",
                  ),
                  items: _intervalOptions
                      .map((h) => DropdownMenuItem(value: h, child: Text("Every $h Hours")))
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      _intervalHours = val!;
                    });
                  },
                ),
              ],
              const SizedBox(height: 24),

              // Notes
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: "Instructional Notes (Optional)",
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 32),

              // Submit Button
              ElevatedButton(
                onPressed: _submitForm,
                child: const Text("Save Medicine Course"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
