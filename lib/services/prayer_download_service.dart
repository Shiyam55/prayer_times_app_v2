import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/prayer_month_file.dart';
import '../models/zone_month_file.dart';

class DownloadResult {
  final bool success;
  final String? rawJson;
  final String? errorMessage;

  DownloadResult.ok(this.rawJson)
      : success = true,
        errorMessage = null;

  DownloadResult.fail(this.errorMessage)
      : success = false,
        rawJson = null;
}

/// Downloads one Zone/Month JSON file from GitHub.
///
/// URLs are generated dynamically from the selected
/// zone and month. No individual file URLs are hard-coded.
class PrayerDownloadService {
  static const String baseUrl =
      'https://raw.githubusercontent.com/msfrox/Prayer-Time-Site/main/data/';

  final http.Client _client;
  final Duration timeout;

  PrayerDownloadService({
    http.Client? client,
    this.timeout = const Duration(seconds: 20),
  }) : _client = client ?? http.Client();

  Future<DownloadResult> fetchFile(
    ZoneMonthFile file,
  ) async {
    final url = file.remoteUrl(baseUrl);

    try {
      final response = await _client
          .get(Uri.parse(url))
          .timeout(timeout);

      if (response.statusCode == 404) {
        return DownloadResult.fail(
          'Prayer Time Server Unavailable',
        );
      }

      if (response.statusCode != 200) {
        return DownloadResult.fail(
          'Download Failed — Retry',
        );
      }

      final body = response.body;

      if (!_isValid(body)) {
        return DownloadResult.fail(
          'Invalid Prayer Time Data',
        );
      }

      return DownloadResult.ok(body);
    } catch (_) {
      return DownloadResult.fail(
        'Download Failed — Retry',
      );
    }
  }

  bool _isValid(String body) {
    try {
      final decoded = jsonDecode(body);

      return PrayerMonthFile.tryParse(decoded) != null;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    _client.close();
  }
}