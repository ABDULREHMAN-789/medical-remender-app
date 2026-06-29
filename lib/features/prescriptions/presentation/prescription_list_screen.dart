import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_helpers.dart';
import '../../../shared/models/prescription_model.dart';
import '../../../shared/providers/prescription_provider.dart';
import '../../../shared/widgets/custom_card.dart';
import '../../../shared/widgets/empty_state.dart';

class PrescriptionListScreen extends ConsumerWidget {
  const PrescriptionListScreen({super.key});

  void _viewPrescription(BuildContext context, Prescription prescription) {
    final isImage = prescription.filePath.endsWith('.png') ||
        prescription.filePath.endsWith('.jpg') ||
        prescription.filePath.endsWith('.jpeg');

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Dr. ${prescription.doctorName}",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                "Prescription Date: ${DateHelpers.formatReadableDate(prescription.prescriptionDate)}",
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              if (isImage)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(prescription.filePath),
                    height: 300,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_rounded, size: 64),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: const [
                      Icon(Icons.picture_as_pdf_rounded, size: 48, color: Colors.red),
                      SizedBox(height: 8),
                      Text("PDF Document Saved", style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              if (prescription.notes != null && prescription.notes!.isNotEmpty) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text("Notes:", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(prescription.notes!),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                "Local Path: ${prescription.filePath}",
                style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prescriptions = ref.watch(prescriptionProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Prescriptions"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: prescriptions.isEmpty
            ? EmptyState(
                icon: Icons.description_rounded,
                title: "No prescriptions uploaded",
                description: "Keep copy of your doctor's prescriptions securely stored completely offline.",
                buttonText: "Add Prescription",
                onButtonPressed: () => context.push('/prescriptions/add'),
              )
            : ListView.separated(
                padding: const EdgeInsets.only(top: 12, bottom: 80),
                itemCount: prescriptions.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final presc = prescriptions[index];
                  final isPdf = presc.filePath.endsWith('.pdf');

                  return CustomCard(
                    onTap: () => _viewPrescription(context, presc),
                    borderSide: BorderSide.none,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF141B2D) : const Color(0xFFECFDF5),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                            color: isPdf ? Colors.redAccent : AppColors.primaryBlue,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Dr. ${presc.doctorName}",
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateHelpers.formatReadableDate(presc.prescriptionDate),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              if (presc.notes != null && presc.notes!.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  presc.notes!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.redAlert),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text("Delete Prescription?"),
                                content: const Text("Are you sure you want to remove this prescription?"),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text("Cancel"),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    style: TextButton.styleFrom(foregroundColor: AppColors.redAlert),
                                    child: const Text("Delete"),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              await ref.read(prescriptionProvider.notifier).deletePrescription(presc.id);
                            }
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/prescriptions/add'),
        icon: const Icon(Icons.add),
        label: const Text("Add Prescription"),
        backgroundColor: isDark ? AppColors.primaryBlueDark : AppColors.primaryBlue,
        foregroundColor: isDark ? AppColors.onPrimaryDark : Colors.white,
      ),
    );
  }
}
