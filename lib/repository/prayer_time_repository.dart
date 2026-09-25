import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/prayer_day.dart';
import '../models/prayer_month_file.dart';
import '../models/zone_month_file.dart';
import '../services/prayer_download_service.dart';

class PrayerTimeRepository {
  static const String _failedFilesKey = 'prayer_failed_files';
  static const String _lastUpdatedKey = 'prayer_last_updated';
  static const String _fileHashPrefix = 'prayer_hash_';

  final PrayerDownloadService downloadService;

  PrayerTimeRepository({
    PrayerDownloadService? downloadService,
  }) : downloadService =
            downloadService ?? PrayerDownloadService();

  Future<Directory> _rootDir() async {
    final appDir = await getApplicationDocumentsDirectory();

    final root = Directory(
      '${appDir.path}/prayer_times',
    );

    if (!await root.exists()) {
      await root.create(recursive: true);
    }

    return root;
  }

  Future<File> _localFile(ZoneMonthFile file) async {
    final root = await _rootDir();

    final zoneDir = Directory(
      '${root.path}/zone${file.zoneCode}',
    );

    if (!await zoneDir.exists()) {
      await zoneDir.create(recursive: true);
    }

    return File(
      '${zoneDir.path}/${file.monthCode}.json',
    );
  }

  Future<bool> isDownloaded(
    ZoneMonthFile file,
  ) async {
    final localFile = await _localFile(file);

    if (!await localFile.exists()) {
      return false;
    }

    try {
      final content = await localFile.readAsString();
      final decoded = jsonDecode(content);

      return PrayerMonthFile.tryParse(decoded) != null;
    } catch (_) {
      return false;
    }
  }

  Future<void> _saveLocal(
    ZoneMonthFile file,
    String rawJson,
  ) async {
    final localFile = await _localFile(file);

    await localFile.writeAsString(
      rawJson,
      flush: true,
    );

    final prefs =
        await SharedPreferences.getInstance();

    final hash = sha256
        .convert(utf8.encode(rawJson))
        .toString();

    await prefs.setString(
      '$_fileHashPrefix${file.key}',
      hash,
    );
  }

  Future<bool> downloadOne(
    ZoneMonthFile file, {
    bool forceRedownload = false,
  }) async {
    if (!forceRedownload &&
        await isDownloaded(file)) {
      return true;
    }

    final result =
        await downloadService.fetchFile(file);

    if (!result.success ||
        result.rawJson == null) {
      await _markFailed(file);
      return false;
    }

    await _saveLocal(
      file,
      result.rawJson!,
    );

    await _unmarkFailed(file);

    return true;
  }

  Future<bool> updateOneIfChanged(
    ZoneMonthFile file,
  ) async {
    final result =
        await downloadService.fetchFile(file);

    if (!result.success ||
        result.rawJson == null) {
      await _markFailed(file);
      return false;
    }

    final newHash = sha256
        .convert(
          utf8.encode(result.rawJson!),
        )
        .toString();

    final prefs =
        await SharedPreferences.getInstance();

    final oldHash = prefs.getString(
      '$_fileHashPrefix${file.key}',
    );

    if (oldHash == newHash &&
        await isDownloaded(file)) {
      return true;
    }

    await _saveLocal(
      file,
      result.rawJson!,
    );

    await _unmarkFailed(file);

    return true;
  }

  Future<void> _markFailed(
    ZoneMonthFile file,
  ) async {
    final prefs =
        await SharedPreferences.getInstance();

    final failed = prefs
            .getStringList(_failedFilesKey)
            ?.toSet() ??
        <String>{};

    failed.add(file.key);

    await prefs.setStringList(
      _failedFilesKey,
      failed.toList(),
    );
  }

  Future<void> _unmarkFailed(
    ZoneMonthFile file,
  ) async {
    final prefs =
        await SharedPreferences.getInstance();

    final failed = prefs
            .getStringList(_failedFilesKey)
            ?.toSet() ??
        <String>{};

    if (failed.remove(file.key)) {
      await prefs.setStringList(
        _failedFilesKey,
        failed.toList(),
      );
    }
  }

  Future<List<ZoneMonthFile>> getFailedFiles() async {
    final prefs =
        await SharedPreferences.getInstance();

    final failed =
        prefs.getStringList(_failedFilesKey) ?? [];

    return failed.map((key) {
      final parts = key.split('-');

      return ZoneMonthFile(
        zone: int.parse(parts[0]),
        month: int.parse(parts[1]),
      );
    }).toList();
  }

  Future<void> setLastUpdatedNow() async {
    final prefs =
        await SharedPreferences.getInstance();

    await prefs.setString(
      _lastUpdatedKey,
      DateTime.now().toIso8601String(),
    );
  }

  Future<DateTime?> getLastUpdated() async {
    final prefs =
        await SharedPreferences.getInstance();

    final value =
        prefs.getString(_lastUpdatedKey);

    if (value == null) {
      return null;
    }

    return DateTime.tryParse(value);
  }

  Future<int> countDownloaded() async {
    int count = 0;

    for (final file in ZoneMonthFile.all()) {
      if (await isDownloaded(file)) {
        count++;
      }
    }

    return count;
  }

  Future<void> clearAll() async {
    final root = await _rootDir();

    if (await root.exists()) {
      await root.delete(
        recursive: true,
      );
    }

    final prefs =
        await SharedPreferences.getInstance();

    final keys = prefs.getKeys().where(
      (key) =>
          key.startsWith(_fileHashPrefix) ||
          key == _failedFilesKey ||
          key == _lastUpdatedKey,
    );

    for (final key in keys.toList()) {
      await prefs.remove(key);
    }
  }

  Future<List<PrayerDay>?> readMonth({
    required int zone,
    required int month,
  }) async {
    final file = ZoneMonthFile(
      zone: zone,
      month: month,
    );

    final localFile =
        await _localFile(file);

    if (!await localFile.exists()) {
      return null;
    }

    try {
      final content =
          await localFile.readAsString();

      return PrayerMonthFile.tryParse(
        jsonDecode(content),
      );
    } catch (_) {
      return null;
    }
  }

  Future<PrayerDay?> readToday({
    required int zone,
    required int month,
    required String effectiveDateString,
  }) async {
    final days = await readMonth(
      zone: zone,
      month: month,
    );

    if (days == null) {
      return null;
    }

    for (final day in days) {
      if (day.date == effectiveDateString) {
        return day;
      }
    }

    return null;
  }
}