class PrayerDateUtils {
  /// The effective prayer date follows the device's
  /// local calendar date.
  ///
  /// Date changes only at midnight (00:00).
  /// It does not change at Maghrib or Isha.
  static DateTime effectiveDate(DateTime now) {
    return DateTime(
      now.year,
      now.month,
      now.day,
    );
  }

  static String effectiveDateString(DateTime now) {
    final date = effectiveDate(now);

    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  static int effectiveMonth(DateTime now) {
    return effectiveDate(now).month;
  }

  static int effectiveYear(DateTime now) {
    return effectiveDate(now).year;
  }

  static int effectiveDay(DateTime now) {
    return effectiveDate(now).day;
  }
}