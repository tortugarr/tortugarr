import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonfin/data/services/row_data_source.dart';
import 'package:server_core/server_core.dart';

class _MockClient extends Mock implements MediaServerClient {}

class _MockLiveTvApi extends Mock implements LiveTvApi {}

/// Dropping the flag fails quietly, since the row still fills up and only the
/// programs in it are wrong.
void main() {
  test('On Now asks for programs that are airing', () async {
    final liveTv = _MockLiveTvApi();
    when(
      () => liveTv.getRecommendedPrograms(
        limit: any(named: 'limit'),
        isAiring: any(named: 'isAiring'),
      ),
    ).thenAnswer((_) async => {'Items': <dynamic>[], 'TotalRecordCount': 0});

    final client = _MockClient();
    when(() => client.liveTvApi).thenReturn(liveTv);

    await RowDataSource(client).loadOnNow('srv1');

    final captured = verify(
      () => liveTv.getRecommendedPrograms(
        limit: any(named: 'limit'),
        isAiring: captureAny(named: 'isAiring'),
      ),
    ).captured.single;
    expect(captured, isTrue);
  });
}
