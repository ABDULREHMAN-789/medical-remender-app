import 'package:intl/intl.dart';

class DateHelpers {
  static final DateFormat timeFormat = DateFormat('hh:mm a');
  static final DateFormat dateFormat = DateFormat('yyyy-MM-dd');
  static final DateFormat readableDateFormat = DateFormat('MMM d, yyyy');

  /// Combines a Date with a Time string like "08:00 AM" or "02:00 PM"
  static DateTime combineDateAndTime(DateTime date, String timeStr) {
    try {
      final parsedTime = timeFormat.parse(timeStr.trim());
      return DateTime(
        date.year,
        date.month,
        date.day,
        parsedTime.hour,
        parsedTime.minute,
      );
    } catch (_) {
      // Fallback if parsing fails or timeStr is not in hh:mm a format
      try {
        final parts = timeStr.split(':');
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        return DateTime(date.year, date.month, date.day, hour, minute);
      } catch (_) {
        return DateTime(date.year, date.month, date.day, 8, 0); // Default to 8 AM
      }
    }
  }

  /// Formats DateTime into "08:00 AM"
  static String formatTime(DateTime dateTime) {
    return timeFormat.format(dateTime);
  }

  /// Formats DateTime into "2026-06-15"
  static String formatDate(DateTime dateTime) {
    return dateFormat.format(dateTime);
  }

  /// Formats DateTime into "Jun 15, 2026"
  static String formatReadableDate(DateTime dateTime) {
    return readableDateFormat.format(dateTime);
  }

  /// Gets the beginning of the day (00:00:00)
  static DateTime startOfDay(DateTime dateTime) {
    return DateTime(dateTime.year, dateTime.month, dateTime.day);
  }

  /// Gets the end of the day (23:59:59)
  static DateTime endOfDay(DateTime dateTime) {
    return DateTime(dateTime.year, dateTime.month, dateTime.day, 23, 59, 59, 999);
  }

  /// Checks if two dates are on the same day
  static bool isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }
}
