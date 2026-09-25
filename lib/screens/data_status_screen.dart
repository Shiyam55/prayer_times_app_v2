import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../repository/prayer_time_repository.dart';

class DataStatusScreen extends StatefulWidget {
  const DataStatusScreen({super.key});

  @override
  State<DataStatusScreen> createState() =>
      _DataStatusScreenState();
}

class _DataStatusScreenState
    extends State<DataStatusScreen> {
  int _downloaded = 0;
  DateTime? _lastUpdated;
  bool _loading = true;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStatus();
    });
  }

  Future<void> _loadStatus() async {
    final repository =
        context.read<PrayerTimeRepository>();

    final downloaded =
        await repository.countDownloaded();

    final lastUpdated =
        await repository.getLastUpdated();

    if (!mounted) return;

    setState(() {
      _downloaded = downloaded;
      _lastUpdated = lastUpdated;
      _loading = false;
    });
  }

  Future<void> _clearData() async {
    final repository =
        context.read<PrayerTimeRepository>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Clear Prayer Data?'),
          content: const Text(
            'All downloaded prayer time data '
            'will be removed from this device.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await repository.clearAll();
    await _loadStatus();
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) {
      return 'Not updated yet';
    }

    final local = dateTime.toLocal();

    final day =
        local.day.toString().padLeft(2, '0');
    final month =
        local.month.toString().padLeft(2, '0');
    final year = local.year.toString();

    final hour =
        local.hour.toString().padLeft(2, '0');
    final minute =
        local.minute.toString().padLeft(2, '0');

    return '$day/$month/$year $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    const totalFiles = 156;

    final progress =
        _downloaded / totalFiles;

    final complete =
        _downloaded == totalFiles;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Status'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: _loadStatus,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Icon(
                            complete
                                ? Icons.check_circle
                                : Icons.download,
                            size: 54,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            complete
                                ? 'All Data Downloaded'
                                : 'Prayer Data Status',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                            textAlign:
                                TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Card(
                    child: Column(
                      children: [
                        const ListTile(
                          leading: Icon(
                            Icons.public,
                          ),
                          title: Text('Zones'),
                          subtitle: Text(
                            '13 Sri Lanka ACJU Zones',
                          ),
                        ),
                        const Divider(height: 1),
                        const ListTile(
                          leading: Icon(
                            Icons.calendar_month,
                          ),
                          title: Text('Months'),
                          subtitle: Text(
                            '12 months per zone',
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(
                            Icons.folder,
                          ),
                          title: const Text(
                            'Downloaded Files',
                          ),
                          subtitle: Text(
                            '$_downloaded / $totalFiles',
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  LinearProgressIndicator(
                    value: progress,
                  ),

                  const SizedBox(height: 8),

                  Text(
                    '${(progress * 100).toStringAsFixed(0)}%',
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 16),

                  Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.update,
                      ),
                      title: const Text(
                        'Last Updated',
                      ),
                      subtitle: Text(
                        _formatDateTime(
                          _lastUpdated,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        '/download',
                      ).then((_) {
                        _loadStatus();
                      });
                    },
                    icon: const Icon(
                      Icons.download,
                    ),
                    label: Text(
                      _downloaded == 0
                          ? 'Download Data'
                          : 'Update Data',
                    ),
                  ),

                  const SizedBox(height: 10),

                  OutlinedButton.icon(
                    onPressed: _loadStatus,
                    icon: const Icon(
                      Icons.refresh,
                    ),
                    label: const Text(
                      'Refresh Status',
                    ),
                  ),

                  const SizedBox(height: 10),

                  OutlinedButton.icon(
                    onPressed: _clearData,
                    icon: const Icon(
                      Icons.delete_outline,
                    ),
                    label: const Text(
                      'Clear Downloaded Data',
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}