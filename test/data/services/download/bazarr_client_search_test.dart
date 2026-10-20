import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/services/download/bazarr_client.dart';

/// Answers Bazarr calls: PATCH queues a search, GET /api/movies returns the
/// next state from [states] (the last one repeats).
class _FakeBazarr implements HttpClientAdapter {
  final List<List<String>> states;
  int gets = 0;
  final patched = <String>[];

  _FakeBazarr(this.states);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'PATCH') {
      patched.add('${options.queryParameters['language']}');
      return ResponseBody.fromString('', 204);
    }
    final missing = states[gets < states.length ? gets : states.length - 1];
    gets++;
    final body = {
      'data': [
        {
          'subtitles': [
            for (final c in ['no', 'en'])
              if (!missing.contains(c)) {'code2': c, 'forced': false},
          ],
          'missing_subtitles': [
            for (final c in missing) {'code2': c, 'forced': false},
          ],
        }
      ]
    };
    return ResponseBody.fromString(jsonEncode(body), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

BazarrSubtitleService _service(_FakeBazarr fake) {
  final dio = Dio(BaseOptions(validateStatus: (_) => true))..httpClientAdapter = fake;
  return BazarrSubtitleService(dio: dio);
}

void main() {
  const target = BazarrTarget.movie(7);

  test('waits for the queued search instead of reading the state at once', () async {
    final fake = _FakeBazarr([
      ['no', 'en'],
      ['no', 'en'],
      ['no'],
      [],
    ]);
    final after = await _service(fake).searchMissing(target, ['no', 'en'],
        pollEvery: Duration.zero);
    expect(fake.patched, ['no', 'en']);
    expect(after.missing, isEmpty);
    expect(after.have, {'no', 'en'});
  });

  test('stops when one language is found and the rest settles', () async {
    final fake = _FakeBazarr([
      ['no', 'en'],
      ['no'],
    ]);
    final after = await _service(fake).searchMissing(target, ['no', 'en'],
        pollEvery: Duration.zero);
    expect(after.missing, {'no'});
    expect(after.have, {'en'});
    // found on the 2nd read, then 3 unchanged polls
    expect(fake.gets, 5);
  });

  test('gives up after the timeout when nothing turns up', () async {
    final fake = _FakeBazarr([
      ['no', 'en'],
    ]);
    final after = await _service(fake).searchMissing(target, ['no', 'en'],
        timeout: const Duration(milliseconds: 50),
        pollEvery: const Duration(milliseconds: 10));
    expect(after.missing, {'no', 'en'});
  });
}
