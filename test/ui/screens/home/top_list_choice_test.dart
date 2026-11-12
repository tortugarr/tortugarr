import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:jellyfin_preference/jellyfin_preference.dart';
import 'package:moonfin/l10n/app_localizations.dart';
import 'package:moonfin/preference/user_preferences.dart';
import 'package:moonfin/ui/screens/home/home_view_model.dart';
import 'package:moonfin/ui/screens/settings/top_lists_settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('rankings get numbers, plain collections do not', () {
    for (final t in ['Netflix Top 10 movies', 'IMDb Top 250', 'Most watched films this week', 'Trending movies now', 'Popular on Rotten Tomatoes: shows']) {
      expect(HomeViewModel.isRankedTopList(t), isTrue, reason: t);
    }
    for (final t in ['New on digital', 'Certified Fresh: new movies']) {
      expect(HomeViewModel.isRankedTopList(t), isFalse, reason: t);
    }
  });

  testWidgets('switching a list off stores it as hidden, on again removes it', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{'pref_last_server_id': 's', 'pref_last_user_id': 'u'});
    final store = PreferenceStore();
    await store.init();
    final prefs = UserPreferences(store);
    GetIt.instance.registerSingleton<UserPreferences>(prefs);
    addTearDown(GetIt.instance.reset);

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: TopListsSettingsScreen(
        loadLists: () async => [(index: 0, title: 'IMDb Top 250'), (index: 1, title: 'Netflix Top 10 shows')],
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(Switch), findsNWidgets(2));

    await tester.tap(find.text('IMDb Top 250'));
    await tester.pumpAndSettle();
    expect(prefs.tgHiddenTopListTitles, {'IMDb Top 250'});

    await tester.tap(find.text('IMDb Top 250'));
    await tester.pumpAndSettle();
    expect(prefs.tgHiddenTopListTitles, isEmpty);
  });
}
