import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/domain/models/download_management.dart';
import 'package:moonfin/presentation/features/downloads/widgets/download_progress_card.dart';

void main() {
  group('DownloadProgressCard', () {
    testWidgets('displays download name and progress percentage',
        (WidgetTester tester) async {
      final download = Download(
        hash: 'abc123',
        name: 'Dune.Part.Two.2024.2160p.WEB-DL',
        progress: 0.753,
        state: DownloadState.downloading,
        startedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DownloadProgressCard(
              download: download,
              onStop: () {},
            ),
          ),
        ),
      );

      expect(find.text('Dune.Part.Two.2024.2160p.WEB-DL'), findsOneWidget);
      expect(find.text('75%'), findsOneWidget);
    });

    group('ETA formatting', () {
      testWidgets('formats < 60 seconds as "< 1m"', (WidgetTester tester) async {
        final download = Download(
          hash: 'abc123',
          name: 'Test Download',
          progress: 0.5,
          state: DownloadState.downloading,
          startedAt: DateTime.now(),
          eta: const Duration(seconds: 30),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DownloadProgressCard(
                download: download,
                onStop: () {},
              ),
            ),
          ),
        );

        expect(find.text('< 1m'), findsOneWidget);
      });

      testWidgets('formats 59 seconds as "< 1m"', (WidgetTester tester) async {
        final download = Download(
          hash: 'abc123',
          name: 'Test Download',
          progress: 0.5,
          state: DownloadState.downloading,
          startedAt: DateTime.now(),
          eta: const Duration(seconds: 59),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DownloadProgressCard(
                download: download,
                onStop: () {},
              ),
            ),
          ),
        );

        expect(find.text('< 1m'), findsOneWidget);
      });

      testWidgets('formats 60 seconds as "1m"', (WidgetTester tester) async {
        final download = Download(
          hash: 'abc123',
          name: 'Test Download',
          progress: 0.5,
          state: DownloadState.downloading,
          startedAt: DateTime.now(),
          eta: const Duration(seconds: 60),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DownloadProgressCard(
                download: download,
                onStop: () {},
              ),
            ),
          ),
        );

        expect(find.text('1m'), findsOneWidget);
      });

      testWidgets('formats 3661 seconds as "1h 1m"', (WidgetTester tester) async {
        final download = Download(
          hash: 'abc123',
          name: 'Test Download',
          progress: 0.5,
          state: DownloadState.downloading,
          startedAt: DateTime.now(),
          eta: const Duration(seconds: 3661),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DownloadProgressCard(
                download: download,
                onStop: () {},
              ),
            ),
          ),
        );

        expect(find.text('1h 1m'), findsOneWidget);
      });

      testWidgets('formats 0 ETA (unknown) as "Calculating..."',
          (WidgetTester tester) async {
        // The Download model converts negative ETA to 0, so we test with 0 duration
        // which represents an unknown/calculating ETA
        final download = Download(
          hash: 'abc123',
          name: 'Test Download',
          progress: 0.5,
          state: DownloadState.downloading,
          startedAt: DateTime.now(),
          eta: const Duration(seconds: 0),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DownloadProgressCard(
                download: download,
                onStop: () {},
              ),
            ),
          ),
        );

        // When eta is 0 and download is not complete, show "Calculating..."
        expect(find.text('Calculating...'), findsOneWidget);
      });
    });

    group('State display', () {
      testWidgets('shows "Downloading" badge for downloading state',
          (WidgetTester tester) async {
        final download = Download(
          hash: 'abc123',
          name: 'Test Download',
          progress: 0.5,
          state: DownloadState.downloading,
          startedAt: DateTime.now(),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DownloadProgressCard(
                download: download,
                onStop: () {},
              ),
            ),
          ),
        );

        expect(find.text('Downloading'), findsOneWidget);
      });

      testWidgets('shows "Seeding (will stop at 100%)" badge for seeding state',
          (WidgetTester tester) async {
        final download = Download(
          hash: 'abc123',
          name: 'Test Download',
          progress: 1.0,
          state: DownloadState.seeding,
          startedAt: DateTime.now(),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DownloadProgressCard(
                download: download,
                onStop: () {},
              ),
            ),
          ),
        );

        expect(find.text('Seeding (will stop at 100%)'), findsOneWidget);
      });

      testWidgets('shows "Completed" badge for completed state',
          (WidgetTester tester) async {
        final download = Download(
          hash: 'abc123',
          name: 'Test Download',
          progress: 1.0,
          state: DownloadState.completed,
          startedAt: DateTime.now(),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DownloadProgressCard(
                download: download,
                onStop: () {},
              ),
            ),
          ),
        );

        expect(find.text('Completed'), findsOneWidget);
      });

      testWidgets('shows "Stopped" badge for stopped state',
          (WidgetTester tester) async {
        final download = Download(
          hash: 'abc123',
          name: 'Test Download',
          progress: 0.5,
          state: DownloadState.stopped,
          startedAt: DateTime.now(),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DownloadProgressCard(
                download: download,
                onStop: () {},
              ),
            ),
          ),
        );

        expect(find.text('Stopped'), findsOneWidget);
      });
    });

    testWidgets('Stop button calls onStop callback', (WidgetTester tester) async {
      var stopCalled = false;
      final download = Download(
        hash: 'abc123',
        name: 'Test Download',
        progress: 0.5,
        state: DownloadState.downloading,
        startedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DownloadProgressCard(
              download: download,
              onStop: () {
                stopCalled = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.stop));
      expect(stopCalled, isTrue);
    });

    testWidgets('Stop button is disabled when download is completed',
        (WidgetTester tester) async {
      var stopCalled = false;
      final download = Download(
        hash: 'abc123',
        name: 'Test Download',
        progress: 1.0,
        state: DownloadState.completed,
        startedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DownloadProgressCard(
              download: download,
              onStop: () {
                stopCalled = true;
              },
            ),
          ),
        ),
      );

      // Verify the button is disabled
      final button = find.byType(ElevatedButton);
      expect(button, findsOneWidget);
      final buttonWidget = tester.widget<ElevatedButton>(button);
      expect(buttonWidget.onPressed, isNull);
      expect(stopCalled, isFalse);
    });

    testWidgets('renders LinearProgressIndicator with correct value',
        (WidgetTester tester) async {
      final download = Download(
        hash: 'abc123',
        name: 'Test Download',
        progress: 0.753,
        state: DownloadState.downloading,
        startedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DownloadProgressCard(
              download: download,
              onStop: () {},
            ),
          ),
        ),
      );

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      final progressIndicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(progressIndicator.value, closeTo(0.753, 0.001));
    });

    testWidgets('download name truncates with ellipsis when too long',
        (WidgetTester tester) async {
      final download = Download(
        hash: 'abc123',
        name:
            'A.Very.Long.Movie.Title.That.Goes.On.And.On.2024.2160p.WEB-DL.x264.AAC.5.1',
        progress: 0.5,
        state: DownloadState.downloading,
        startedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DownloadProgressCard(
              download: download,
              onStop: () {},
            ),
          ),
        ),
      );

      // The text should be present but may be truncated
      expect(
        find.text(
            'A.Very.Long.Movie.Title.That.Goes.On.And.On.2024.2160p.WEB-DL.x264.AAC.5.1'),
        findsOneWidget,
      );
    });
  });
}
