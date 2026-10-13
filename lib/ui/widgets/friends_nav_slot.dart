import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../data/services/achievements_service.dart';
import '../../preference/user_preferences.dart';
import '../screens/settings/achievements_screen.dart';
import 'settings/settings_panel.dart';

/// Wraps the friends button for a nav bar.
///
/// Renders nothing when the user turned the button off or the server has no
/// friends feature. Hands the builder the number of friend requests and unread
/// messages, which the button draws as a red circle on its icon.
class FriendsNavSlot extends StatelessWidget {
  final Widget Function(BuildContext context, int badge) builder;

  const FriendsNavSlot({super.key, required this.builder});

  static bool isOffered() =>
      GetIt.instance<UserPreferences>().get(UserPreferences.showFriendsButton);

  /// Whether the button has something to open right now.
  static bool isAvailable() =>
      GetIt.instance.isRegistered<AchievementsService>() &&
      GetIt.instance<AchievementsService>().socialAvailable;

  /// Opens the friends list in the side panel the settings use.
  static Future<void> open(BuildContext context) =>
      SettingsPanel.open(context, const FriendsScreen());

  @override
  Widget build(BuildContext context) {
    if (!isOffered() || !GetIt.instance.isRegistered<AchievementsService>()) {
      return const SizedBox.shrink();
    }

    final service = GetIt.instance<AchievementsService>();

    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        if (!service.socialAvailable) return const SizedBox.shrink();
        return builder(context, service.socialBadgeCount);
      },
    );
  }
}
