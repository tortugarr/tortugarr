/// A reusable card widget that displays a single download's progress.
///
/// Shows the download name, progress percentage, ETA, current state (Downloading,
/// Seeding, Completed, Stopped), and a cancel button. The card is TV-friendly
/// with large, easily-readable text and buttons.
library;

import 'package:flutter/material.dart';

import '../../../../domain/models/download_management.dart';

class DownloadProgressCard extends StatelessWidget {
  final Download download;
  final VoidCallback onStop;

  const DownloadProgressCard({
    super.key,
    required this.download,
    required this.onStop,
  });

  /// Converts ETA into a human-readable format.
  ///
  /// - If download doesn't have a valid ETA yet: "Calculating..."
  /// - < 60s: "< 1m"
  /// - >= 60s: "15m", "2h 30m", etc.
  static String _formatEta(Download download) {
    if (!download.hasEta) return 'Calculating...';

    final etaSeconds = download.etaSeconds;
    if (etaSeconds < 60) return '< 1m';

    final hours = etaSeconds ~/ 3600;
    final minutes = (etaSeconds % 3600) ~/ 60;

    if (hours == 0) {
      return '${minutes}m';
    } else if (minutes == 0) {
      return '${hours}h';
    } else {
      return '${hours}h ${minutes}m';
    }
  }

  /// Returns a color based on download state.
  Color _stateColor(DownloadState state) {
    return switch (state) {
      DownloadState.downloading => Colors.blue,
      DownloadState.allocating => Colors.blue,
      DownloadState.seeding => Colors.orange,
      DownloadState.paused => Colors.grey,
      DownloadState.completed => Colors.green,
      DownloadState.stopped => Colors.grey,
    };
  }

  /// Returns a label based on download state.
  String _stateLabel(DownloadState state) {
    return switch (state) {
      DownloadState.downloading => 'Downloading',
      DownloadState.allocating => 'Allocating',
      DownloadState.seeding => 'Seeding (will stop at 100%)',
      DownloadState.paused => 'Paused',
      DownloadState.completed => 'Completed',
      DownloadState.stopped => 'Stopped',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progressPercent = download.progressPercent;
    final eta = _formatEta(download);
    final stateLabel = _stateLabel(download.state);
    final stateColor = _stateColor(download.state);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              download.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),

            // Progress row: percentage on left, ETA on right
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$progressPercent%',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  eta,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Progress bar
            LinearProgressIndicator(
              value: download.progress.clamp(0.0, 1.0),
              minHeight: 8,
            ),
            const SizedBox(height: 12),

            // State badge and cancel button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // State badge
                Chip(
                  label: Text(stateLabel),
                  backgroundColor: stateColor.withAlpha(51), // 0.2 * 255 ≈ 51
                  labelStyle: theme.textTheme.labelMedium?.copyWith(
                    color: stateColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                // Cancel button (disabled when completed)
                ElevatedButton.icon(
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: download.state == DownloadState.completed
                      ? null
                      : onStop,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
