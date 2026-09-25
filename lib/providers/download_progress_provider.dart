import 'package:flutter/foundation.dart';

import '../models/zone_month_file.dart';
import '../repository/prayer_time_repository.dart';

enum FileDownloadStatus {
  pending,
  downloading,
  downloaded,
  failed,
}

class FileDownloadState {
  final ZoneMonthFile file;
  final FileDownloadStatus status;

  const FileDownloadState({
    required this.file,
    required this.status,
  });

  FileDownloadState copyWith({
    FileDownloadStatus? status,
  }) {
    return FileDownloadState(
      file: file,
      status: status ?? this.status,
    );
  }
}

class DownloadProgressProvider extends ChangeNotifier {
  final PrayerTimeRepository repository;

  DownloadProgressProvider({
    required this.repository,
  }) {
    _initialize();
  }

  final List<FileDownloadState> _files = [];

  bool _isDownloading = false;
  int _completed = 0;
  int _failed = 0;
  String? _currentFile;
  String? _error;

  List<FileDownloadState> get files =>
      List.unmodifiable(_files);

  bool get isDownloading => _isDownloading;

  int get completed => _completed;

  int get failed => _failed;

  int get total => _files.length;

  double get progress {
    if (total == 0) {
      return 0;
    }

    return _completed / total;
  }

  String? get currentFile => _currentFile;

  String? get error => _error;

  Future<void> _initialize() async {
    final allFiles = ZoneMonthFile.all();

    _files
      ..clear()
      ..addAll(
        allFiles.map(
          (file) => FileDownloadState(
            file: file,
            status: FileDownloadStatus.pending,
          ),
        ),
      );

    for (int i = 0; i < _files.length; i++) {
      final file = _files[i].file;

      if (await repository.isDownloaded(file)) {
        _files[i] = _files[i].copyWith(
          status: FileDownloadStatus.downloaded,
        );
      }
    }

    _recalculateCounts();
    notifyListeners();
  }

  Future<void> refreshStatus() async {
    _completed = 0;
    _failed = 0;

    for (int i = 0; i < _files.length; i++) {
      final file = _files[i].file;

      if (await repository.isDownloaded(file)) {
        _files[i] = _files[i].copyWith(
          status: FileDownloadStatus.downloaded,
        );
      } else {
        _files[i] = _files[i].copyWith(
          status: FileDownloadStatus.pending,
        );
      }
    }

    _recalculateCounts();
    notifyListeners();
  }

  Future<void> startDownload() async {
    if (_isDownloading) {
      return;
    }

    _isDownloading = true;
    _error = null;

    notifyListeners();

    try {
      for (int i = 0; i < _files.length; i++) {
        if (!_isDownloading) {
          break;
        }

        final state = _files[i];

        if (state.status ==
            FileDownloadStatus.downloaded) {
          continue;
        }

        final file = state.file;

        _currentFile =
            'Zone ${file.zoneCode} • Month ${file.monthCode}';

        _files[i] = state.copyWith(
          status: FileDownloadStatus.downloading,
        );

        notifyListeners();

        final success =
            await repository.downloadOne(file);

        if (success) {
          _files[i] = _files[i].copyWith(
            status: FileDownloadStatus.downloaded,
          );
        } else {
          _files[i] = _files[i].copyWith(
            status: FileDownloadStatus.failed,
          );
        }

        _recalculateCounts();
        notifyListeners();
      }

      if (_failed == 0 && _completed == total) {
        await repository.setLastUpdatedNow();
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isDownloading = false;
      _currentFile = null;
      notifyListeners();
    }
  }

  Future<void> retryFailed() async {
    if (_isDownloading) {
      return;
    }

    final failedFiles = _files
        .where(
          (state) =>
              state.status ==
              FileDownloadStatus.failed,
        )
        .map((state) => state.file)
        .toList();

    if (failedFiles.isEmpty) {
      return;
    }

    _isDownloading = true;
    _error = null;

    notifyListeners();

    try {
      for (final file in failedFiles) {
        if (!_isDownloading) {
          break;
        }

        final index = _files.indexWhere(
          (state) => state.file.key == file.key,
        );

        if (index == -1) {
          continue;
        }

        _currentFile =
            'Zone ${file.zoneCode} • Month ${file.monthCode}';

        _files[index] =
            _files[index].copyWith(
          status: FileDownloadStatus.downloading,
        );

        notifyListeners();

        final success =
            await repository.downloadOne(file);

        _files[index] =
            _files[index].copyWith(
          status: success
              ? FileDownloadStatus.downloaded
              : FileDownloadStatus.failed,
        );

        _recalculateCounts();
        notifyListeners();
      }

      if (_failed == 0 && _completed == total) {
        await repository.setLastUpdatedNow();
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isDownloading = false;
      _currentFile = null;
      notifyListeners();
    }
  }

  void stopDownload() {
    _isDownloading = false;
    notifyListeners();
  }

  void _recalculateCounts() {
    _completed = _files
        .where(
          (state) =>
              state.status ==
              FileDownloadStatus.downloaded,
        )
        .length;

    _failed = _files
        .where(
          (state) =>
              state.status ==
              FileDownloadStatus.failed,
        )
        .length;
  }
}