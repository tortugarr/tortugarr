/// The download progress screen shown after submitting a media request.
///
/// Monitors active downloads via [allDownloadsProvider], shows real-time
/// progress with ETA, and allows canceling individual downloads.
///
/// Two providers are watched purely for their side effects, because both are
/// `autoDispose` and so only run while this screen is on stage:
///
/// * [downloadDiscoveryProvider] polls the download client and adopts torrents
///   the pipeline created after the user submitted a request — without it the
///   list stays empty, since the info hash does not exist at submit time.
/// * [downloadWithRefreshProvider] asks Jellyfin to rescan its library once a
///   tracked download reaches 100%.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../application/providers/download_provider.dart';
import '../widgets/download_progress_card.dart';

class DownloadStatusScreen extends ConsumerWidget {
  const DownloadStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadsAsync = ref.watch(allDownloadsProvider);

    // Subscribed for their side effects only; see the library comment.
    // `listen` rather than `watch` on purpose: a listener keeps an autoDispose
    // provider alive just as a watch does, but does not rebuild this screen
    // every time the five-second poll ticks or a completion is recorded. The
    // list itself already rebuilds off [allDownloadsProvider], which is what
    // both of these ultimately feed.
    //
    // A discovery failure is deliberately not rendered — the poll retries, and
    // a fault that matters surfaces through [allDownloadsProvider] instead.
    ref.listen<AsyncValue<List<String>>>(downloadDiscoveryProvider, (_, _) {});
    ref.listen<Set<String>>(downloadWithRefreshProvider, (_, _) {});

    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloads'),
      ),
      body: downloadsAsync.when(
        // Adopting a newly discovered torrent changes the tracked hash list,
        // which tears [allDownloadsProvider] down and rebuilds it. Without
        // this the whole list would blink back to a spinner every time the
        // five-second poll found something — so keep the last snapshot on
        // screen and let it be replaced when the merged stream reports again.
        // A genuine first load still shows the spinner.
        skipLoadingOnReload: true,
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (err, stack) => Center(
          child: Text('Error: $err'),
        ),
        data: (downloads) {
          if (downloads.isEmpty) {
            return const Center(
              child: Text('No active downloads'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: downloads.length,
            itemBuilder: (context, index) {
              final download = downloads[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: DownloadProgressCard(
                  download: download,
                  onStop: () => _onStopDownload(context, ref, download.hash),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _onStopDownload(BuildContext context, WidgetRef ref, String hash) async {
    ref.read(stopDownloadProvider(hash));
  }
}
