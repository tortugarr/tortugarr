import 'package:flutter/material.dart';
import 'package:moonfin_design/moonfin_design.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../util/platform_detection.dart';
import '../../widgets/focus/tv_focus_ring.dart';
import '../../navigation/destinations.dart';
import 'providers/admin_websocket_handler.dart';
import 'widgets/admin_drawer.dart';
import 'widgets/admin_tv_focus_row.dart';

class AdminShellScreen extends StatelessWidget {
  final Widget child;

  const AdminShellScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final isWide = MediaQuery.sizeOf(context).width >= 900;
    final isCompact = width < 430;
    final currentPath = GoRouterState.of(context).uri.path;
    final drawerFocus = AdminDrawerFocusController();
    final canGoBack = !isWide &&
      (_isSubPage(currentPath) || currentPath == Destinations.adminAnalytics);

    final page = AdminWebSocketHandler(
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          backgroundColor: theme.colorScheme.surface,
          toolbarHeight: isCompact ? kToolbarHeight : 64,
          leading: isWide
              ? null
              : canGoBack
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () {
                        if (currentPath == Destinations.adminAnalytics) {
                          context.go(Destinations.admin);
                          return;
                        }
                        context.pop();
                      },
                    )
                  : Builder(
                      builder: (ctx) => IconButton(
                        icon: const Icon(Icons.menu),
                        onPressed: () => Scaffold.of(ctx).openDrawer(),
                      ),
                    ),
          titleSpacing: 12,
          title: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.adminServerAdministrationTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: isCompact ? theme.textTheme.titleMedium : theme.textTheme.titleLarge,
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: l10n.adminExitTooltip,
              onPressed: () => context.go(Destinations.home),
            ),
          ],
        ),
        drawer: isWide ? null : AdminDrawer(currentPath: currentPath),
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                theme.colorScheme.surface,
              ],
            ),
          ),
          child: isWide
              ? (PlatformDetection.isTV
                  ? AdminTvFocusRow(
                      drawerFocus: drawerFocus,
                      currentPath: currentPath,
                      isMenuPage: !_isSubPage(currentPath),
                      drawer: _drawerPane(theme, currentPath, drawerFocus),
                      content: _contentPane(theme, child),
                    )
                  : Row(
                      children: [
                        _drawerPane(theme, currentPath, null),
                        Expanded(child: _contentPane(theme, child)),
                      ],
                    ))
              : child,
        ),
      ),
    );
    if (!PlatformDetection.isTV) return page;
    // The admin pages are built for touch; make focus visible on TV, and let
    // Back on a menu page return home instead of offering to exit the app.
    return BackButtonListener(
      onBackButtonPressed: () async {
        final route = ModalRoute.of(context);
        if (route != null && !route.isCurrent) return false; // a dialog
        if (_isSubPage(currentPath)) return false;
        context.go(Destinations.home);
        return true;
      },
      child: Theme(
        data: TvFocusRing.theme(theme),
        child: TvFocusRing(child: page),
      ),
    );
  }

  static Widget _drawerPane(
    ThemeData theme,
    String currentPath,
    AdminDrawerFocusController? focus,
  ) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.scaleAlpha(0.92),
        border: Border(
          right: BorderSide(
            color: theme.colorScheme.outlineVariant,
          ),
        ),
      ),
      child: AdminDrawer(
        currentPath: currentPath,
        isEmbedded: true,
        focusController: focus,
      ),
    );
  }

  static Widget _contentPane(ThemeData theme, Widget child) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Material(
        color: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.circular(18),
          side: BorderSide(
            color: theme.colorScheme.outlineVariant,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: ScrollConfiguration(
          behavior: const _AdminShellScrollBehavior(),
          child: child,
        ),
      ),
    );
  }

  static const _topLevelPaths = {
    Destinations.admin,
    Destinations.adminUsers,
    Destinations.adminLibraries,
    Destinations.adminSettings,
    Destinations.adminSettingsBranding,
    Destinations.adminSettingsPlayback,
    Destinations.adminSettingsDisplay,
    Destinations.adminSettingsMetadata,
    Destinations.adminSettingsNfo,
    Destinations.adminTasks,
    Destinations.adminPlugins,
    Destinations.adminRepositories,
    Destinations.adminActivity,
    Destinations.adminDevices,
    Destinations.adminSettingsNetworking,
    Destinations.adminSettingsResume,
    Destinations.adminSettingsStreaming,
    Destinations.adminSettingsTrickplay,
    Destinations.adminKeys,
    Destinations.adminBackups,
    Destinations.adminLogs,
    Destinations.adminLiveTv,
  };

  static bool _isSubPage(String path) => !_topLevelPaths.contains(path);
}

class _AdminShellScrollBehavior extends MaterialScrollBehavior {
  const _AdminShellScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
