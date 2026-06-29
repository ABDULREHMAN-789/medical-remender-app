import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_helpers.dart';
import '../../../shared/providers/medicine_provider.dart';
import '../../../shared/widgets/custom_card.dart';
import '../../../shared/widgets/empty_state.dart';

class MedicineListScreen extends ConsumerStatefulWidget {
  const MedicineListScreen({super.key});

  @override
  ConsumerState<MedicineListScreen> createState() => _MedicineListScreenState();
}

class _MedicineListScreenState extends ConsumerState<MedicineListScreen> {
  String _searchQuery = '';
  bool _showArchived = false;

  IconData _getMedicineIcon(String type) {
    switch (type.toLowerCase()) {
      case 'tablet':
        return Icons.trip_origin_rounded;
      case 'capsule':
        return Icons.medication_rounded;
      case 'syrup':
        return Icons.opacity_rounded;
      case 'injection':
        return Icons.vaccines_rounded;
      case 'drops':
        return Icons.water_drop_rounded;
      default:
        return Icons.medical_services_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final medicines = ref.watch(medicineProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Filter medicines
    final filteredMeds = medicines.where((med) {
      final matchesSearch = med.medicineName.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesArchiveStatus = med.isArchived == _showArchived;
      return matchesSearch && matchesArchiveStatus;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Medicines"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          children: [
            // Search Bar & Filter Chips
            const SizedBox(height: 12),
            TextField(
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
              decoration: const InputDecoration(
                hintText: "Search medications...",
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ChoiceChip(
                  label: const Text("Active"),
                  selected: !_showArchived,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _showArchived = false;
                      });
                    }
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text("Archived"),
                  selected: _showArchived,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _showArchived = true;
                      });
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Medicines List
            Expanded(
              child: filteredMeds.isEmpty
                  ? EmptyState(
                      icon: Icons.medication_rounded,
                      title: _searchQuery.isNotEmpty
                          ? "No matches found"
                          : (_showArchived ? "No archived medicines" : "No active medicines"),
                      description: _searchQuery.isNotEmpty
                          ? "Check your spelling or search another medicine."
                          : (_showArchived
                              ? "Completed or disabled medicine courses will be shown here."
                              : "Get started by logging your daily medicine courses."),
                      buttonText: _searchQuery.isNotEmpty || _showArchived ? null : "Add Medicine",
                      onButtonPressed: () => context.push('/medicines/add'),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: filteredMeds.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final med = filteredMeds[index];
                        final isLowStock = med.remainingQuantity <= 5;
                        final colorAccent = isLowStock && !med.isArchived ? AppColors.redAlert : AppColors.textSecondary;

                        return CustomCard(
                          onTap: () => context.push('/medicines/details/${med.id}'),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF141B2D) : const Color(0xFFECFDF5),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _getMedicineIcon(med.medicineType),
                                  color: isDark ? AppColors.primaryBlueDark : AppColors.primaryBlue,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      med.medicineName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "${med.medicineType} • ${med.dosage}",
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      "Course: ${DateHelpers.formatReadableDate(med.startDate)} - ${DateHelpers.formatReadableDate(med.endDate)}",
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    "${med.remainingQuantity} / ${med.quantity}",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: colorAccent,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    isLowStock && !med.isArchived
                                        ? (med.remainingQuantity == 0 ? "Out of Stock" : "Low Stock")
                                        : "Remaining",
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: colorAccent,
                                      fontWeight: isLowStock && !med.isArchived ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/medicines/add'),
        icon: const Icon(Icons.add),
        label: const Text("Add Medicine"),
        backgroundColor: isDark ? AppColors.primaryBlueDark : AppColors.primaryBlue,
        foregroundColor: isDark ? AppColors.onPrimaryDark : Colors.white,
      ),
    );
  }
}
