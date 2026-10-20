import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/services/seerr/seerr_api_models.dart';
import 'package:moonfin/data/services/seerr/seerr_language_filter.dart';
import 'dart:ui' show Locale;
import 'package:intl/date_symbol_data_local.dart';
import 'package:moonfin/util/app_l10n.dart';

SeerrDiscoverItem _item(int id, String? lang, {int? status}) =>
    SeerrDiscoverItem(
      id: id,
      mediaType: 'movie',
      originalLanguage: lang,
      mediaInfo: status == null ? null : SeerrMediaInfo(id: id, status: status),
    );

/// Upstream with [pages] pages of [perPage] items; items whose id is
/// divisible by [keepEvery] are English, the rest Japanese.
class _FakeUpstream {
  final int pages;
  final int perPage = 20;
  final int keepEvery;
  final List<int> fetched = [];

  _FakeUpstream({this.pages = 50, this.keepEvery = 4});

  Future<SeerrDiscoverPage> call(int page) async {
    fetched.add(page);
    if (page > pages) {
      return SeerrDiscoverPage(totalPages: pages, page: page);
    }
    return SeerrDiscoverPage(
      results: [
        for (var i = 0; i < perPage; i++)
          _item(
            (page - 1) * perPage + i + 1,
            ((page - 1) * perPage + i + 1) % keepEvery == 0 ? 'en' : 'ja',
          ),
      ],
      totalPages: pages,
      totalResults: pages * perPage,
      page: page,
    );
  }
}

Future<List<SeerrDiscoverItem>> _lang(List<SeerrDiscoverItem> items) async =>
    SeerrLanguageFilter.apply(items);

void main() {
  // These expectations are written in Norwegian Bokmål.
  setUpAll(() async {
    debugAppLocaleOverride = const Locale('nb');
    await initializeDateFormatting('nb');
  });
  tearDownAll(() => debugAppLocaleOverride = null);

  group('SeerrLanguageFilter.previewMark', () {
    SeerrLanguageMark? mark(String? lang, {int? status}) =>
        SeerrLanguageFilter.previewMark(_item(1, lang, status: status), active: true);

    test('hidden titles get the red SKJULES mark with the ISO code', () {
      expect(mark('ja'), const SeerrLanguageMark('JA', SeerrLanguageMarkKind.hidden));
      expect(mark('ko')!.label, 'SKJULES · KO');
      expect(mark(null), const SeerrLanguageMark('?', SeerrLanguageMarkKind.hidden));
      expect(mark(' '), const SeerrLanguageMark('?', SeerrLanguageMarkKind.hidden));
    });

    test('kept titles show the household codes', () {
      const expected = {
        'en': 'EN',
        'no': 'NO',
        'nb': 'NO',
        'nn': 'NO',
        'sv': 'SE',
        'da': 'DK',
        'de': 'DE',
        'fr': 'FR',
        'EN': 'EN',
      };
      expected.forEach((lang, code) {
        final m = mark(lang);
        expect(m, SeerrLanguageMark(code, SeerrLanguageMarkKind.kept), reason: lang);
        expect(m!.label, code);
      });
    });

    test('library titles: allowed language green, foreign grey, never hidden', () {
      expect(mark('sv', status: 5), const SeerrLanguageMark('SE', SeerrLanguageMarkKind.kept));
      expect(mark('ja', status: 5),
          const SeerrLanguageMark('JA', SeerrLanguageMarkKind.libraryForeign));
      expect(mark('ja', status: 5)!.label, 'JA');
      expect(mark(null, status: 4),
          const SeerrLanguageMark('?', SeerrLanguageMarkKind.libraryForeign));
    });

    test('nothing is marked when preview is off', () {
      expect(SeerrLanguageFilter.previewMark(_item(1, 'ja'), active: false), isNull);
      expect(SeerrLanguageFilter.previewMark(_item(1, 'en'), active: false), isNull);
    });

    test('with only badges on, every title is labelled: kept green, foreign grey', () {
      SeerrLanguageMark? badge(String? lang) => SeerrLanguageFilter.previewMark(
            _item(1, lang),
            active: false,
            badges: true,
          );
      expect(badge('en'), const SeerrLanguageMark('EN', SeerrLanguageMarkKind.kept));
      expect(badge('ja'), const SeerrLanguageMark('JA', SeerrLanguageMarkKind.foreign));
      expect(badge(null), const SeerrLanguageMark('?', SeerrLanguageMarkKind.foreign));
    });

    test('display codes cover the allowed languages', () {
      // Every default language has a badge label (the map also covers the
      // languages that can be picked in Settings).
      expect(SeerrLanguageFilter.displayCodes.keys.toSet(),
          containsAll(SeerrLanguageFilter.allowedLanguages));
    });

    test('hidden marks match exactly what apply() removes', () {
      final items = [
        for (final (i, lang) in ['en', 'ja', 'fr', 'zh', null, 'ko', 'sv'].indexed)
          _item(i, lang),
        _item(99, 'ja', status: 5),
      ];
      final kept = SeerrLanguageFilter.apply(items).map((e) => e.id).toSet();
      final hidden = items
          .where((e) =>
              SeerrLanguageFilter.previewMark(e, active: true)!.kind ==
              SeerrLanguageMarkKind.hidden)
          .map((e) => e.id)
          .toSet();
      expect(hidden.intersection(kept), isEmpty);
      expect(hidden.union(kept), items.map((e) => e.id).toSet());
    });

    test('the mark survives the raw card data round trip', () {
      for (final m in [
        const SeerrLanguageMark('JA', SeerrLanguageMarkKind.hidden),
        const SeerrLanguageMark('SE', SeerrLanguageMarkKind.kept),
        const SeerrLanguageMark('KO', SeerrLanguageMarkKind.libraryForeign),
      ]) {
        expect(SeerrLanguageMark.fromRaw({'Name': 'x', ...m.toRaw()}), m);
      }
      expect(SeerrLanguageMark.fromRaw({'Name': 'x'}), isNull);
    });
  });

  group('SeerrLanguageFilter', () {
    test('keeps the allowed languages and drops the rest', () {
      for (final lang in ['en', 'no', 'nb', 'nn', 'sv', 'da', 'de', 'fr', 'EN']) {
        expect(SeerrLanguageFilter.keeps(_item(1, lang)), isTrue, reason: lang);
      }
      for (final lang in ['ja', 'ko', 'zh', 'cn', 'hi', 'es', 'it', 'th']) {
        expect(SeerrLanguageFilter.keeps(_item(1, lang)), isFalse, reason: lang);
      }
    });

    test('drops titles without a language', () {
      expect(SeerrLanguageFilter.keeps(_item(1, null)), isFalse);
      expect(SeerrLanguageFilter.keeps(_item(1, '')), isFalse);
    });

    test('keeps titles already in the library whatever the language', () {
      expect(SeerrLanguageFilter.keeps(_item(1, 'ja', status: 5)), isTrue);
      expect(SeerrLanguageFilter.keeps(_item(1, 'ko', status: 4)), isTrue);
      expect(SeerrLanguageFilter.keeps(_item(1, 'ja', status: 2)), isFalse);
    });
  });

  group('SeerrFilledPager', () {
    test('fills a row page from further upstream pages', () async {
      final up = _FakeUpstream(keepEvery: 4); // 5 of 20 kept per page
      final pager = SeerrFilledPager();
      final page = await pager.load(key: 'k', page: 1, fetch: up.call, filter: _lang);
      expect(page.results, hasLength(20));
      expect(up.fetched, [1, 2, 3, 4]);
      expect(page.page, 1);
      expect(page.totalPages, greaterThan(1));
      expect(pager.upstreamStart('k', 2), 5);
    });

    test('next row page continues without repeats or gaps', () async {
      final up = _FakeUpstream(keepEvery: 4);
      final pager = SeerrFilledPager();
      final p1 = await pager.load(key: 'k', page: 1, fetch: up.call, filter: _lang);
      final p2 = await pager.load(key: 'k', page: 2, fetch: up.call, filter: _lang);
      final ids = [...p1.results, ...p2.results].map((i) => i.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
      expect(ids, [for (var i = 4; i <= 160; i += 4) i]);
      expect(p2.page, 2);
    });

    test('stops after the extra page cap', () async {
      final up = _FakeUpstream(keepEvery: 1000); // nothing kept
      final pager = SeerrFilledPager();
      final page = await pager.load(key: 'k', page: 1, fetch: up.call, filter: _lang);
      expect(page.results, isEmpty);
      expect(up.fetched, hasLength(SeerrFilledPager.maxExtraPages + 1));
      expect(page.totalPages, greaterThan(1));
    });

    test('reports the last page when upstream runs out', () async {
      final up = _FakeUpstream(pages: 2, keepEvery: 4);
      final pager = SeerrFilledPager();
      final page = await pager.load(key: 'k', page: 1, fetch: up.call, filter: _lang);
      expect(page.results, hasLength(10));
      expect(up.fetched, [1, 2]);
      expect(page.totalPages, 1);
    });

    test('a page asked for out of order is reached by walking forward', () async {
      final up = _FakeUpstream(keepEvery: 4);
      final pager = SeerrFilledPager();
      final p3 = await pager.load(key: 'k', page: 3, fetch: up.call, filter: _lang);
      expect(p3.page, 3);
      expect(p3.results.first.id, 164);
    });

    test('rows keep separate cursors', () async {
      final a = _FakeUpstream(keepEvery: 4);
      final b = _FakeUpstream(keepEvery: 1);
      final pager = SeerrFilledPager();
      await pager.load(key: 'a', page: 1, fetch: a.call, filter: _lang);
      await pager.load(key: 'b', page: 1, fetch: b.call, filter: _lang);
      expect(pager.upstreamStart('a', 2), 5);
      expect(pager.upstreamStart('b', 2), 2);
    });

    test('a filter error reaches the caller so it can fall back', () async {
      final up = _FakeUpstream();
      final pager = SeerrFilledPager();
      expect(
        pager.load(
          key: 'k',
          page: 1,
          fetch: up.call,
          filter: (_) async => throw StateError('boom'),
        ),
        throwsStateError,
      );
    });
  });
}
