import 'package:get_it/get_it.dart';

import '../../preference/user_preferences.dart';

/// Oldest date the home Next Up row reaches back to, or null for no limit.
///
/// Without a cutoff the server walks the entire watch history, which is slow
/// enough to time out on a large library. A series page skips this, since a
/// window there would hide the episode the user opened the show for.
DateTime? get nextUpDateCutoff {
  final prefs = GetIt.instance.isRegistered<UserPreferences>()
      ? GetIt.instance<UserPreferences>()
      : null;
  final days = prefs?.get(UserPreferences.nextUpMaxDays) ??
      UserPreferences.nextUpMaxDays.defaultValue;
  if (days <= 0) return null;
  return DateTime.now().subtract(Duration(days: days));
}
