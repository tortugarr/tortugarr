import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/services/download/missing_episodes.dart';
import 'package:moonfin/data/services/download/sonarr_client.dart';
import 'package:moonfin/ui/widgets/missing_episodes/missing_episode_card.dart';
import 'dart:ui' show Locale;
import 'package:intl/date_symbol_data_local.dart';
import 'package:moonfin/util/app_l10n.dart';

/// Answers Sonarr calls from canned data, or fails the way a phone does when
/// it cannot reach the server.
class _FakeSonarr implements HttpClientAdapter {
  final int status;
  final bool unreachable;
  final List<Map<String, dynamic>> series;

  _FakeSonarr({this.status = 200, this.unreachable = false, this.series = const []});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (unreachable) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        message: 'Connection refused',
      );
    }
    final path = options.uri.path;
    final Object body = path.endsWith('/api/v3/series')
        ? series
        : path.endsWith('/api/v3/episode')
            ? [
                {
                  'id': 11,
                  'seasonNumber': 1,
                  'episodeNumber': 1,
                  'monitored': false,
                  'title': 'Pilot',
                  'hasFile': false,
                  'airDateUtc': '2020-01-01T00:00:00Z',
                },
              ]
            : <Object>[];
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

MissingEpisodesService _service(_FakeSonarr fake) =>
    MissingEpisodesService(
      sonarr: SonarrClient(
        dio: Dio(BaseOptions(validateStatus: (_) => true))..httpClientAdapter = fake,
      ),
    );

void main() {
  // These expectations are written in Norwegian Bokmål.
  setUpAll(() async {
    debugAppLocaleOverride = const Locale('nb');
    await initializeDateFormatting('nb');
  });
  tearDownAll(() => debugAppLocaleOverride = null);

  group('missing episodes when Sonarr cannot help', () {
    test('an unreachable Sonarr gives a reason the user can read', () async {
      final service = _service(_FakeSonarr(unreachable: true));
      await expectLater(
        service.loadFor(tvdbId: 77847),
        throwsA(isA<MissingEpisodesException>()
            .having((e) => e.message, 'message', contains('Fikk ikke kontakt med Sonarr'))
            .having((e) => e.message, 'message', contains('Connection refused'))),
      );
    });

    test('an HTTP error from Sonarr names the status', () async {
      final service = _service(_FakeSonarr(status: 401));
      await expectLater(
        service.loadFor(tvdbId: 77847),
        throwsA(isA<MissingEpisodesException>()
            .having((e) => e.message, 'message', contains('HTTP 401'))),
      );
    });

    test('a series without a TVDB id is found by its TMDB id', () async {
      final service = _service(_FakeSonarr(series: [
        {'id': 3, 'tvdbId': 1, 'tmdbId': 1, 'title': 'Other'},
        {'id': 7, 'tvdbId': 404604, 'tmdbId': 201834, 'title': 'ted'},
      ]));
      final status = await service.loadFor(tmdbId: 201834);
      expect(status, isNotNull);
      expect(status!.sonarrSeriesId, 7);
      expect(status.episodes.single.episodeNumber, 1);
    });

    test('no ids at all means not in Sonarr, without asking it', () async {
      final service = _service(_FakeSonarr(unreachable: true));
      expect(await service.loadFor(), isNull);
    });

    test('the message names the address the app used', () {
      expect(unreachableMessage(null), startsWith('Fikk ikke kontakt med Sonarr'));
      expect(unreachableMessage('timeout'), endsWith('(timeout)'));
    });
  });

  for (final width in [1280.0, 360.0]) {
    testWidgets('the status note shows the reason and retries at ${width}px', (tester) async {
      var retries = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: MissingEpisodesStatusNote(
                reason: 'Fikk ikke kontakt med Sonarr på localhost:8989',
                onRetry: () => retries++,
              ),
            ),
          ),
        ),
      ));
      expect(find.text('Manglende episoder kan ikke vises nå'), findsOneWidget);
      expect(find.textContaining('localhost:8989'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Manglende episoder kan ikke vises nå'));
      expect(retries, 1);
    });
  }
}
