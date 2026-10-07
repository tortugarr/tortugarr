import 'dart:ui';

import 'app_localizations.dart';

AppLocalizations currentAppLocalizations() {
  final locale = PlatformDispatcher.instance.locale;
  try {
    return lookupAppLocalizations(locale);
  } catch (_) {
    return lookupAppLocalizations(const Locale('en'));
  }
}
