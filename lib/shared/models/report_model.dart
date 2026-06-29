class ReportModel {
  final int totalDoses;
  final int takenDoses;
  final int skippedDoses;
  final int missedDoses;
  final double adherenceRate;
  final Map<DateTime, DayAdherence> dailyAdherence;

  ReportModel({
    required this.totalDoses,
    required this.takenDoses,
    required this.skippedDoses,
    required this.missedDoses,
    required this.adherenceRate,
    required this.dailyAdherence,
  });

  factory ReportModel.empty() {
    return ReportModel(
      totalDoses: 0,
      takenDoses: 0,
      skippedDoses: 0,
      missedDoses: 0,
      adherenceRate: 0.0,
      dailyAdherence: {},
    );
  }
}

class DayAdherence {
  final int taken;
  final int skipped;
  final int missed;

  DayAdherence({
    required this.taken,
    required this.skipped,
    required this.missed,
  });

  double get rate {
    final total = taken + skipped + missed;
    if (total == 0) return 0.0;
    return (taken / total) * 100;
  }
}
