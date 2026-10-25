import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/preference/preference_constants.dart';
import 'package:moonfin/preference/seerr_row_config.dart';

void main() {
  group('SeerrRowConfig streaming rows', () {
    SeerrRowConfig find(List<SeerrRowConfig> rows, SeerrRowType type) =>
        rows.firstWhere((r) => r.type == type);

    test('defaults list Networks and Studios, switched off', () {
      final rows = SeerrRowConfig.defaults();
      expect(find(rows, SeerrRowType.networks).enabled, isFalse);
      expect(find(rows, SeerrRowType.studios).enabled, isFalse);
    });

    test('a saved config without them gets them appended, off, at the end', () {
      final saved = SeerrRowConfig.toJsonString(const [
        SeerrRowConfig(type: SeerrRowType.trending, order: 0),
        SeerrRowConfig(type: SeerrRowType.popularMovies, order: 1),
      ]);
      final rows = SeerrRowConfig.fromJsonString(saved);
      final networks = find(rows, SeerrRowType.networks);
      expect(networks.enabled, isFalse);
      expect(networks.order, greaterThan(1));
      expect(find(rows, SeerrRowType.trending).enabled, isTrue);
    });

    test('a user who turned Networks on keeps it on', () {
      final saved = SeerrRowConfig.toJsonString(const [
        SeerrRowConfig(type: SeerrRowType.networks, enabled: true, order: 0),
      ]);
      final rows = SeerrRowConfig.fromJsonString(saved);
      expect(find(rows, SeerrRowType.networks).enabled, isTrue);
    });
  });
}
