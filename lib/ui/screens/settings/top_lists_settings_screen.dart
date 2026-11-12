import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../data/services/tortugarr/tortugarr_plugin_client.dart';
import '../../../l10n/app_localizations.dart';
import '../../../preference/user_preferences.dart';
import '../../widgets/adaptive/adaptive_list_section.dart';
import '../../widgets/focus/request_initial_focus.dart';
import '../../widgets/settings/clean_settings_typography.dart';
import '../home/home_view_model.dart';
import 'settings_app_bar.dart';

/// Settings > Appearance > Home Screen > Top lists: one switch per list the
/// Tortugarr server offers. Switched-off lists are not fetched or shown.
class TopListsSettingsScreen extends StatefulWidget {
  const TopListsSettingsScreen({super.key, this.loadLists});

  /// Test seam; defaults to the plugin's list of top lists.
  final Future<List<({int index, String title})>> Function()? loadLists;

  @override
  State<TopListsSettingsScreen> createState() => _TopListsSettingsScreenState();
}

class _TopListsSettingsScreenState extends State<TopListsSettingsScreen> {
  final _prefs = GetIt.instance<UserPreferences>();
  late final Future<List<({int index, String title})>> _lists =
      (widget.loadLists ?? TortugarrPluginClient().topLists)();
  bool _changed = false;

  @override
  void dispose() {
    if (_changed && GetIt.instance.isRegistered<HomeViewModel>()) {
      GetIt.instance<HomeViewModel>().load(preserveExisting: true);
    }
    super.dispose();
  }

  Future<void> _set(String title, bool shown) async {
    final key = HomeViewModel.topListKey(title);
    final hidden = _prefs.tgHiddenTopListTitles;
    shown ? hidden.remove(key) : hidden.add(key);
    await _prefs.set(UserPreferences.tgHiddenTopLists, hidden.join(','));
    _changed = true;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return RequestInitialFocus(
      child: withCleanSettingsTypography(
        context,
        Scaffold(
          appBar: buildSettingsAppBar(context, Text(l10n.tgTopListsRow)),
          body: FutureBuilder<List<({int index, String title})>>(
            future: _lists,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              final lists = snap.data ?? const [];
              if (snap.hasError || lists.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(l10n.tgTopListsNone, textAlign: TextAlign.center),
                  ),
                );
              }
              final hidden = _prefs.tgHiddenTopListTitles;
              return ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(l10n.tgTopListsSettingsHint),
                  ),
                  adaptiveListSection(
                    children: [
                      for (final (i, l) in lists.indexed)
                        SwitchListTile(
                          autofocus: i == 0,
                          title: Text(l.title),
                          value: !hidden.contains(HomeViewModel.topListKey(l.title)),
                          onChanged: (v) => _set(l.title, v),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
