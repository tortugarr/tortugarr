import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/application/providers/download_provider.dart';
import 'package:moonfin/domain/models/download_management.dart';
import 'package:moonfin/presentation/features/downloads/widgets/download_progress_card.dart';

import '../download_test_app.dart';

void main() {
  group('DownloadStatusScreen', () {
    testWidgets('shows a spinner while downloads are loading', (tester) async {
      final gate = Completer<List<Download>>();

      await pumpDownloadApp(
        tester,
        overrides: [
          allDownloadsProvider.overrideWith((ref) => gate.future.asStream()),
        ],
        settle: false,
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      gate.complete(const <Download>[]);
      await tester.pumpAndSettle();
    });

    testWidgets('shows an error message when the stream fails', (tester) async {
      final gate = Completer<List<Download>>();

      await pumpDownloadApp(
        tester,
        overrides: [
          allDownloadsProvider.overrideWith((ref) {
            return gate.future.asStream().handleError((err) {
              throw err;
            });
          }),
        ],
        settle: false,
      );

      gate.completeError(StateError('Download service unreachable'));
      await tester.pumpAndSettle();

      expect(find.text('Error: Bad state: Download service unreachable'),
          findsOneWidget);
    });

    testWidgets('shows "No active downloads" when list is empty', (tester) async {
      await pumpDownloadApp(
        tester,
        overrides: [
          allDownloadsProvider.overrideWith(
            (ref) => Stream.value(const <Download>[]),
          ),
        ],
      );

      expect(find.text('No active downloads'), findsOneWidget);
    });

    testWidgets('renders one DownloadProgressCard per download', (tester) async {
      final download1 = Download(
        hash: 'abc123',
        name: 'Dune.Part.Two.2024.2160p.WEB-DL',
        progress: 0.753,
        state: DownloadState.downloading,
        startedAt: DateTime.now(),
      );

      final download2 = Download(
        hash: 'def456',
        name: 'Severance.S01E01.1080p.WEB-DL',
        progress: 0.25,
        state: DownloadState.downloading,
        startedAt: DateTime.now(),
      );

      await pumpDownloadApp(
        tester,
        overrides: [
          allDownloadsProvider.overrideWith(
            (ref) => Stream.value([download1, download2]),
          ),
        ],
      );

      expect(find.byType(DownloadProgressCard), findsNWidgets(2));
      expect(find.text('Dune.Part.Two.2024.2160p.WEB-DL'), findsOneWidget);
      expect(find.text('Severance.S01E01.1080p.WEB-DL'), findsOneWidget);
    });

    testWidgets('updates when stream emits new values', (tester) async {
      final controller = StreamController<List<Download>>();

      final download1 = Download(
        hash: 'abc123',
        name: 'Dune.Part.Two.2024.2160p.WEB-DL',
        progress: 0.5,
        state: DownloadState.downloading,
        startedAt: DateTime.now(),
      );

      final download1Updated = Download(
        hash: 'abc123',
        name: 'Dune.Part.Two.2024.2160p.WEB-DL',
        progress: 0.75,
        state: DownloadState.downloading,
        startedAt: DateTime.now(),
      );

      await pumpDownloadApp(
        tester,
        overrides: [
          allDownloadsProvider.overrideWith((ref) => controller.stream),
        ],
        settle: false,
      );

      // Emit first value
      controller.add([download1]);
      await tester.pumpAndSettle();

      expect(find.text('50%'), findsOneWidget);

      // Emit updated value
      controller.add([download1Updated]);
      await tester.pumpAndSettle();

      expect(find.text('75%'), findsOneWidget);

      await controller.close();
    });

    testWidgets('Stop button on each card calls stopDownloadProvider',
        (tester) async {
      var stopCalled = false;
      var stoppedHash = '';

      final download = Download(
        hash: 'abc123',
        name: 'Dune.Part.Two.2024.2160p.WEB-DL',
        progress: 0.5,
        state: DownloadState.downloading,
        startedAt: DateTime.now(),
      );

      await pumpDownloadApp(
        tester,
        overrides: [
          allDownloadsProvider.overrideWith(
            (ref) => Stream.value([download]),
          ),
          stopDownloadProvider.overrideWith((ref, hash) async {
            stopCalled = true;
            stoppedHash = hash;
          }),
        ],
      );

      await tester.tap(find.byIcon(Icons.stop));
      await tester.pumpAndSettle();

      expect(stopCalled, isTrue);
      expect(stoppedHash, 'abc123');
    });

    testWidgets('displays downloads in the order provided by stream',
        (tester) async {
      final download1 = Download(
        hash: 'abc123',
        name: 'A - First Download',
        progress: 0.5,
        state: DownloadState.downloading,
        startedAt: DateTime.now(),
      );

      final download2 = Download(
        hash: 'def456',
        name: 'B - Second Download',
        progress: 0.25,
        state: DownloadState.downloading,
        startedAt: DateTime.now(),
      );

      await pumpDownloadApp(
        tester,
        overrides: [
          allDownloadsProvider.overrideWith(
            (ref) => Stream.value([download1, download2]),
          ),
        ],
      );

      // Find all text widgets to verify order
      final downloads = find.byType(DownloadProgressCard);
      expect(downloads, findsNWidgets(2));

      // Get the text from each card to verify order
      expect(find.text('A - First Download'), findsOneWidget);
      expect(find.text('B - Second Download'), findsOneWidget);
    });

    testWidgets('AppBar shows "Downloads" title', (tester) async {
      await pumpDownloadApp(
        tester,
        overrides: [
          allDownloadsProvider.overrideWith(
            (ref) => Stream.value(const <Download>[]),
          ),
        ],
      );

      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Downloads'), findsWidgets);
    });
  });
}
