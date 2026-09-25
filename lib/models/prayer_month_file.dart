import 'prayer_day.dart';

class PrayerMonthFile {
  static List<PrayerDay>? tryParse(dynamic decodedJson) {
    if (decodedJson is! List || decodedJson.isEmpty) {
      return null;
    }

    final List<PrayerDay> days = [];

    for (final entry in decodedJson) {
      if (entry is! Map<String, dynamic>) {
        return null;
      }

      if (!entry.containsKey('date')) {
        return null;
      }

      days.add(PrayerDay.fromJson(entry));
    }

    return days;
  }
}