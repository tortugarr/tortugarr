import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:moonfin_design/moonfin_design.dart';

import '../../../data/services/tortugarr/smart_tube.dart';
import '../../../l10n/app_localizations.dart';
import '../../../preference/user_preferences.dart';
import '../../../util/platform_detection.dart';

/// Shows the welcome tour once, the first time Home opens after an install or update.
Future<void> showHarborTourOnce(BuildContext context) async {
  final prefs = GetIt.instance<UserPreferences>();
  if (prefs.get(UserPreferences.tgTourShown)) return;
  await prefs.set(UserPreferences.tgTourShown, true);
  if (!context.mounted) return;
  await showHarborTour(context);
}

/// The short welcome tour: how to move around Harbor, what the badges mean, how a title is
/// downloaded, where Home is changed, and SmartTube when it is installed. Also from
/// Settings › About.
Future<void> showHarborTour(BuildContext context) async {
  final hasSmartTube = await SmartTube.installedPackage() != null;
  if (!context.mounted) return;
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'tour',
    barrierColor: Colors.black.withValues(alpha: 0.72),
    pageBuilder: (context, _, _) => _HarborTour(hasSmartTube: hasSmartTube),
  );
}

class _TourPage {
  const _TourPage(this.icon, this.title, this.body);
  final IconData icon;
  final String title;
  final String body;
}

class _HarborTour extends StatefulWidget {
  const _HarborTour({required this.hasSmartTube});
  final bool hasSmartTube;

  @override
  State<_HarborTour> createState() => _HarborTourState();
}

class _HarborTourState extends State<_HarborTour> {
  final _pages = PageController();
  final _focus = FocusNode();
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    _focus.dispose();
    super.dispose();
  }

  List<_TourPage> _content(AppLocalizations l10n) => [
    _TourPage(
      Icons.sailing_rounded,
      l10n.tgTourWelcomeTitle,
      PlatformDetection.useMobileUi
          ? l10n.tgTourWelcomeTouch
          : l10n.tgTourWelcomeRemote,
    ),
    _TourPage(
      Icons.local_offer_rounded,
      l10n.tgTourBadgesTitle,
      l10n.tgTourBadgesBody,
    ),
    _TourPage(
      Icons.download_rounded,
      l10n.tgTourDownloadTitle,
      l10n.tgTourDownloadBody,
    ),
    _TourPage(Icons.tune_rounded, l10n.tgTourHomeTitle, l10n.tgTourHomeBody),
    if (widget.hasSmartTube)
      _TourPage(
        Icons.smart_display_rounded,
        l10n.tgTourSmartTubeTitle,
        l10n.tgTourSmartTubeBody,
      ),
  ];

  void _go(int page, int count) {
    if (page >= count) {
      Navigator.of(context).pop();
      return;
    }
    if (page < 0) return;
    _pages.animateToPage(
      page,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pages = _content(l10n);
    final last = _page == pages.length - 1;
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final width = (size.width * (size.width < size.height ? 0.9 : 0.52)).clamp(
      280.0,
      760.0,
    );
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyUpEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.arrowRight ||
            key == LogicalKeyboardKey.select ||
            key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter ||
            key == LogicalKeyboardKey.gameButtonA) {
          _go(_page + 1, pages.length);
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowLeft) {
          _go(_page - 1, pages.length);
          return KeyEventResult.handled;
        }
        // Up/Down have nowhere to go; Back closes the tour (the dialog's own pop).
        if (key == LogicalKeyboardKey.arrowUp ||
            key == LogicalKeyboardKey.arrowDown) {
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: width,
            padding: const EdgeInsets.fromLTRB(28, 26, 28, 18),
            decoration: BoxDecoration(
              color: AppColorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColorScheme.accent.withValues(alpha: 0.6),
                width: 1.5,
              ),
              boxShadow: const [
                BoxShadow(color: Colors.black54, blurRadius: 30),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: (size.height * 0.5).clamp(260.0, 380.0),
                  child: PageView(
                    controller: _pages,
                    onPageChanged: (p) => setState(() => _page = p),
                    children: [
                      for (final p in pages)
                        // Long text or a big font size scrolls instead of being cut.
                        Center(
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  p.icon,
                                  size: 52,
                                  color: AppColorScheme.accent,
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  p.title,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
                                        color: AppColorScheme.onSurface,
                                      ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  p.body,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: AppColorScheme.onSurface.withValues(
                                      alpha: 0.88,
                                    ),
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < pages.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: i == _page ? 22 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _page
                              ? AppColorScheme.accent
                              : AppColorScheme.onSurface.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                if (PlatformDetection.useMobileUi)
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(l10n.tgTourSkip),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () => _go(_page + 1, pages.length),
                        child: Text(last ? l10n.tgTourDone : l10n.tgTourNext),
                      ),
                    ],
                  )
                else
                  Text(
                    last ? l10n.tgTourRemoteHintLast : l10n.tgTourRemoteHint,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColorScheme.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
