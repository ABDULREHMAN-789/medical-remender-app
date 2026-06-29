import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_helpers.dart';
import '../../../shared/providers/prescription_provider.dart';
import '../../../shared/providers/service_providers.dart';

class AddPrescriptionScreen extends ConsumerStatefulWidget {
  const AddPrescriptionScreen({super.key});

  @override
  ConsumerState<AddPrescriptionScreen> createState() => _AddPrescriptionScreenState();
}

class _AddPrescriptionScreenState extends ConsumerState<AddPrescriptionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _doctorNameController = TextEditingController();
  final _notesController = TextEditingController();
  
  DateTime _prescriptionDate = DateTime.now();
  String? _filePath;
  String? _fileName;

  final ImagePicker _imagePicker = ImagePicker();

  @override
  void dispose() {
    _doctorNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
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
          const SnackBar(content: Text('Permissions required to choose photos.')),
        );
      }
      return;
    }

    try {
      final XFile? image = await _imagePicker.pickImage(source: source, imageQuality: 70);
      if (image != null) {
        setState(() {
          _filePath = image.path;
          _fileName = image.name;
        });
      }
    } catch (e, stackTrace) {
      debugPrint("Image pick error: $e\n$stackTrace");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to select image: $e')),
        );
      }
    }
  }

  Future<void> _pickPDF() async {
    final permissionService = ref.read(permissionServiceProvider);
    final granted = await permissionService.requestStoragePermission();
    if (!granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Storage permission is required to choose files.')),
        );
      }
      return;
    }

    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _filePath = result.files.single.path;
          _fileName = result.files.single.name;
        });
      }
    } catch (e) {
      print("PDF pick error: $e");
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _prescriptionDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (picked != null) {
      setState(() {
        _prescriptionDate = picked;
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_filePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or capture a prescription file.')),
      );
      return;
    }

    try {
      await ref.read(prescriptionProvider.notifier).addPrescription(
            doctorName: _doctorNameController.text.trim(),
            date: _prescriptionDate,
            filePath: _filePath!,
            notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prescription uploaded successfully!')),
        );
        context.pop();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Prescription"),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Document attachment viewer box
              Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF141B2D) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: _filePath == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.description_rounded, size: 44, color: AppColors.textSecondary),
                          const SizedBox(height: 12),
                          const Text("No File Attached", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _pickPDF,
                                icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                                label: const Text("Attach PDF"),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(120, 40),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton.icon(
                                onPressed: () {
                                  showModalBottomSheet(
                                    context: context,
                                    builder: (ctx) => SafeArea(
                                      child: Wrap(
                                        children: [
                                          ListTile(
                                            leading: const Icon(Icons.photo_camera_rounded),
                                            title: const Text('Camera'),
                                            onTap: () {
                                              Navigator.pop(ctx);
                                              _pickImage(ImageSource.camera);
                                            },
                                          ),
                                          ListTile(
                                            leading: const Icon(Icons.photo_library_rounded),
                                            title: const Text('Gallery'),
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
                                icon: const Icon(Icons.photo_rounded, size: 18),
                                label: const Text("Attach Photo"),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(120, 40),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _fileName?.endsWith('.pdf') == true
                                ? Icons.picture_as_pdf_rounded
                                : Icons.image_rounded,
                            size: 44,
                            color: _fileName?.endsWith('.pdf') == true ? Colors.redAccent : AppColors.primaryBlue,
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              _fileName ?? "Attached File",
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _filePath = null;
                                _fileName = null;
                              });
                            },
                            style: TextButton.styleFrom(foregroundColor: AppColors.redAlert),
                            child: const Text("Remove File"),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 24),

              // Form inputs
              TextFormField(
                controller: _doctorNameController,
                validator: (val) => val == null || val.trim().isEmpty ? "Doctor name is required" : null,
                decoration: const InputDecoration(
                  labelText: "Doctor Name *",
                  prefixIcon: Icon(Icons.person_rounded),
                ),
              ),
              const SizedBox(height: 16),

              // Prescription Date Picker
              InkWell(
                onTap: _selectDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF141B2D) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.calendar_today_rounded, color: AppColors.textSecondary),
                          SizedBox(width: 12),
                          Text("Prescription Date", style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Text(
                        DateHelpers.formatReadableDate(_prescriptionDate),
                        style: const TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Notes
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: "Prescription Notes (Optional)",
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 32),

              // Submit
              ElevatedButton(
                onPressed: _submitForm,
                child: const Text("Save Prescription Details"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
