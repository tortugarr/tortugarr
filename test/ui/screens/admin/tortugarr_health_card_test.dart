import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/services/tortugarr/tortugarr_plugin_client.dart';
import 'package:moonfin/l10n/app_localizations.dart';
import 'package:moonfin/ui/screens/admin/widgets/tortugarr_health_card.dart';

const _gb = 1 << 30;

Future<void> _pump(WidgetTester tester, Future<TortugarrHealth> Function() load) async {
  tester.view.physicalSize = const Size(1920, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: TortugarrHealthCard(load: load))),
  ));
  await tester.pumpAndSettle();
}

void main() {
  test('the plugin answer is parsed', () {
    final h = TortugarrHealth.fromJson({
      'overall': 'warning',
      'services': [
        {'id': 'radarr', 'name': 'Radarr', 'ok': true, 'version': '6.4.4'},
        {'id': 'bazarr', 'name': 'Bazarr', 'ok': false, 'version': '', 'message': 'no answer within 8 seconds'},
      ],
      'disks': [
        {'drive': 'E:', 'libraries': ['Movies', 'TV Shows'], 'freeBytes': 10 * _gb, 'totalBytes': 1000 * _gb, 'level': 'warning'},
      ],
      'warnings': [
        {'source': 'Prowlarr', 'level': 'info', 'message': 'New update is available'},
      ],
    });
    expect(h.overall, 'warning');
    expect(h.services[1].ok, isFalse);
    expect(h.disks.single.drive, 'E:');
    expect(h.disks.single.usedFraction, closeTo(0.99, 0.001));
    expect(h.warnings.single.level, 'info');
  });

  testWidgets('services, disks and warnings are shown', (tester) async {
    await _pump(
      tester,
      () async => const TortugarrHealth(
        overall: 'error',
        services: [
          TortugarrServiceState(name: 'Radarr', ok: true, version: '6.4.4'),
          TortugarrServiceState(name: 'Bazarr', ok: false, message: 'no answer'),
        ],
        disks: [
          TortugarrDiskState(drive: 'E:', libraries: ['Movies', 'TV Shows'], freeBytes: 10 * _gb, totalBytes: 1000 * _gb, level: 'warning'),
        ],
        warnings: [TortugarrHealthWarning(source: 'Prowlarr', level: 'info', message: 'New update is available')],
      ),
    );
    expect(find.textContaining(RegExp('server health', caseSensitive: false)), findsOneWidget);
    expect(find.text('Something is down'), findsOneWidget);
    expect(find.text('Radarr 6.4.4'), findsOneWidget);
    expect(find.text('Bazarr · not answering'), findsOneWidget);
    expect(find.text('E:'), findsOneWidget);
    expect(find.text('Movies, TV Shows'), findsOneWidget);
    expect(find.text('10.0 GB free of 1000 GB'), findsOneWidget);
    expect(find.text('New update is available'), findsOneWidget);
  });

  testWidgets('no answer from the plugin says so and can try again', (tester) async {
    var calls = 0;
    await _pump(tester, () async {
      calls++;
      throw Exception('down');
    });
    expect(find.text('No answer from the Tortugarr plugin.'), findsOneWidget);
    await tester.tap(find.text('Check again'));
    await tester.pumpAndSettle();
    expect(calls, 2);
  });
}
