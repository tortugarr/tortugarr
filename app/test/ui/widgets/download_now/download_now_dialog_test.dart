import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/services/seerr/seerr_api_models.dart';
import 'package:moonfin/l10n/app_localizations.dart';
import 'package:moonfin/ui/widgets/download_now/download_now_dialog.dart';

/// Regression test for the "Download Now" episode-selection cascade.
///
/// Bug: `_SeasonEpisodeGrid.totalEpisodes` was bound to the *selected* set's
/// length instead of the season's fixed episode count. Deselecting E02 shrank
/// the rendered tile count from 10 to 9, so E10 vanished from the screen even
/// though it was still in the selection — and it then downloaded anyway.
/// This test pins both halves of the fix:
///  1. every episode tile (E01..E10) stays visible after a deselect, and
///  2. the emitted [DownloadNowChoice] keeps E10 and drops only E02.
void main() {
  testWidgets(
    'deselecting E02 keeps all 10 tiles visible and emits only E02 removed',
    (tester) async {
      DownloadNowChoice? emitted;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    emitted = await showDownloadNowDialog(
                      context,
                      isTv: true,
                      title: 'Test Show',
                      seasons: const [
                        SeerrSeason(seasonNumber: 1, episodeCount: 10),
                      ],
                      numberOfSeasons: 1,
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // The dialog opens with "All seasons" on. Turn it off so the per-season
      // episode grid renders.
      await tester.tap(find.text('All Seasons'));
      await tester.pumpAndSettle();

      // Select season 1 — that expands its episode grid.
      await tester.tap(find.textContaining('S01'));
      await tester.pumpAndSettle();

      // Sanity: all 10 episode tiles render before any deselect.
      for (var i = 1; i <= 10; i++) {
        expect(
          find.text('E${i.toString().padLeft(2, '0')}'),
          findsOneWidget,
          reason: 'E$i should be visible before deselecting',
        );
      }

      // Deselect E02.
      await tester.tap(find.text('E02'));
      await tester.pumpAndSettle();

      // (1) Regression: every tile E01..E10 must STILL be visible. Before the
      // fix, E10 disappeared because totalEpisodes shrank to 9.
      for (var i = 1; i <= 10; i++) {
        expect(
          find.text('E${i.toString().padLeft(2, '0')}'),
          findsOneWidget,
          reason: 'E$i must still be visible after deselecting E02',
        );
      }

      // The season count line should read "9/10", not "9/9".
      expect(find.textContaining('9/10'), findsOneWidget);

      // (2) Regression: submitting must emit {1,3..10} — E02 removed, E10
      // retained. Before the fix the hidden-but-selected E10 still downloaded.
      await tester.tap(find.text('Download'));
      await tester.pumpAndSettle();

      expect(emitted, isNotNull, reason: 'Download should pop with a choice');
      expect(emitted!.seasons, [1]);
      expect(emitted!.episodes[1], [1, 3, 4, 5, 6, 7, 8, 9, 10]);
    },
  );
}
