part of '../settings_side_panel.dart';

/// Every keyboard shortcut the app answers to on this platform, reachable
/// from About so a desktop user can find the keys without guessing.
class _KeyboardShortcutsScreen extends StatelessWidget {
  const _KeyboardShortcutsScreen();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: buildSettingsAppBar(context, Text(l10n.keyboardShortcutsTitle)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          KeyboardShortcutList(sections: keyboardShortcutSections(l10n)),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.spaceLg,
              AppSpacing.spaceLg,
              AppSpacing.spaceLg,
              AppSpacing.spaceXl,
            ),
            child: Text(
              l10n.keyboardShortcutsPlayerHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
