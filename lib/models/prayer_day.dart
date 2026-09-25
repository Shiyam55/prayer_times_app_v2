class PrayerDay {
  final String date;
  final String fajr;
  final String sunrise;
  final String zuhr;
  final String asr;
  final String maghrib;
  final String isha;

  const PrayerDay({
    required this.date,
    required this.fajr,
    required this.sunrise,
    required this.zuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
  });

  factory PrayerDay.fromJson(Map<String, dynamic> json) {
    return PrayerDay(
      date: json['date']?.toString() ?? '',
      fajr: json['fajr']?.toString() ?? '',
      sunrise: json['sunrise']?.toString() ?? '',
      zuhr: json['zuhr']?.toString() ?? '',
      asr: json['asr']?.toString() ?? '',
      maghrib: json['maghrib']?.toString() ?? '',
      isha: json['isha']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'fajr': fajr,
      'sunrise': sunrise,
      'zuhr': zuhr,
      'asr': asr,
      'maghrib': maghrib,
      'isha': isha,
    };
  }

  List<MapEntry<String, String>> get displayEntries {
    return [
      MapEntry('Fajr', fajr),
      MapEntry('Sunrise', sunrise),
      MapEntry('Zuhr', zuhr),
      MapEntry('Asr', asr),
      MapEntry('Maghrib', maghrib),
      MapEntry('Isha', isha),
    ];
  }
}