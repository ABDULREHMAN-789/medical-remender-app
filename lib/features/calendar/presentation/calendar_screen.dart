import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_helpers.dart';
import '../../../shared/providers/history_provider.dart';
import '../../../shared/widgets/custom_card.dart';
import '../../../shared/widgets/empty_state.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _selectedDate = DateHelpers.startOfDay(DateTime.now());
  DateTime _focusedMonth = DateTime.now();

  final List<String> _weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  int _getDaysInMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0).day;
  }

  int _getFirstWeekdayOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1).weekday % 7; // Sunday is 0, Monday is 1, etc.
  }

  void _previousMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(historyProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final daysInMonth = _getDaysInMonth(_focusedMonth);
    final firstWeekday = _getFirstWeekdayOfMonth(_focusedMonth);

    // Calculate total grid items (padding slots + calendar days)
    final totalGridItems = firstWeekday + daysInMonth;

    // Filter history for selected date
    final selectedDayHistory = history.where((h) {
      return DateHelpers.isSameDay(h.scheduledTime, _selectedDate);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Adherence Calendar"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Calendar Month Navigation
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "${_getMonthName(_focusedMonth.month)} ${_focusedMonth.year}",
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      onPressed: _previousMonth,
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      onPressed: _nextMonth,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Weekday Headers
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _weekdays.map((w) {
                return Expanded(
                  child: Center(
                    child: Text(
                      w,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),

            // Monthly Calendar Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: totalGridItems,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemBuilder: (context, index) {
                if (index < firstWeekday) {
                  return const SizedBox.shrink(); // Empty cells before the 1st
                }

                final dayNumber = index - firstWeekday + 1;
                final cellDate = DateTime(_focusedMonth.year, _focusedMonth.month, dayNumber);
                final isSelected = DateHelpers.isSameDay(cellDate, _selectedDate);
                final isToday = DateHelpers.isSameDay(cellDate, DateTime.now());

                // Find status logs for this cell date
                final dayLogs = history.where((h) => DateHelpers.isSameDay(h.scheduledTime, cellDate)).toList();
                
                final hasTaken = dayLogs.any((h) => h.status == 'taken');
                final hasSkipped = dayLogs.any((h) => h.status == 'skipped');
                final hasMissed = dayLogs.any((h) => h.status == 'missed');

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDate = cellDate;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isDark ? AppColors.primaryBlueDark : AppColors.primaryBlue)
                          : (isToday
                              ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF))
                              : Colors.transparent),
                      borderRadius: BorderRadius.circular(12),
                      border: isToday && !isSelected
                          ? Border.all(color: isDark ? AppColors.primaryBlueDark : AppColors.primaryBlue, width: 1.5)
                          : Border.all(color: Colors.transparent),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          dayNumber.toString(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isSelected
                                ? (isDark ? Colors.black : Colors.white)
                                : (isDark ? Colors.white : AppColors.onBackgroundLight),
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Indicator dots
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (hasTaken)
                              _buildDot(AppColors.secondaryGreen, isSelected),
                            if (hasSkipped)
                              _buildDot(AppColors.yellowWarning, isSelected),
                            if (hasMissed)
                              _buildDot(AppColors.redAlert, isSelected),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const Divider(height: 40),

            // Logs for Selected Date
            Text(
              "Logs for ${DateHelpers.formatReadableDate(_selectedDate)}",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            if (selectedDayHistory.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: EmptyState(
                  icon: Icons.history_toggle_off_rounded,
                  title: "No data available",
                  description: "You haven't recorded or missed any medicine doses on this day.",
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: selectedDayHistory.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final log = selectedDayHistory[index];
                  Color dotColor = Colors.grey;
                  if (log.status == 'taken') dotColor = AppColors.secondaryGreen;
                  if (log.status == 'skipped') dotColor = AppColors.yellowWarning;
                  if (log.status == 'missed') dotColor = AppColors.redAlert;

                  return CustomCard(
                    borderSide: BorderSide.none,
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 28,
                          decoration: BoxDecoration(
                            color: dotColor, 
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                log.medicineName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Dosage: ${log.dosage} • Time: ${DateHelpers.formatTime(log.scheduledTime)}",
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          log.status.toUpperCase(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: dotColor,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(Color color, bool isSelected) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1),
      height: 4,
      width: 4,
      decoration: BoxDecoration(
        color: isSelected ? Colors.white.withOpacity(0.8) : color,
        shape: BoxShape.circle,
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }
}
