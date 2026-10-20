import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/services/seerr/seerr_api_models.dart';
import 'package:moonfin/data/services/seerr/seerr_language_filter.dart';
import 'package:moonfin/preference/seerr_preferences.dart';
import 'package:moonfin/preference/user_preferences.dart';
import 'package:moonfin/util/subtitle_track_logic.dart';

SeerrDiscoverItem _item(int id, String? lang, {int? status}) =>
    SeerrDiscoverItem.fromJson({
      'id': id,
      'mediaType': 'movie',
      'title': 't$id',
      'originalLanguage': lang,
      if (status != null) 'mediaInfo': {'status': status},
    });

void main() {
  group('discovery languages', () {
    test('default picks map to the old TMDB set', () {
      expect(tmdbCodesFor(defaultDiscoveryLanguageCodes),
          SeerrLanguageFilter.allowedLanguages);
    });

    test('new languages map to their TMDB codes', () {
      expect(tmdbCodesFor({'spa', 'pol', 'dut'}), {'es', 'pl', 'nl'});
      expect(tmdbCodesFor({'nor'}), {'no', 'nb', 'nn'});
    });

    test('prefs missing falls back to the default picks', () {
      expect(discoveryLanguagesSetting(), defaultDiscoveryLanguageCodes);
      expect(SeerrLanguageFilter.currentAllowed,
          SeerrLanguageFilter.allowedLanguages);
    });

    test('a custom set keeps only its languages', () {
      final allowed = tmdbCodesFor({'spa'});
      expect(SeerrLanguageFilter.keeps(_item(1, 'es'), allowed: allowed), isTrue);
      expect(SeerrLanguageFilter.keeps(_item(1, 'en'), allowed: allowed), isFalse);
      expect(SeerrLanguageFilter.keeps(_item(1, 'ja', status: 5), allowed: allowed),
          isTrue);
    });
  });

  group('language badges', () {
    test('badges only: kept titles get a green badge, foreign ones a grey one', () {
      final en = SeerrLanguageFilter.previewMark(_item(1, 'en'),
          active: false, badges: true);
      expect(en, const SeerrLanguageMark('EN', SeerrLanguageMarkKind.kept));
      expect(SeerrLanguageFilter.previewMark(_item(1, 'ja'),
          active: false, badges: true),
          const SeerrLanguageMark('JA', SeerrLanguageMarkKind.foreign));
    });

    test('badges only: foreign library titles get the grey badge', () {
      expect(
        SeerrLanguageFilter.previewMark(_item(1, 'ja', status: 5),
            active: false, badges: true),
        const SeerrLanguageMark('JA', SeerrLanguageMarkKind.libraryForeign),
      );
    });

    test('preview still marks hidden titles red', () {
      expect(
        SeerrLanguageFilter.previewMark(_item(1, 'ja'), active: true),
        const SeerrLanguageMark('JA', SeerrLanguageMarkKind.hidden),
      );
    });

    test('new language codes have a badge label', () {
      expect(SeerrLanguageFilter.previewMark(_item(1, 'es'),
              active: false, badges: true, allowed: {'es'})!.code, 'ES');
    });

    test('neither on: no badge', () {
      expect(SeerrLanguageFilter.previewMark(_item(1, 'en'), active: false),
          isNull);
    });

    test('badges setting is off when prefs are missing', () {
      expect(showLanguageBadgesSetting(), isFalse);
    });
  });

  test('app language defaults to the system language', () {
    expect(UserPreferences.languageOverride.defaultValue, 'system');
  });
}
