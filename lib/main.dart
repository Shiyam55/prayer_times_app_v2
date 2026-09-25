import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'models/prayer_day.dart';
import 'models/zone_month_file.dart';
import 'repository/prayer_time_repository.dart';

void main() {
  runApp(const MasjidIdApp());
}

final PrayerTimeRepository prayerTimeRepository = PrayerTimeRepository();

class MasjidIdApp extends StatelessWidget {
  const MasjidIdApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'MASJID ID Prayer Times',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF087F5B),
          ),
        ),
        home: const PrayerHomeScreen(),
      );
}

class ZoneData {
  final String keyName, title, subtitle;
  final Color color;

  const ZoneData({
    required this.keyName,
    required this.title,
    required this.subtitle,
    required this.color,
  });
}

class PrayerData {
  final String icon, name, keyName;

  const PrayerData(this.icon, this.name, this.keyName);
}

const allZoneDefinitions = <ZoneData>[
  ZoneData(
    keyName: 'zone1',
    title: 'WESTERN',
    subtitle: 'Colombo, Gampaha & Kalutara District',
    color: Color(0xFF087F5B),
  ),
  ZoneData(
    keyName: 'zone2',
    title: 'ZONE 02 – JAFFNA',
    subtitle: 'Jaffna & Nallur',
    color: Color(0xFF1565C0),
  ),
  ZoneData(
    keyName: 'zone3',
    title: 'ZONE 03 – MULLAITIVU',
    subtitle: 'Mullaitivu District (Except Nallurs, Kilinochchi, Vavuniya District)',
    color: Color(0xFFD71920),
  ),
  ZoneData(
    keyName: 'zone4',
    title: 'ZONE 04 – MANNAR',
    subtitle: 'Mannar & Puttalam District',
    color: Color(0xFF7B1FA2),
  ),
  ZoneData(
    keyName: 'zone5',
    title: 'ZONE 05 – ANURADHAPURA',
    subtitle: 'Anuradhapura & Polonnaruwa District',
    color: Color(0xFFE65100),
  ),
  ZoneData(
    keyName: 'zone6',
    title: 'ZONE 06 – KURUNEGALA',
    subtitle: 'Kurunegala District',
    color: Color(0xFF00695C),
  ),
  ZoneData(
    keyName: 'zone7',
    title: 'CENTRAL',
    subtitle: 'Kandy, Matale & Nuwara Eliya District',
    color: Color(0xFF1565C0),
  ),
  ZoneData(
    keyName: 'zone8',
    title: 'EASTERN',
    subtitle: 'Batticaloa & Ampara District',
    color: Color(0xFFD71920),
  ),
  ZoneData(
    keyName: 'zone9',
    title: 'ZONE 09 – TRINCOMALEE',
    subtitle: 'Trincomalee District',
    color: Color(0xFF00838F),
  ),
  ZoneData(
    keyName: 'zone10',
    title: 'ZONE 10 – BADULLA',
    subtitle: 'Badulla & Monaragala District, Dehiattakandiya, Embilipitiya',
    color: Color(0xFF6D4C41),
  ),
  ZoneData(
    keyName: 'zone11',
    title: 'ZONE 11 – RATNAPURA',
    subtitle: 'Ratnapura & Kegalle District',
    color: Color(0xFF558B2F),
  ),
  ZoneData(
    keyName: 'zone12',
    title: 'ZONE 12 – GALLE',
    subtitle: 'Galle & Matara District',
    color: Color(0xFF283593),
  ),
  ZoneData(
    keyName: 'zone13',
    title: 'ZONE 13 – HAMBANTOTA',
    subtitle: 'Hambantota District',
    color: Color(0xFFAD1457),
  ),
];

String dateKey(DateTime d) =>
    '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

int minutesOf(String value) {
  final parts = value.split(':');
  if (parts.length != 2) return 9999;
  final hour = int.tryParse(parts[0]) ?? 0;
  final minute = int.tryParse(parts[1]) ?? 0;
  return hour * 60 + minute;
}

String to12Hour(String value) {
  final parts = value.split(':');
  if (parts.length != 2) return value;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return value;
  final suffix = hour >= 12 ? 'PM' : 'AM';
  final h = hour % 12 == 0 ? 12 : hour % 12;
  return '$h:${minute.toString().padLeft(2, '0')} $suffix';
}

/// Applies the per-prayer minute adjustment from AppSettings to a raw
/// 'HH:MM' value and returns a new 'HH:MM' string.
String applyPrayerAdjustment(String raw, String prayerKey) {
  final offset = AppSettings.instance.prayerAdjustments[prayerKey] ?? 0;
  if (offset == 0) return raw;
  final total = minutesOf(raw);
  if (total == 9999) return raw;
  final adjusted = (total + offset) % 1440;
  return '${(adjusted ~/ 60).toString().padLeft(2, '0')}:'
      '${(adjusted % 60).toString().padLeft(2, '0')}';
}

bool hasPrayerData(String zoneKey) =>
    allZoneDefinitions.any((zone) => zone.keyName == zoneKey);

String effectiveDateString(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

Future<Map<String, dynamic>> loadPrayerDataForDate({
  required DateTime date,
  required List<ZoneData> zoneList,
  bool refreshOnline = true,
}) async {
  final result = <String, dynamic>{};

  for (final zone in zoneList) {
    PrayerDay? day = await prayerTimeRepository.readToday(
      zone: int.parse(zone.keyName.replaceFirst('zone', '')),
      month: date.month,
      effectiveDateString: effectiveDateString(date),
    );

    // Online refresh is attempted only after checking the local cache.
    // If the network is unavailable, the cached value remains usable.
    if (refreshOnline) {
      final file = ZoneMonthFile(
        zone: int.parse(zone.keyName.replaceFirst('zone', '')),
        month: date.month,
      );
      await prayerTimeRepository.updateOneIfChanged(file);
      day = await prayerTimeRepository.readToday(
        zone: file.zone,
        month: file.month,
        effectiveDateString: effectiveDateString(date),
      ) ?? day;
    }

    if (day != null) {
      result[zone.keyName] = <String, dynamic>{
        dateKey(date): day.toJson(),
      };
    }
  }

  return result;
}


String clock12(DateTime value) {
  final suffix = value.hour >= 12 ? 'PM' : 'AM';
  final h = value.hour % 12 == 0 ? 12 : value.hour % 12;
  return '$h:${value.minute.toString().padLeft(2, '0')}:${value.second.toString().padLeft(2, '0')} $suffix';
}

List<ZoneData> get zones {
  // Main interface always displays the three required zones.
  const mainZoneKeys = ['zone1', 'zone7', 'zone8'];
  return mainZoneKeys
      .map((key) => allZoneDefinitions.firstWhere((z) => z.keyName == key))
      .toList();
}

const prayers = <PrayerData>[
  PrayerData('', 'Fajr', 'fajr'),
  PrayerData('', 'Sunrise', 'sunrise'),
  PrayerData('', 'Zuhr', 'zuhr'),
  PrayerData('', 'Asr', 'asr'),
  PrayerData('', 'Maghrib', 'maghrib'),
  PrayerData('', 'Isha', 'isha'),
];

class HijriDateInfo {
  final int day;
  final int month;
  final int year;
  final String monthName;
  final String monthNameArabic;

  const HijriDateInfo({
    required this.day,
    required this.month,
    required this.year,
    required this.monthName,
    required this.monthNameArabic,
  });

  HijriDateInfo copyWith({int? day, int? month, int? year}) {
    return HijriDateInfo(
      day: day ?? this.day,
      month: month ?? this.month,
      year: year ?? this.year,
      monthName: monthName,
      monthNameArabic: monthNameArabic,
    );
  }
}

class HijriCalendarService {
  static const Map<String, int> _rabiAlThani1448 = {
    '2026-09-13': 1, '2026-09-14': 2, '2026-09-15': 3,
    '2026-09-16': 4, '2026-09-17': 5, '2026-09-18': 6,
    '2026-09-19': 7, '2026-09-20': 8, '2026-09-21': 9,
    '2026-09-22': 10, '2026-09-23': 11, '2026-09-24': 12,
    '2026-09-25': 13, '2026-09-26': 14, '2026-09-27': 15,
    '2026-09-28': 16, '2026-09-29': 17, '2026-09-30': 18,
    '2026-10-01': 19, '2026-10-02': 20, '2026-10-03': 21,
    '2026-10-04': 22, '2026-10-05': 23, '2026-10-06': 24,
    '2026-10-07': 25, '2026-10-08': 26, '2026-10-09': 27,
    '2026-10-10': 28, '2026-10-11': 29, '2026-10-12': 30,
  };

  static Future<HijriDateInfo?> getForGregorian(DateTime date) async {
    final key =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final day = _rabiAlThani1448[key];
    if (day == null) return null;
    return HijriDateInfo(
      day: day,
      month: 4,
      year: 1448,
      monthName: 'Rabi al-Thani',
      monthNameArabic: 'ربيع الثاني',
    );
  }
}

class HijriCalendarInfoScreen extends StatelessWidget {
  const HijriCalendarInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Hilāl Calendar',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'RABIUNIL AKHIR',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            '1448 AH',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          const Text(
            'Calendar mapping used in this build:',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            '1 Rabi al-Thani 1448 = 13 September 2026\n'
            '10 Rabi al-Thani 1448 = 22 September 2026\n'
            '30 Rabi al-Thani 1448 = 12 October 2026',
          ),
        ],
      ),
    );
  }
}

class PrayerHomeScreen extends StatefulWidget {
  const PrayerHomeScreen({super.key});

  @override
  State<PrayerHomeScreen> createState() => _PrayerHomeScreenState();
}

class _PrayerHomeScreenState extends State<PrayerHomeScreen> {
  Map<String, dynamic>? data;
  HijriDateInfo? hijriDate;
  Timer? timer;
  DateTime now = DateTime.now();
  bool tomorrowSelected = false;
  int _lastHijriAdjustment = 0;
  DateTime? _lastShownDate;

  @override
  void initState() {
    super.initState();
    _lastHijriAdjustment = AppSettings.instance.hijriAdjustment;
    _loadData();

    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;

      final newNow = DateTime.now();

      setState(() => now = newNow);

      // shownDate flips at midnight and after 20:00. Reload prayer data
      // and the Hijri date whenever the displayed date actually changes.
      final current = shownDate;
      if (_lastShownDate == null ||
          !_lastShownDate!.isAtSameMomentAs(current) ||
          AppSettings.instance.hijriAdjustment != _lastHijriAdjustment) {
        _lastHijriAdjustment = AppSettings.instance.hijriAdjustment;
        _loadData();
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    _lastShownDate = shownDate;
    try {
      final loaded = await loadPrayerDataForDate(
        date: shownDate,
        zoneList: zones,
      );

      if (!mounted) return;
      setState(() => data = loaded);
    } catch (_) {
      if (!mounted) return;
      setState(() => data = {});
    }
    await _loadHijriDate();
  }

  Future<void> _loadHijriDate() async {
    final result = await HijriCalendarService.getForGregorian(shownDate);
    if (!mounted) return;
    setState(() {
      hijriDate = result == null
          ? null
          : result.copyWith(
              day: (result.day + AppSettings.instance.hijriAdjustment)
                  .clamp(1, 30),
            );
    });
  }

  DateTime get shownDate {
    final today = DateTime(now.year, now.month, now.day);

    return (tomorrowSelected || now.hour >= 20)
        ? today.add(const Duration(days: 1))
        : today;
  }

  String _dateKey(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Map<String, String> _timesFor(String zoneKey) {
    final zone = data?[zoneKey];

    if (zone is! Map) return {};

    final day = zone[_dateKey(shownDate)];

    if (day is! Map) return {};

    return day.map<String, String>(
      (key, value) => MapEntry(
        key.toString(),
        applyPrayerAdjustment(value.toString(), key.toString()),
      ),
    );
  }

  String _to12Hour(String value) {
    final p = value.split(':');

    if (p.length != 2) return value;

    final h = int.tryParse(p[0]) ?? 0;
    final m = int.tryParse(p[1]) ?? 0;

    final period = h >= 12 ? 'PM' : 'AM';
    final hour = h % 12 == 0 ? 12 : h % 12;

    return '$hour:${m.toString().padLeft(2, '0')} $period';
  }

  String _clock() {
    final h = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final p = now.hour >= 12 ? 'PM' : 'AM';

    return '$h:${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')} $p';
  }

  String _weekday(DateTime d) {
    const x = [
      'MONDAY',
      'TUESDAY',
      'WEDNESDAY',
      'THURSDAY',
      'FRIDAY',
      'SATURDAY',
      'SUNDAY',
    ];

    return x[d.weekday - 1];
  }

  String _tamilWeekday(DateTime d) {
    const x = [
      'திங்கட்கிழமை',
      'செவ்வாய்க்கிழமை',
      'புதன்கிழமை',
      'வியாழக்கிழமை',
      'வெள்ளிக்கிழமை',
      'சனிக்கிழமை',
      'ஞாயிற்றுக்கிழமை',
    ];

    return x[d.weekday - 1];
  }

  String _nextPrayer() {
    if (tomorrowSelected || now.hour >= 20) {
      return 'Tomorrow';
    }

    final times = _timesFor(zones.isEmpty ? 'zone1' : zones.first.keyName);
    final current = now.hour * 60 + now.minute;

    for (final prayer in prayers) {
      final value = times[prayer.keyName];

      if (value == null) continue;

      final p = value.split(':');

      if (p.length != 2) continue;

      final minutes =
          (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0);

      if (minutes > current) {
        final diff = minutes - current;

        return '${prayer.name} • ${diff ~/ 60}h ${diff % 60}m';
      }
    }

    return 'Tomorrow';
  }

  String _hijriMonthDisplay() {
    final name = hijriDate?.monthName.toLowerCase() ?? '';

    // The app display requested by you:
    // RABIUNIL AKHIR = Rabi al-Akhir / Rabi al-Thani.
    if (name.contains('rabi') &&
        (name.contains('thani') || name.contains('akhir'))) {
      return 'RABIUNIL AKHIR';
    }

    if (hijriDate == null) return 'HIJRI CALENDAR';

    return hijriDate!.monthName.toUpperCase();
  }

  String _hijriSecondLine() {
    if (hijriDate == null) {
      return 'HIJRI DATE';
    }

    return '${hijriDate!.year} AH   •   DATE ${hijriDate!.day}';
  }

  void _openSharePreview() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PrayerSharePreviewScreen(
          shownDate: shownDate,
          hijriDate: hijriDate,
          data: data ?? <String, dynamic>{},
          selectedZones: List<ZoneData>.from(zones),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = shownDate;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        centerTitle: true,
        title: const SizedBox.shrink(),
        actions: [
          IconButton(
            tooltip: 'Share Prayer Times',
            icon: const Icon(Icons.share_outlined),
            onPressed: _openSharePreview,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SettingsScreen(),
                ),
              ).then((_) {
                if (mounted) _loadData();
              });
            },
          ),
        ],
      ),
      body: data == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(8, 2, 8, 10),
                children: [
                  _header(),
                  const SizedBox(height: 5),
                  _dateBar(d),
                  const SizedBox(height: 5),
                  _prayerTable(),
                  const SizedBox(height: 5),
                  _dua(),
                ],
              ),
            ),
    );
  }

  Widget _header() => SizedBox(
        height: 58,
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: const BoxDecoration(
                  color: Color(0xFF1455C0),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _hijriMonthDisplay(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 1),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _hijriSecondLine(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFD71920),
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: const Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'PRAYER TIMES',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _dateBar(DateTime d) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFFFD91A),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  Text(
                    '${d.day.toString().padLeft(2, '0')}.'
                    '${d.month.toString().padLeft(2, '0')}.${d.year}',
                    style: const TextStyle(
                      color: Color(0xFF173B9B),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    '${_weekday(d)} — ${_tamilWeekday(d)}',
                    style: const TextStyle(
                      color: Color(0xFF173B9B),
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            OutlinedButton(
              onPressed: () {
                setState(() {
                  tomorrowSelected = !tomorrowSelected;
                });
                _loadData();
                _loadHijriDate();
              },
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 24),
                padding: const EdgeInsets.symmetric(horizontal: 5),
                visualDensity: VisualDensity.compact,
              ),
              child: Text(
                tomorrowSelected ? 'TODAY' : 'TOMORROW →',
                style: const TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      );


  Widget _prayerTable() => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: const Color(0xFFD9DFE3),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                _headerCell('SALAH', Colors.black87),
                for (final zone in zones)
                  _headerCell(zone.title, zone.color),
              ],
            ),
            for (final prayer in prayers) _prayerRow(prayer),
          ],
        ),
      );

  Widget _headerCell(String text, Color color) => Expanded(
        child: Container(
          height: 31,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 2),
          color: color,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 7,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      );

  Widget _prayerRow(PrayerData prayer) => SizedBox(
        height: 34,
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: FittedBox(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    prayer.name,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
            for (final zone in zones)
              Expanded(
                child: Container(
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: Color(0xFFE2E7EA),
                      ),
                      left: BorderSide(
                        color: Color(0xFFE2E7EA),
                      ),
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _to12Hour(
                        _timesFor(zone.keyName)[prayer.keyName] ?? '--:--',
                      ),
                      style: TextStyle(
                        color: zone.color,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );

  Widget _dua() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFFD91A),
          borderRadius: BorderRadius.circular(9),
        ),
        child: const Column(
          children: [
            Text(
              'اللهم أعنا على ذكرك وشكرك وحسن عبادتك',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 2),
            Text(
              '"O Allah, help us remember You, thank You, and worship You in the best manner."',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
}


class PrayerSharePreviewScreen extends StatefulWidget {
  final DateTime shownDate;
  final HijriDateInfo? hijriDate;
  final Map<String, dynamic> data;
  final List<ZoneData> selectedZones;

  const PrayerSharePreviewScreen({
    super.key,
    required this.shownDate,
    required this.hijriDate,
    required this.data,
    required this.selectedZones,
  });

  @override
  State<PrayerSharePreviewScreen> createState() =>
      _PrayerSharePreviewScreenState();
}

class _PrayerSharePreviewScreenState extends State<PrayerSharePreviewScreen> {
  final GlobalKey _shareKey = GlobalKey();
  bool sharing = false;

  Map<String, String> _times(String zoneKey) {
    final zone = widget.data[zoneKey];
    if (zone is! Map) return <String, String>{};

    final day = zone[dateKey(widget.shownDate)];
    if (day is! Map) return <String, String>{};

    return day.map<String, String>(
      (key, value) => MapEntry(
        key.toString(),
        applyPrayerAdjustment(value.toString(), key.toString()),
      ),
    );
  }

  String _hijriMonth() {
    final name = widget.hijriDate?.monthName.toLowerCase() ?? '';
    if (name.contains('rabi') &&
        (name.contains('thani') || name.contains('akhir'))) {
      return 'RABIUNIL AKHIR';
    }
    return widget.hijriDate?.monthName.toUpperCase() ?? 'HIJRI CALENDAR';
  }

  String _hijriLine() {
    final h = widget.hijriDate;
    if (h == null) return 'HIJRI DATE';
    return '${h.year} AH • DATE ${h.day}';
  }

  String _dateLine() {
    final d = widget.shownDate;
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  String _weekday() {
    const names = <String>[
      'MONDAY',
      'TUESDAY',
      'WEDNESDAY',
      'THURSDAY',
      'FRIDAY',
      'SATURDAY',
      'SUNDAY',
    ];
    return names[widget.shownDate.weekday - 1];
  }

  Widget _shareCard() {
    final activeZones = widget.selectedZones.isEmpty
        ? <ZoneData>[allZoneDefinitions.first]
        : <ZoneData>[widget.selectedZones.first];

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 720,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F7F6),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
              decoration: const BoxDecoration(
                color: Color(0xFF1455C0),
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Column(
                children: [
                  Text(
                    _hijriMonth(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _hijriLine(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              color: const Color(0xFFD71920),
              child: const Text(
                'PRAYER TIMES',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _dateLine(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF173B9B),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFD9DFE3)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      _shareHeaderCell('SALAH', Colors.black87),
                      for (final z in activeZones)
                        _shareHeaderCell(z.title.replaceAll('ZONE ', 'Z '), z.color),
                    ],
                  ),
                  for (final prayer in prayers)
                    _sharePrayerRow(prayer, activeZones),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _shareHeaderCell(String text, Color color) => Expanded(
        child: Container(
          height: 48,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          color: color,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      );

  Widget _sharePrayerRow(PrayerData prayer, List<ZoneData> activeZones) => SizedBox(
        height: 56,
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: FittedBox(
                  alignment: Alignment.centerLeft,
                  fit: BoxFit.scaleDown,
                  child: Text(
                    prayer.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
            for (final zone in activeZones)
              Expanded(
                child: Container(
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Color(0xFFE2E7EA)),
                      left: BorderSide(color: Color(0xFFE2E7EA)),
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      to12Hour(_times(zone.keyName)[prayer.keyName] ?? '--:--'),
                      style: TextStyle(
                        color: zone.color,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );

  Future<void> _shareAsImage() async {
    if (sharing) return;
    setState(() => sharing = true);

    try {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      final boundary =
          _shareKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;

      if (boundary == null) {
        throw StateError('Share image is not ready.');
      }

      final image = await boundary.toImage(pixelRatio: 2.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();

      if (byteData == null) {
        throw StateError('Could not create PNG image.');
      }

      final bytes = byteData.buffer.asUint8List();
      final d = widget.shownDate;
      final fileName =
          'prayer_times_${d.year}_${d.month.toString().padLeft(2, '0')}_${d.day.toString().padLeft(2, '0')}.png';

      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              bytes,
              name: fileName,
              mimeType: 'image/png',
            ),
          ],
          text: 'Prayer Times • ${_dateLine()}',
          subject: 'Prayer Times',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE9EFED),
      appBar: AppBar(
        title: const Text('Share Prayer Times'),
        actions: [
          IconButton(
            tooltip: 'Share as Image',
            onPressed: sharing ? null : _shareAsImage,
            icon: sharing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share_outlined),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(10),
          child: RepaintBoundary(
            key: _shareKey,
            child: _shareCard(),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton.icon(
          onPressed: sharing ? null : _shareAsImage,
          icon: const Icon(Icons.share),
          label: const Text('SHARE AS IMAGE'),
        ),
      ),
    );
  }
}


class AppSettings {
  AppSettings._();
  static final AppSettings instance = AppSettings._();

  String selectedZone = 'ZONE 01 – WESTERN';
  List<String> selectedZoneKeys = ['zone1', 'zone7', 'zone8'];
  String locationName = 'Sri Lanka';
  String language = 'English';
  String backgroundStyle = 'Light';
  int hijriAdjustment = 0;
  String widgetTheme = 'Dark';

  Color get background {
    switch (backgroundStyle) {
      case 'Black':
        return const Color(0xFF050807);
      case 'Light':
        return const Color(0xFFF4F7F6);
      case 'Masjid Photo':
        return const Color(0xFF10251D);
      case 'Dark Green':
      default:
        return const Color(0xFF081A14);
    }
  }

  bool notifications = true;
  bool prayerNotifications = true;
  bool iqamahNotifications = true;
  bool silentMode = false;
  bool fullScreen = true;
  bool hideStatusBar = true;
  bool hideNavigationBar = true;
  bool keepScreenOn = true;
  final Map<String, String> iqamahTimes = {
    'fajr': '05:00',
    'zuhr': '12:30',
    'asr': '15:30',
    'maghrib': '18:15',
    'isha': '19:30',
  };
  final Map<String, int> prayerAdjustments = {
    'fajr': 0,
    'sunrise': 0,
    'zuhr': 0,
    'asr': 0,
    'maghrib': 0,
    'isha': 0,
  };

  void reset() {
    selectedZone = 'ZONE 01 – WESTERN';
    selectedZoneKeys = ['zone1', 'zone7', 'zone8'];
    locationName = 'Sri Lanka';
    language = 'English';
    backgroundStyle = 'Light';
    hijriAdjustment = 0;
    widgetTheme = 'Dark';
    notifications = true;
    prayerNotifications = true;
    iqamahNotifications = true;
    silentMode = false;
    fullScreen = true;
    hideStatusBar = true;
    hideNavigationBar = true;
    keepScreenOn = true;
    iqamahTimes.clear();
    iqamahTimes.addAll({
      'fajr': '05:00',
      'zuhr': '12:30',
      'asr': '15:30',
      'maghrib': '18:15',
      'isha': '19:30',
    });
    prayerAdjustments.updateAll((key, value) => 0);
  }
}

const allSriLankaZones = <Map<String, String>>[
  {'zone': '01', 'name': 'Colombo', 'areas': 'Colombo, Gampaha & Kalutara District'},
  {'zone': '02', 'name': 'Jaffna', 'areas': 'Jaffna & Nallur'},
  {'zone': '03', 'name': 'Mullaitivu', 'areas': 'Mullaitivu District (Except Nallurs, Kilinochchi, Vavuniya District)'},
  {'zone': '04', 'name': 'Mannar', 'areas': 'Mannar & Puttalam District'},
  {'zone': '05', 'name': 'Anuradhapura', 'areas': 'Anuradhapura & Polonnaruwa District'},
  {'zone': '06', 'name': 'Kurunegala', 'areas': 'Kurunegala District'},
  {'zone': '07', 'name': 'Kandy', 'areas': 'Kandy, Matale & Nuwara Eliya District'},
  {'zone': '08', 'name': 'Batticaloa', 'areas': 'Batticaloa & Ampara District'},
  {'zone': '09', 'name': 'Trincomalee', 'areas': 'Trincomalee District'},
  {'zone': '10', 'name': 'Badulla', 'areas': 'Badulla & Monaragala District, Dehiattakandiya, Embilipitiya'},
  {'zone': '11', 'name': 'Ratnapura', 'areas': 'Ratnapura & Kegalle District'},
  {'zone': '12', 'name': 'Galle', 'areas': 'Galle & Matara District'},
  {'zone': '13', 'name': 'Hambantota', 'areas': 'Hambantota District'},
];

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final items = const [
    (Icons.public, '13 Zones'),
    (Icons.location_on_outlined, 'Location'),
    (Icons.explore_outlined, 'Qibla'),
    (Icons.calendar_month_outlined, 'Hilāl Calendar'),
    (Icons.date_range_outlined, 'Hijri Adjustment'),
    (Icons.access_time, 'Iqamah'),
    (Icons.notifications_none, 'Notifications'),
    (Icons.volume_off_outlined, 'Silent Mode'),
    (Icons.palette_outlined, 'Background'),
    (Icons.language, 'Language'),
    (Icons.widgets_outlined, 'Widget Settings'),
    (Icons.tune, 'Prayer Adjustment'),
    (Icons.info_outline, 'About'),
    (Icons.download_outlined, 'Update'),
    (Icons.restart_alt, 'Reset'),
  ];

  void _open(String title) {
    final pages = <String, Widget>{
      '13 Zones': const ZonesScreen(),
      'Location': const LocationScreen(),
      'Qibla': const QiblaScreen(),
      'Hilāl Calendar': const HijriCalendarInfoScreen(),
      'Hijri Adjustment': const HijriAdjustmentScreen(),
      'Iqamah': const IqamahScreen(),
      'Notifications': const NotificationsScreen(),
      'Silent Mode': const SilentModeScreen(),
      'Background': const BackgroundScreen(),
      'Language': const LanguageScreen(),
      'Widget Settings': const WidgetSettingsScreen(),
      'Prayer Adjustment': const PrayerAdjustmentScreen(),
      'About': const AboutScreen(),
      'Update': const UpdateScreen(),
      'Reset': const ResetScreen(),
    };

    final page = pages[title];
    if (page == null) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => page)).then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8F4),
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: const Color(0xFFF4F8F4),
      ),
      body: ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, _) => const Divider(height: 1, thickness: .8),
        itemBuilder: (context, index) {
          final item = items[index];
          return ListTile(
            minTileHeight: 74,
            leading: Icon(item.$1, size: 30, color: const Color(0xFF46514B)),
            title: Text(item.$2, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            trailing: const Icon(Icons.chevron_right, size: 30),
            onTap: () => _open(item.$2),
          );
        },
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  final String title;
  final Widget child;
  const SettingsPage({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900))),
        body: child,
      );
}

class ZonesScreen extends StatefulWidget {
  const ZonesScreen({super.key});
  @override
  State<ZonesScreen> createState() => _ZonesScreenState();
}

class _ZonesScreenState extends State<ZonesScreen> {
  bool _hasData(String key) => allZoneDefinitions.any((z) => z.keyName == key);

  void _toggleZone(ZoneData zone) {
    final selected = AppSettings.instance.selectedZoneKeys;
    setState(() {
      if (selected.contains(zone.keyName)) {
        if (selected.length <= 1) return;
        selected.remove(zone.keyName);
      } else {
        selected
          ..clear()
          ..add(zone.keyName);
      }
      AppSettings.instance.selectedZone = zone.title;
    });
  }

  @override
  Widget build(BuildContext context) => SettingsPage(
        title: '13 Zones',
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              color: const Color(0xFFE8F5E9),
              child: const Text(
                'Select 1 zone for the main Prayer Times interface.\nPrayer data is loaded dynamically by zone and month from the GitHub source.',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: allZoneDefinitions.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final zone = allZoneDefinitions[i];
                  final selected = AppSettings.instance.selectedZoneKeys.contains(zone.keyName);
                  final hasData = _hasData(zone.keyName);
                  return ListTile(
                    leading: Checkbox(
                      value: selected,
                      onChanged: (_) => _toggleZone(zone),
                    ),
                    title: Text(zone.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text('${zone.subtitle}\n${hasData ? 'Dynamic monthly data available' : 'Monthly data not available'}'),
                    isThreeLine: true,
                    trailing: IconButton(
                      tooltip: 'Annual timetable',
                      icon: const Icon(Icons.calendar_month_outlined),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => AnnualZonePrayerScreen(zone: zone)),
                      ),
                    ),
                    onTap: () => _toggleZone(zone),
                  );
                },
              ),
            ),
          ],
        ),
      );
}

class AnnualZonePrayerScreen extends StatefulWidget {
  final ZoneData zone;
  const AnnualZonePrayerScreen({super.key, required this.zone});
  @override
  State<AnnualZonePrayerScreen> createState() => _AnnualZonePrayerScreenState();
}

class _AnnualZonePrayerScreenState extends State<AnnualZonePrayerScreen> {
  Map<String, dynamic>? data;
  int year = 2026;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final zoneNumber = int.parse(widget.zone.keyName.replaceFirst('zone', ''));
    final zoneData = <String, dynamic>{};

    for (int month = 1; month <= 12; month++) {
      final file = ZoneMonthFile(zone: zoneNumber, month: month);
      var days = await prayerTimeRepository.readMonth(zone: zoneNumber, month: month);
      if (days == null) {
        await prayerTimeRepository.downloadOne(file);
        days = await prayerTimeRepository.readMonth(zone: zoneNumber, month: month);
      }
      for (final day in days ?? <PrayerDay>[]) {
        zoneData[day.date.substring(5)] = day.toJson();
      }
    }

    if (mounted) setState(() => data = {widget.zone.keyName: zoneData});
  }

  String _dateKey(DateTime d) => '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _12(String value) {
    final p = value.split(':');
    if (p.length != 2) return value;
    final h = int.tryParse(p[0]) ?? 0;
    final m = int.tryParse(p[1]) ?? 0;
    return '${h % 12 == 0 ? 12 : h % 12}:${m.toString().padLeft(2, '0')} ${h >= 12 ? 'PM' : 'AM'}';
  }

  Map<String, String> _times(DateTime d) {
    final zone = data?[widget.zone.keyName];
    if (zone is! Map) return {};
    final day = zone[_dateKey(d)];
    if (day is! Map) return {};
    return day.map<String, String>((k, v) => MapEntry(k.toString(), v.toString()));
  }

  @override
  Widget build(BuildContext context) {
    final rows = <DateTime>[];
    final days = DateTime(year + 1, 1, 1).difference(DateTime(year, 1, 1)).inDays;
    for (int i = 0; i < days; i++) rows.add(DateTime(year, 1, 1).add(Duration(days: i)));
    return SettingsPage(
      title: widget.zone.title,
      child: data == null
          ? const Center(child: CircularProgressIndicator())
          : (data![widget.zone.keyName] as Map).isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      '2026 annual prayer-time data for ${widget.zone.title} has not been added to prayer_times_2026.json yet.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: rows.length + 1,
                  itemBuilder: (_, index) {
                    if (index == 0) {
                      return Container(
                        color: widget.zone.color,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        child: const Row(
                          children: [
                            Expanded(child: Text('DATE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
                            Expanded(child: Text('FAJR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
                            Expanded(child: Text('ZUHR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
                            Expanded(child: Text('ASR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
                            Expanded(child: Text('MAGHRIB', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
                            Expanded(child: Text('ISHA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
                          ],
                        ),
                      );
                    }
                    final d = rows[index - 1];
                    final t = _times(d);
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade300))),
                      child: Row(
                        children: [
                          Expanded(child: Text('${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}', style: const TextStyle(fontWeight: FontWeight.w700))),
                          for (final key in ['fajr', 'zuhr', 'asr', 'maghrib', 'isha'])
                            Expanded(child: Text(t[key] == null ? '--:--' : _12(t[key]!), style: const TextStyle(fontWeight: FontWeight.w700))),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});
  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  late final TextEditingController controller;
  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: AppSettings.instance.locationName);
  }
  @override
  void dispose() { controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => SettingsPage(
    title: 'Location',
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const ListTile(leading: Icon(Icons.location_on), title: Text('Prayer time location', style: TextStyle(fontWeight: FontWeight.w900)), subtitle: Text('Select the area used for prayer-time calculations and display.')),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Location name', border: OutlineInputBorder(), prefixIcon: Icon(Icons.place)),
          onChanged: (v) => AppSettings.instance.locationName = v,
        ),
        const SizedBox(height: 12),
        Card(child: ListTile(
          leading: const Icon(Icons.public),
          title: Text(AppSettings.instance.selectedZone),
          subtitle: const Text('Selected prayer-time zone'),
        )),
        const SizedBox(height: 12),
        const Text('Location is used to identify the prayer-time zone and Qibla coordinates entered in this app.', style: TextStyle(color: Colors.grey)),
      ],
    ),
  );
}

class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});
  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  double bearing = 0;
  final lat = TextEditingController(text: '6.9271');
  final lon = TextEditingController(text: '79.8612');

  double _qibla(double latitude, double longitude) {
    const kaabaLat = 21.4225;
    const kaabaLon = 39.8262;
    double rad(double x) => x * 3.141592653589793 / 180;
    double deg(double x) => x * 180 / 3.141592653589793;
    final phi1 = rad(latitude), phi2 = rad(kaabaLat);
    final dl = rad(kaabaLon - longitude);
    final y = sin(dl);
    final x = cos(phi1) * tan(phi2) - sin(phi1) * cos(dl);
    return (deg(atan2(y, x)) + 360) % 360;
  }

  @override
  Widget build(BuildContext context) => SettingsPage(
    title: 'Qibla',
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Icon(Icons.explore, size: 100, color: Color(0xFF087F5B)),
        const SizedBox(height: 10),
        Center(child: Text('${bearing.toStringAsFixed(1)}°', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900))),
        const Center(child: Text('Qibla bearing from selected coordinates')),
        const SizedBox(height: 20),
        TextField(controller: lat, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Latitude', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(controller: lon, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Longitude', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: () {
            final a = double.tryParse(lat.text), b = double.tryParse(lon.text);
            if (a == null || b == null) return;
            setState(() => bearing = _qibla(a, b));
          },
          icon: const Icon(Icons.navigation),
          label: const Text('Calculate Qibla'),
        ),
        const SizedBox(height: 8),
        const Text('This calculates the initial great-circle bearing to the Kaaba from the coordinates entered above. A live compass sensor can be added separately.'),
      ],
    ),
  );
}


class HijriAdjustmentScreen extends StatefulWidget {
  const HijriAdjustmentScreen({super.key});

  @override
  State<HijriAdjustmentScreen> createState() => _HijriAdjustmentScreenState();
}

class _HijriAdjustmentScreenState extends State<HijriAdjustmentScreen> {
  @override
  Widget build(BuildContext context) {
    final current = AppSettings.instance.hijriAdjustment;
    return SettingsPage(
      title: 'Hijri Date Adjustment',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Hijri Date Adjustment',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Adjust the displayed Hijri date by -2 to +2 days. The adjustment is applied to the Home screen and Share Image.',
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    current > 0 ? '+$current Day' : '$current Day',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        iconSize: 36,
                        onPressed: current > -2
                            ? () => setState(() => AppSettings.instance.hijriAdjustment--)
                            : null,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      SizedBox(
                        width: 70,
                        child: Center(
                          child: Text(
                            '$current',
                            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                      IconButton(
                        iconSize: 36,
                        onPressed: current < 2
                            ? () => setState(() => AppSettings.instance.hijriAdjustment++)
                            : null,
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    children: [-2, -1, 0, 1, 2].map((value) {
                      return ChoiceChip(
                        label: Text(value > 0 ? '+$value' : '$value'),
                        selected: current == value,
                        onSelected: (_) => setState(() => AppSettings.instance.hijriAdjustment = value),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('SAVE'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class IqamahScreen extends StatefulWidget {
  const IqamahScreen({super.key});
  @override
  State<IqamahScreen> createState() => _IqamahScreenState();
}

class _IqamahScreenState extends State<IqamahScreen> {
  final names = const {'fajr':'Fajr','zuhr':'Zuhr','asr':'Asr','maghrib':'Maghrib','isha':'Isha'};
  late final Map<String, TextEditingController> c;
  @override
  void initState() {
    super.initState();
    c = {for (final e in names.entries) e.key: TextEditingController(text: AppSettings.instance.iqamahTimes[e.key])};
  }
  @override
  void dispose() { for (final x in c.values) x.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => SettingsPage(
    title: 'Iqamah',
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Set the daily Iqamah time for each Salah.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        for (final e in names.entries) Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextField(
            controller: c[e.key],
            keyboardType: TextInputType.datetime,
            decoration: InputDecoration(labelText: e.value, hintText: 'HH:MM', border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.access_time)),
            onChanged: (v) => AppSettings.instance.iqamahTimes[e.key] = v,
          ),
        ),
        FilledButton.icon(
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Iqamah times saved for this session.'))),
          icon: const Icon(Icons.save),
          label: const Text('Save Iqamah Times'),
        ),
      ],
    ),
  );
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}
class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  Widget build(BuildContext context) => SettingsPage(
    title: 'Notifications',
    child: ListView(
      children: [
        SwitchListTile(title: const Text('Notifications'), subtitle: const Text('Enable app notifications'), value: AppSettings.instance.notifications, onChanged: (v) => setState(() => AppSettings.instance.notifications = v)),
        SwitchListTile(title: const Text('Prayer alerts'), subtitle: const Text('Alert before prayer time'), value: AppSettings.instance.prayerNotifications, onChanged: (v) => setState(() => AppSettings.instance.prayerNotifications = v)),
        SwitchListTile(title: const Text('Iqamah alerts'), subtitle: const Text('Alert for Iqamah time'), value: AppSettings.instance.iqamahNotifications, onChanged: (v) => setState(() => AppSettings.instance.iqamahNotifications = v)),
        const ListTile(leading: Icon(Icons.info_outline), title: Text('Notification timing'), subtitle: Text('Actual Android scheduled notifications require notification scheduling permission/plugin setup.')),
      ],
    ),
  );
}

class SilentModeScreen extends StatefulWidget {
  const SilentModeScreen({super.key});
  @override
  State<SilentModeScreen> createState() => _SilentModeScreenState();
}
class _SilentModeScreenState extends State<SilentModeScreen> {
  @override
  Widget build(BuildContext context) => SettingsPage(
    title: 'Silent Mode',
    child: ListView(
      children: [
        SwitchListTile(title: const Text('Silent Mode'), subtitle: const Text('Mute app alert sounds'), value: AppSettings.instance.silentMode, onChanged: (v) => setState(() => AppSettings.instance.silentMode = v)),
        const ListTile(leading: Icon(Icons.volume_off), title: Text('Important'), subtitle: Text('This setting controls this app; it does not change the phone-wide Android silent mode.')),
      ],
    ),
  );
}

class BackgroundScreen extends StatefulWidget {
  const BackgroundScreen({super.key});
  @override
  State<BackgroundScreen> createState() => _BackgroundScreenState();
}
class _BackgroundScreenState extends State<BackgroundScreen> {
  final styles = const ['Dark Green', 'Light', 'Black', 'Blue', 'Masjid Photo'];
  @override
  Widget build(BuildContext context) => SettingsPage(
    title: 'Background',
    child: ListView.builder(
      itemCount: styles.length,
      itemBuilder: (_, i) {
        final x = styles[i];
        return RadioListTile<String>(
          value: x,
          groupValue: AppSettings.instance.backgroundStyle,
          title: Text(x, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(x == 'Masjid Photo' ? 'Use a mosque-style background preview.' : 'Use $x style'),
          onChanged: (v) => setState(() => AppSettings.instance.backgroundStyle = v!),
        );
      },
    ),
  );
}

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});
  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}
class _LanguageScreenState extends State<LanguageScreen> {
  final langs = const ['English', 'தமிழ்', 'සිංහල', 'العربية'];
  @override
  Widget build(BuildContext context) => SettingsPage(
    title: 'Language',
    child: ListView(
      children: langs.map((x) => RadioListTile<String>(
        value: x,
        groupValue: AppSettings.instance.language,
        title: Text(x, style: const TextStyle(fontWeight: FontWeight.w800)),
        onChanged: (v) => setState(() => AppSettings.instance.language = v!),
      )).toList(),
    ),
  );
}

class WidgetSettingsScreen extends StatefulWidget {
  const WidgetSettingsScreen({super.key});
  @override
  State<WidgetSettingsScreen> createState() => _WidgetSettingsScreenState();
}

class _WidgetSettingsScreenState extends State<WidgetSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final s = AppSettings.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Widget Settings')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 6),
            child: Text('Full Prayer Widget', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('The full-screen prayer display shows prayer times, date, zones and widget display controls. Android Home Screen widget integration requires the Android widget configuration in addition to this Flutter screen.'),
          ),
          ListTile(
            title: const Text('Widget Theme'),
            subtitle: Text(s.widgetTheme),
            trailing: DropdownButton<String>(
              value: s.widgetTheme,
              items: const [
                DropdownMenuItem(value: 'Dark', child: Text('Dark')),
                DropdownMenuItem(value: 'Light', child: Text('Light')),
              ],
              onChanged: (v) => setState(() => s.widgetTheme = v ?? 'Dark'),
            ),
          ),
          SwitchListTile(title: const Text('Full Screen'), value: s.fullScreen, onChanged: (v) { setState(() => s.fullScreen = v); _apply(); }),
          SwitchListTile(title: const Text('Hide Status Bar'), value: s.hideStatusBar, onChanged: (v) { setState(() => s.hideStatusBar = v); _apply(); }),
          SwitchListTile(title: const Text('Hide Navigation Bar'), value: s.hideNavigationBar, onChanged: (v) { setState(() => s.hideNavigationBar = v); _apply(); }),
          SwitchListTile(title: const Text('Keep Screen On'), subtitle: const Text('Keep this display preference active while using the full prayer display.'), value: s.keepScreenOn, onChanged: (v) => setState(() => s.keepScreenOn = v)),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.fullscreen),
            title: const Text('Open Full Prayer Widget'),
            subtitle: const Text('Show complete prayer timetable'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              _apply();
              Navigator.push(context, MaterialPageRoute(builder: (_) => const WidgetPrayerDisplay()));
            },
          ),
        ],
      ),
    );
  }

  void _apply() {
    final s = AppSettings.instance;
    if (!s.fullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      return;
    }
    final overlays = <SystemUiOverlay>[];
    if (!s.hideStatusBar) overlays.add(SystemUiOverlay.top);
    if (!s.hideNavigationBar) overlays.add(SystemUiOverlay.bottom);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: overlays);
  }
}

class PrayerAdjustmentScreen extends StatefulWidget {
  const PrayerAdjustmentScreen({super.key});
  @override
  State<PrayerAdjustmentScreen> createState() => _PrayerAdjustmentScreenState();
}
class _PrayerAdjustmentScreenState extends State<PrayerAdjustmentScreen> {
  final labels = const {'fajr':'Fajr','sunrise':'Sunrise','zuhr':'Zuhr','asr':'Asr','maghrib':'Maghrib','isha':'Isha'};
  @override
  Widget build(BuildContext context) => SettingsPage(
    title: 'Prayer Adjustment',
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Adjust displayed prayer times by minutes.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        for (final e in labels.entries)
          Card(
            child: ListTile(
              title: Text(e.value, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('${AppSettings.instance.prayerAdjustments[e.key]} minutes'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(onPressed: () => setState(() => AppSettings.instance.prayerAdjustments[e.key] = (AppSettings.instance.prayerAdjustments[e.key] ?? 0) - 1), icon: const Icon(Icons.remove_circle_outline)),
                  IconButton(onPressed: () => setState(() => AppSettings.instance.prayerAdjustments[e.key] = (AppSettings.instance.prayerAdjustments[e.key] ?? 0) + 1), icon: const Icon(Icons.add_circle_outline)),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});
  @override
  Widget build(BuildContext context) => SettingsPage(
    title: 'About',
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        Icon(Icons.mosque, size: 90, color: Color(0xFF087F5B)),
        SizedBox(height: 12),
        Center(child: Text('Prayer Times', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900))),
        SizedBox(height: 6),
        Center(child: Text('Masjid Prayer Time Application')),
        SizedBox(height: 24),
        ListTile(leading: Icon(Icons.info_outline), title: Text('Version'), subtitle: Text('1.0.0')),
        ListTile(leading: Icon(Icons.calendar_today), title: Text('Prayer data'), subtitle: Text('2026 daily prayer-time dataset')),
        ListTile(leading: Icon(Icons.public), title: Text('Coverage'), subtitle: Text('13 Sri Lankan zones are listed in Settings; current timetable data includes the configured Western, Central and Eastern zones.')),
        ListTile(leading: Icon(Icons.code), title: Text('Platform'), subtitle: Text('Flutter / Android')),
      ],
    ),
  );
}

class UpdateScreen extends StatefulWidget {
  const UpdateScreen({super.key});
  @override
  State<UpdateScreen> createState() => _UpdateScreenState();
}
class _UpdateScreenState extends State<UpdateScreen> {
  bool checking = false;
  String result = 'No update check has been run.';
  @override
  Widget build(BuildContext context) => SettingsPage(
    title: 'Update',
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const ListTile(leading: Icon(Icons.system_update), title: Text('App Update', style: TextStyle(fontWeight: FontWeight.w900)), subtitle: Text('Check the current installed app build and update status.')),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: checking ? null : () async {
            setState(() { checking = true; result = 'Checking...'; });
            await Future.delayed(const Duration(seconds: 1));
            if (!mounted) return;
            setState(() { checking = false; result = 'You are using the current local build (1.0.0).'; });
          },
          icon: const Icon(Icons.refresh),
          label: Text(checking ? 'Checking...' : 'Check for Update'),
        ),
        const SizedBox(height: 12),
        Text(result, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 20),
        const Text('A live Play Store / server update system can be connected once the app has an online release endpoint.', style: TextStyle(color: Colors.grey)),
      ],
    ),
  );
}

class ResetScreen extends StatelessWidget {
  const ResetScreen({super.key});
  @override
  Widget build(BuildContext context) => SettingsPage(
    title: 'Reset',
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, size: 70, color: Colors.orange),
          const SizedBox(height: 12),
          const Text('Reset all app settings', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('This resets zone, location, language, background, notifications, Iqamah and prayer adjustments for this app session.'),
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final yes = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Reset settings?'),
                  content: const Text('All current settings will be restored to their defaults.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Reset')),
                  ],
                ),
              );
              if (yes == true) {
                AppSettings.instance.reset();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings reset.')));
                }
              }
            },
            icon: const Icon(Icons.restart_alt),
            label: const Text('Reset All Settings'),
          ),
        ],
      ),
    ),
  );
}

class WidgetPrayerDisplay extends StatefulWidget {
  const WidgetPrayerDisplay({super.key});

  @override
  State<WidgetPrayerDisplay> createState() => _WidgetPrayerDisplayState();
}

class _WidgetPrayerDisplayState extends State<WidgetPrayerDisplay> {
  Map<String, dynamic>? data;
  Timer? timer;
  DateTime now = DateTime.now();
  bool tomorrow = false;
  HijriDateInfo? hijriDate;

  @override
  void initState() {
    super.initState();
    _loadData();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final next = DateTime.now();
      if (next.year != now.year ||
          next.month != now.month ||
          next.day != now.day ||
          next.hour != now.hour) {
        _loadData();
        _loadHijriDate();
      }
      setState(() => now = next);
    });
    _enterFullScreen();
    _loadHijriDate();
  }

  Future<void> _loadHijriDate() async {
    final result = await HijriCalendarService.getForGregorian(shownDate);
    if (!mounted) return;
    setState(() {
      hijriDate = result == null
          ? null
          : result.copyWith(
              day: (result.day + AppSettings.instance.hijriAdjustment)
                  .clamp(1, 30),
            );
    });
  }

  Future<void> _loadData() async {
    final loaded = await loadPrayerDataForDate(
      date: shownDate,
      zoneList: zones.isEmpty ? <ZoneData>[allZoneDefinitions.first] : zones,
    );
    if (mounted) setState(() => data = loaded);
  }

  @override
  void dispose() {
    timer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _enterFullScreen() {
    final settings = AppSettings.instance;
    if (!settings.fullScreen) return;

    final overlays = <SystemUiOverlay>[];
    if (!settings.hideStatusBar) overlays.add(SystemUiOverlay.top);
    if (!settings.hideNavigationBar) overlays.add(SystemUiOverlay.bottom);

    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: overlays,
    );
  }

  DateTime get shownDate {
    final today = DateTime(now.year, now.month, now.day);
    return (tomorrow || now.hour >= 20)
        ? today.add(const Duration(days: 1))
        : today;
  }

  Map<String, String> _times(String zoneKey) {
    final zone = data?[zoneKey];
    if (zone is! Map) return <String, String>{};
    final day = zone[dateKey(shownDate)];
    if (day is! Map) return <String, String>{};
    return day.map<String, String>(
      (key, value) => MapEntry(
        key.toString(),
        applyPrayerAdjustment(value.toString(), key.toString()),
      ),
    );
  }

  String _nextPrayer() {
    final selectedZones = zones;
    final zoneKey = selectedZones.isEmpty ? 'zone1' : selectedZones.first.keyName;
    final times = _times(zoneKey);
    final current = now.hour * 60 + now.minute;

    if (shownDate.year == now.year &&
        shownDate.month == now.month &&
        shownDate.day == now.day) {
      for (final prayer in prayers) {
        final raw = times[prayer.keyName];
        if (raw != null && minutesOf(raw) > current) {
          return '${prayer.name} • ${to12Hour(raw)}';
        }
      }
    }

    return 'Tomorrow • Fajr';
  }

  String _nextIqamah() {
    final current = now.hour * 60 + now.minute;
    const order = <String>['fajr', 'zuhr', 'asr', 'maghrib', 'isha'];
    const labels = <String, String>{
      'fajr': 'Fajr',
      'zuhr': 'Zuhr',
      'asr': 'Asr',
      'maghrib': 'Maghrib',
      'isha': 'Isha',
    };

    for (final key in order) {
      final raw = AppSettings.instance.iqamahTimes[key];
      if (raw != null && minutesOf(raw) > current) {
        return '${labels[key]} • ${to12Hour(raw)}';
      }
    }
    return 'Tomorrow • Fajr';
  }

  Widget _infoBox(String title, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: const Color(0xFF10251D),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF29453A)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cell(String text, Color color) {
    return Expanded(
      child: Container(
        height: 40,
        alignment: Alignment.center,
        color: color,
        padding: const EdgeInsets.all(3),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }

  Widget _timeCell(String raw, Color color) {
    return Expanded(
      child: Container(
        height: 42,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Color(0xFF29453A)),
            left: BorderSide(color: Color(0xFF29453A)),
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            raw == '--:--' ? raw : to12Hour(raw),
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedZones = zones;
    final safeZones = selectedZones.isEmpty
        ? <ZoneData>[allZoneDefinitions.first]
        : selectedZones;

    final lightWidget = AppSettings.instance.widgetTheme == 'Light';
    final widgetBg = lightWidget ? const Color(0xFFF4F7F6) : const Color(0xFF081A14);
    final widgetCard = lightWidget ? Colors.white : const Color(0xFF10201A);
    final widgetText = lightWidget ? Colors.black87 : Colors.white;

    return Scaffold(
      backgroundColor: widgetBg,
      body: SafeArea(
        top: !AppSettings.instance.hideStatusBar,
        bottom: !AppSettings.instance.hideNavigationBar,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'PRAYER TIMES',
                      style: TextStyle(
                        color: widgetText,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    clock12(now),
                    style: const TextStyle(
                      color: Color(0xFFFFD600),
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: widgetText),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${shownDate.day.toString().padLeft(2, '0')}.${shownDate.month.toString().padLeft(2, '0')}.${shownDate.year}',
                          style: TextStyle(
                            color: AppSettings.instance.widgetTheme == 'Light' ? Colors.black87 : Colors.white70,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (hijriDate != null)
                          Text(
                            '${hijriDate!.day} ${hijriDate!.monthName} ${hijriDate!.year} AH',
                            style: TextStyle(
                              color: AppSettings.instance.widgetTheme == 'Light' ? Colors.black54 : Colors.white60,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() => tomorrow = !tomorrow);
                      _loadData();
                      _loadHijriDate();
                    },
                    child: Text(
                      tomorrow ? 'TODAY' : 'TOMORROW',
                      style: const TextStyle(
                        color: Color(0xFFFFD600),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  _infoBox('NEXT PRAYER', _nextPrayer()),
                  const SizedBox(width: 8),
                  _infoBox('NEXT IQAMAH', _nextIqamah()),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: widgetCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF29453A)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _cell('SALAH', const Color(0xFF26342E)),
                          for (final zone in safeZones)
                            _cell(
                              zone.title.replaceFirst('ZONE ', 'Z '),
                              zone.color,
                            ),
                        ],
                      ),
                      for (final prayer in prayers)
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 42,
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.symmetric(horizontal: 5),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    prayer.name,
                                    style: TextStyle(
                                      color: widgetText,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            for (final zone in safeZones)
                              _timeCell(
                                hasPrayerData(zone.keyName)
                                    ? (_times(zone.keyName)[prayer.keyName] ?? '--:--')
                                    : '--:--',
                                zone.color,
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'اللهم أعنا على ذكرك وشكرك وحسن عبادتك',
                style: TextStyle(
                  color: Color(0xFFFFD600),
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
