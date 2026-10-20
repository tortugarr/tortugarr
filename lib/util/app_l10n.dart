import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../preference/user_preferences.dart';

/// The app's strings where no BuildContext is at hand (services, view models,
/// small helpers). Follows the same choice as the app itself: the in-app
/// language override, else the device language, else English.
AppLocalizations appL10n() => lookupAppLocalizations(appLocale());

/// Tests set this to pin the language, e.g. `Locale('nb')`.
@visibleForTesting
ui.Locale? debugAppLocaleOverride;

/// Pins the interface to English and hides the Interface language setting.
/// Off since 2026-10-20 (user decision): the app follows the device language
/// again, with the in-app override. It was on from 2026-10-05.
const bool kForceEnglish = false;

/// The locale the app shows its text in.
ui.Locale appLocale() {
  final pinned = debugAppLocaleOverride;
  if (pinned != null) return pinned;
  if (kForceEnglish) return const ui.Locale('en');
  try {
    final override =
        GetIt.instance<UserPreferences>().get(UserPreferences.languageOverride);
    if (override != 'system') {
      for (final locale in AppLocalizations.supportedLocales) {
        if (locale.toLanguageTag() == override ||
            locale.toString() == override) {
          return locale;
        }
      }
    }
  } catch (_) {}
  final system = ui.PlatformDispatcher.instance.locale;
  for (final locale in AppLocalizations.supportedLocales) {
    if (locale.languageCode == system.languageCode) return locale;
  }
  return const ui.Locale('en');
}

String _format(DateFormat Function(String tag) pattern, DateTime date) {
  try {
    return pattern(appLocale().toLanguageTag()).format(date);
  } catch (_) {
    // Date symbols for the locale are not loaded (e.g. in unit tests).
    return pattern('en').format(date);
  }
}

/// A short date in the app's language ("Oct 12" / "12. okt."), with the year
/// when it is not this year.
String appShortDate(DateTime date, {DateTime? now}) {
  final local = date.toLocal();
  final thisYear = local.year == (now ?? DateTime.now()).year;
  return _format(
    (tag) => thisYear ? DateFormat.MMMd(tag) : DateFormat.yMMMd(tag),
    local,
  );
}

/// A full date in the app's language ("October 12, 2026" / "12. oktober 2026").
String appLongDate(DateTime date) =>
    _format((tag) => DateFormat.yMMMMd(tag), date.toLocal());
