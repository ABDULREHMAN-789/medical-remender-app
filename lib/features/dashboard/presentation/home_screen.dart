import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/date_helpers.dart';
import '../../../shared/providers/dashboard_provider.dart';
import '../../../shared/providers/history_provider.dart';
import '../../../shared/widgets/custom_card.dart';
import '../../../shared/widgets/empty_state.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return AppStrings.greetingMorning;
    } else if (hour < 17) {
      return AppStrings.greetingAfternoon;
    } else {
      return AppStrings.greetingEvening;
    }
  }

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

  void _onBottomNavTapped(int index) {
    setState(() {
      _currentIndex = index;
    });

    switch (index) {
      case 0:
        // Already home
        break;
      case 1:
        context.push('/medicines');
        break;
      case 2:
        context.push('/calendar');
        break;
      case 3:
        context.push('/prescriptions');
        break;
      case 4:
        context.push('/reports');
        break;
      case 5:
        context.push('/settings');
        break;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Sync index if we pop back from other screens
    setState(() {
      _currentIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dashboardState = ref.watch(dashboardProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${_getGreeting()}, User",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.onBackgroundLight,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateHelpers.formatReadableDate(DateTime.now()),
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => context.push('/settings'),
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceDark : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: const Icon(Icons.settings_rounded),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Progress Card
              CustomCard(
                color: isDark ? const Color(0xFF141B2D) : const Color(0xFFECFDF5),
                borderSide: BorderSide.none,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Today's Progress",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "You have taken ${((dashboardState.todayProgress) * 100).toInt()}% of your doses scheduled for today.",
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          height: 64,
                          width: 64,
                          child: CircularProgressIndicator(
                            value: dashboardState.todayProgress,
                            strokeWidth: 6,
                            backgroundColor: isDark ? const Color(0xFF151E2E) : const Color(0xFFD1FAE5),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isDark ? AppColors.primaryBlueDark : AppColors.primaryBlue,
                            ),
                          ),
                        ),
                        Text(
                          "${(dashboardState.todayProgress * 100).toInt()}%",
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            letterSpacing: -0.2,
                          ),
                        )
                      ],
                    )
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Next reminder & Counts row
              Row(
                children: [
                  Expanded(
                    child: CustomCard(
                      height: 120, // Grid height helper
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Icon(Icons.timer_outlined, color: AppColors.secondaryGreen),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Next Medicine",
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                dashboardState.nextDose != null
                                    ? "${dashboardState.nextDose!.medicine.medicineName} (${DateHelpers.formatTime(dashboardState.nextDose!.scheduledTime)})"
                                    : "No more today",
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CustomCard(
                      height: 120,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Icon(Icons.medication_rounded, color: AppColors.primaryBlue),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Active Medicines",
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "${dashboardState.activeMedicinesCount} Active Course(s)",
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Stock alerts card if low stock exists
              if (dashboardState.stockAlerts.isNotEmpty) ...[
                CustomCard(
                  color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2),
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFF991B1B) : const Color(0xFFFCA5A5),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppColors.redAlert),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Stock Alert: ${dashboardState.stockAlerts.length} medicine(s) running extremely low!",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF991B1B),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.push('/medicines'),
                        child: const Text("Refill"),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Schedule Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Today's Schedule",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.onBackgroundLight,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/medicines'),
                    child: const Text("View All"),
                  )
                ],
              ),
              const SizedBox(height: 12),

              if (dashboardState.todayDoses.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: EmptyState(
                    icon: Icons.done_all_rounded,
                    title: "All clean!",
                    description: "No medicines scheduled for today. Add a new medicine course to start.",
                    buttonText: "Add Medicine",
                    onButtonPressed: () => context.push('/medicines/add'),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: dashboardState.todayDoses.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final dose = dashboardState.todayDoses[index];
                    final med = dose.medicine;
                    final time = dose.scheduledTime;
                    final status = dose.status;

                    Color statusColor = Colors.grey;
                    if (status == 'taken') statusColor = AppColors.secondaryGreen;
                    if (status == 'skipped') statusColor = AppColors.yellowWarning;
                    if (status == 'missed') statusColor = AppColors.redAlert;
                    if (status == 'scheduled') statusColor = isDark ? AppColors.primaryBlueDark : AppColors.primaryBlue;

                    return CustomCard(
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
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "${med.dosage} • ${DateHelpers.formatTime(time)}",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: status == 'scheduled'
                                        ? (isDark ? const Color(0xFF162E3B) : const Color(0xFFE0F2FE))
                                        : status == 'taken'
                                            ? (isDark ? const Color(0xFF143026) : const Color(0xFFD1FAE5))
                                            : status == 'skipped'
                                                ? (isDark ? const Color(0xFF382914) : const Color(0xFFFEF3C7))
                                                : (isDark ? const Color(0xFF3B1D1D) : const Color(0xFFFFE4E6)),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    status == 'scheduled' ? 'PENDING' : status.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: statusColor,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (status == 'scheduled') ...[
                            IconButton(
                              icon: const Icon(Icons.check_circle_outline_rounded, color: AppColors.secondaryGreen),
                              onPressed: () {
                                ref.read(historyProvider.notifier).logDose(
                                      medicineId: med.id,
                                      medicineName: med.medicineName,
                                      dosage: med.dosage,
                                      scheduledTime: time,
                                      status: 'taken',
                                      reminderId: dose.reminder.id,
                                    );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Dose marked as Taken!')),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.cancel_outlined, color: AppColors.yellowWarning),
                              onPressed: () {
                                ref.read(historyProvider.notifier).logDose(
                                      medicineId: med.id,
                                      medicineName: med.medicineName,
                                      dosage: med.dosage,
                                      scheduledTime: time,
                                      status: 'skipped',
                                      reminderId: dose.reminder.id,
                                    );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Dose marked as Skipped!')),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onBottomNavTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: isDark ? AppColors.primaryBlueDark : AppColors.primaryBlue,
        unselectedItemColor: AppColors.textSecondary,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.medication_rounded),
            label: 'Meds',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_rounded),
            label: 'Calendar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.description_rounded),
            label: 'Presc',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_rounded),
            label: 'Reports',
          ),
        ],
      ),
    );
  }
}
