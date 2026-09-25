class ZoneMonthFile {
  final int zone;
  final int month;

  const ZoneMonthFile({
    required this.zone,
    required this.month,
  });

  String get zoneCode => zone.toString().padLeft(2, '0');

  String get monthCode => month.toString().padLeft(2, '0');

  String get remoteFileName => 'zone$zoneCode-$monthCode.json';

  String remoteUrl(String baseUrl) {
    return '$baseUrl$remoteFileName';
  }

  String get localRelativePath => 'zone$zoneCode/$monthCode.json';

  String get key => '$zone-$month';

  static List<ZoneMonthFile> all() {
    final List<ZoneMonthFile> list = [];

    for (int zone = 1; zone <= 13; zone++) {
      for (int month = 1; month <= 12; month++) {
        list.add(
          ZoneMonthFile(
            zone: zone,
            month: month,
          ),
        );
      }
    }

    return list;
  }
}