import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/report_model.dart';
import 'history_provider.dart';
import '../../core/utils/date_helpers.dart';

final reportProvider = Provider<ReportModel>((ref) {
  final historyList = ref.watch(historyProvider);
  if (historyList.isEmpty) {
    return ReportModel.empty();
  }

  int total = historyList.length;
  int taken = 0;
  int skipped = 0;
  int missed = 0;

  final Map<DateTime, int> dayTaken = {};
  final Map<DateTime, int> daySkipped = {};
  final Map<DateTime, int> dayMissed = {};

  for (final h in historyList) {
    final status = h.status;
    if (status == 'taken') {
      taken++;
    } else if (status == 'skipped') {
      skipped++;
    } else if (status == 'missed') {
      missed++;
    }

    final day = DateHelpers.startOfDay(h.scheduledTime);
    if (status == 'taken') {
      dayTaken[day] = (dayTaken[day] ?? 0) + 1;
    } else if (status == 'skipped') {
      daySkipped[day] = (daySkipped[day] ?? 0) + 1;
    } else if (status == 'missed') {
      dayMissed[day] = (dayMissed[day] ?? 0) + 1;
    }
  }

  final double adherenceRate = total > 0 ? (taken / total) * 100 : 0.0;

  final Map<DateTime, DayAdherence> dailyAdherence = {};
  final allDays = <DateTime>{...dayTaken.keys, ...daySkipped.keys, ...dayMissed.keys};
  for (final day in allDays) {
    dailyAdherence[day] = DayAdherence(
      taken: dayTaken[day] ?? 0,
      skipped: daySkipped[day] ?? 0,
      missed: dayMissed[day] ?? 0,
    );
  }

  return ReportModel(
    totalDoses: total,
    takenDoses: taken,
    skippedDoses: skipped,
    missedDoses: missed,
    adherenceRate: adherenceRate,
    dailyAdherence: dailyAdherence,
  );
});
