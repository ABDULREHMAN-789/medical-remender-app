import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_helpers.dart';
import '../../../shared/models/report_model.dart';
import '../../../shared/providers/report_provider.dart';
import '../../../shared/widgets/custom_card.dart';
import '../../../shared/widgets/empty_state.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  String _getWeekdayLabel(int weekday) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    if (weekday < 1 || weekday > 7) return '';
    return labels[weekday - 1];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(reportProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final hasData = report.totalDoses > 0;

    // Calculations for PieChart
    final double takenPercent = report.totalDoses > 0 ? (report.takenDoses / report.totalDoses) * 100 : 0.0;
    final double skippedPercent = report.totalDoses > 0 ? (report.skippedDoses / report.totalDoses) * 100 : 0.0;
    final double missedPercent = report.totalDoses > 0 ? (report.missedDoses / report.totalDoses) * 100 : 0.0;

    // Bar chart groups (Last 7 Days)
    final now = DateTime.now();
    final List<BarChartGroupData> barGroups = [];
    for (int i = 6; i >= 0; i--) {
      final day = DateHelpers.startOfDay(now.subtract(Duration(days: i)));
      final stats = report.dailyAdherence[day] ?? DayAdherence(taken: 0, skipped: 0, missed: 0);
      final rate = stats.rate;

      barGroups.add(
        BarChartGroupData(
          x: 6 - i,
          barRods: [
            BarChartRodData(
              toY: rate,
              color: rate >= 85
                  ? AppColors.secondaryGreen
                  : (rate >= 50 ? AppColors.yellowWarning : AppColors.redAlert),
              width: 16,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Adherence Reports"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: !hasData
          ? const Padding(
              padding: EdgeInsets.all(20.0),
              child: EmptyState(
                icon: Icons.bar_chart_rounded,
                title: "No compliance data yet",
                description: "Statistics and charts will appear here as soon as you record your first dose logs.",
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary stats cards
                  Row(
                    children: [
                      Expanded(
                        child: CustomCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Adherence Rate", style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              const SizedBox(height: 8),
                              Text(
                                "${report.adherenceRate.toInt()}%",
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: report.adherenceRate >= 80 ? AppColors.secondaryGreen : AppColors.yellowWarning,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CustomCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Doses Logged", style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              const SizedBox(height: 8),
                              Text(
                                "${report.totalDoses}",
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Pie Chart Card
                  const Text("Doses Breakdown", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  CustomCard(
                    child: Column(
                      children: [
                        SizedBox(
                          height: 180,
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: 35,
                              sections: [
                                if (report.takenDoses > 0)
                                  PieChartSectionData(
                                    color: AppColors.secondaryGreen,
                                    value: report.takenDoses.toDouble(),
                                    title: '${takenPercent.toInt()}%',
                                    radius: 45,
                                    titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                if (report.skippedDoses > 0)
                                  PieChartSectionData(
                                    color: AppColors.yellowWarning,
                                    value: report.skippedDoses.toDouble(),
                                    title: '${skippedPercent.toInt()}%',
                                    radius: 45,
                                    titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                if (report.missedDoses > 0)
                                  PieChartSectionData(
                                    color: AppColors.redAlert,
                                    value: report.missedDoses.toDouble(),
                                    title: '${missedPercent.toInt()}%',
                                    radius: 45,
                                    titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Legends row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildLegendItem(AppColors.secondaryGreen, "Taken (${report.takenDoses})"),
                            _buildLegendItem(AppColors.yellowWarning, "Skipped (${report.skippedDoses})"),
                            _buildLegendItem(AppColors.redAlert, "Missed (${report.missedDoses})"),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Weekly adherence trends bar chart
                  const Text("Weekly Adherence Trend", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  CustomCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text("Compliance Rate (%)", style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 200,
                          child: BarChart(
                            BarChartData(
                              alignment: BarChartAlignment.spaceAround,
                              maxY: 100,
                              minY: 0,
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                horizontalInterval: 20,
                                getDrawingHorizontalLine: (val) => FlLine(
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                  strokeWidth: 1,
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              titlesData: FlTitlesData(
                                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (val, meta) {
                                      final index = val.toInt();
                                      if (index < 0 || index > 6) return const SizedBox.shrink();
                                      final targetDay = now.subtract(Duration(days: 6 - index));
                                      return SideTitleWidget(
                                        axisSide: meta.axisSide,
                                        child: Text(
                                          _getWeekdayLabel(targetDay.weekday),
                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              barGroups: barGroups,
                            ),
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

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      children: [
        Container(
          height: 12,
          width: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
