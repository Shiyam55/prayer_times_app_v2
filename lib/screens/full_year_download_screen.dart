import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/download_progress_provider.dart';

class FullYearDownloadScreen extends StatefulWidget {
  const FullYearDownloadScreen({super.key});

  @override
  State<FullYearDownloadScreen> createState() =>
      _FullYearDownloadScreenState();
}

class _FullYearDownloadScreenState
    extends State<FullYearDownloadScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context
          .read<DownloadProgressProvider>()
          .refreshStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Full Year Download'),
      ),
      body: Consumer<DownloadProgressProvider>(
        builder: (context, provider, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Download Full Year Data',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 16),

                Text(
                  'Total Files: ${provider.total}',
                ),

                const SizedBox(height: 4),

                Text(
                  'Downloaded: '
                  '${provider.completed}/${provider.total}',
                ),

                if (provider.failed > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Failed: ${provider.failed}',
                    style: const TextStyle(
                      color: Colors.red,
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                LinearProgressIndicator(
                  value: provider.progress,
                ),

                const SizedBox(height: 6),

                Text(
                  '${(provider.progress * 100).toStringAsFixed(0)}%',
                  textAlign: TextAlign.center,
                ),

                if (provider.currentFile != null) ...[
                  const SizedBox(height: 20),

                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        'Downloading:\n'
                        '${provider.currentFile}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],

                if (provider.error != null) ...[
                  const SizedBox(height: 12),

                  Text(
                    provider.error!,
                    style: const TextStyle(
                      color: Colors.red,
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                if (provider.isDownloading)
                  Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 12),
                      const Text(
                        'Downloading prayer time data...',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: provider.stopDownload,
                        child: const Text('Stop'),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      ElevatedButton(
                        onPressed: provider.startDownload,
                        child: Text(
                          provider.completed > 0 &&
                                  provider.completed <
                                      provider.total
                              ? 'Resume Download'
                              : 'Start Download',
                        ),
                      ),

                      if (provider.failed > 0) ...[
                        const SizedBox(height: 10),
                        OutlinedButton(
                          onPressed:
                              provider.retryFailed,
                          child: const Text(
                            'Retry Failed Files',
                          ),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}