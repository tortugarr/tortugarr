import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:moonfin_design/moonfin_design.dart';

import '../../../l10n/app_localizations.dart';
import '../../navigation/destinations.dart';
import 'admin_nav.dart';
import 'providers/admin_websocket_handler.dart';
import 'widgets/admin_settings_search.dart';
import 'widgets/admin_tv_keys.dart';
import 'widgets/admin_unsaved_bar.dart';
import '../../../util/platform_detection.dart';
import '../../widgets/focus/tv_focus_ring.dart';

/// The admin area's frame. Wide windows get the group rail, the page list
/// and breadcrumbs. Narrow ones get a bottom bar of groups that open each
/// group's page list.
class AdminShellScreen extends StatelessWidget {
  final Widget child;

  /// The admin area's own navigator, so its stack can be told apart from the
  /// root one, which also holds the home screen the whole area was pushed over.
  static final navigatorKey = GlobalKey<NavigatorState>(debugLabel: 'admin');

  static const wideBreakpoint = 900.0;

  const AdminShellScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWide = MediaQuery.sizeOf(context).width >= wideBreakpoint;
    final path = GoRouterState.of(context).uri.path;
    final page = adminPageFor(path);
    final group = _groupFor(path, page);
    // A screen pushed inside the area pops back to the one that opened it.
    // The depth comes from the router rather than the navigator, which is a
    // child of this widget and still holds the previous stack while this
    // builds.
    final canGoBack = _stackDepth(context) > 1;
    // Blended over the scaffold up front so the gradient is opaque, since
    // every page also paints it over the page it replaces.
    final backdrop = BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.alphaBlend(
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
            theme.scaffoldBackgroundColor,
          ),
          Color.alphaBlend(
            theme.colorScheme.surface,
            theme.scaffoldBackgroundColor,
          ),
        ],
      ),
    );
    // Admin pages draw no background of their own, so each one carries what
    // sits behind it. Otherwise the page being left stays readable under the
    // one fading in.
    final pages = Theme(
      data: theme.copyWith(
        pageTransitionsTheme: _BackedPageTransitions(
          theme.pageTransitionsTheme,
          backdrop: backdrop,
          panel: isWide ? theme.colorScheme.surface : null,
        ),
      ),
      child: ScrollConfiguration(
        behavior: const _AdminShellScrollBehavior(),
        // Each page's route blocks the semantics painted before it, which
        // would hide the rail and page list from screen readers.
        child: Semantics(container: true, child: child),
      ),
    );

    // With nothing under the area, Android only hands Back to the app while a
    // route claims it. Otherwise it closes the app.
    final shell = PopScope(
      canPop: Navigator.of(context).canPop(),
      child: AdminWebSocketHandler(
        child: isWide
            ? _WideShell(
                backdrop: backdrop,
                group: group,
                page: page,
                canGoBack: canGoBack,
                child: pages,
              )
            : _NarrowShell(
                backdrop: backdrop,
                group: group,
                canGoBack: canGoBack,
                child: pages,
              ),
      ),
    );
    if (!PlatformDetection.isTV) return shell;
    // The admin pages are built for touch; make focus visible on TV.
    return Theme(
      data: TvFocusRing.theme(theme),
      child: TvFocusRing(
        child: AdminTvKeys(pages: AdminShellScreen.navigatorKey, child: shell),
      ),
    );
  }

  static AdminGroup _groupFor(String path, AdminPage? page) {
    final prefix = Destinations.adminGroupPath('');
    if (path.startsWith(prefix)) {
      final group = adminGroupById(path.substring(prefix.length));
      if (group != null) return group;
    }
    return page == null ? adminGroups.first : adminGroupOf(page);
  }

  static int _stackDepth(BuildContext context) {
    final configuration = GoRouter.of(context).routerDelegate.currentConfiguration;
    for (final match in configuration.matches) {
      if (match is ShellRouteMatch && match.navigatorKey == navigatorKey) {
        return match.matches.length;
      }
    }
    return 0;
  }
}

class _WideShell extends StatelessWidget {
  const _WideShell({
    required this.backdrop,
    required this.group,
    required this.page,
    required this.canGoBack,
    required this.child,
  });

  final BoxDecoration backdrop;
  final AdminGroup group;
  final AdminPage? page;
  final bool canGoBack;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: DecoratedBox(
        decoration: backdrop,
        child: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _GroupRail(selected: group),
              _PageList(group: group, selected: page),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 56,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 16, 0),
                        child: Row(
                          children: [
                            if (canGoBack)
                              IconButton(
                                icon: const Icon(Icons.arrow_back),
                                tooltip: MaterialLocalizations.of(context)
                                    .backButtonTooltip,
                                onPressed: context.pop,
                              ),
                            Expanded(
                              child: _Breadcrumbs(group: group, page: page),
                            ),
                            const SizedBox(width: 12),
                            const SizedBox(
                              width: 340,
                              child: AdminSettingsSearch(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(0, 0, 16, 16),
                        child: Material(
                          color: theme.colorScheme.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.circular(18),
                            side: BorderSide(
                              color: theme.colorScheme.outlineVariant,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(child: child),
                              const AdminUnsavedBar(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NarrowShell extends StatelessWidget {
  const _NarrowShell({
    required this.backdrop,
    required this.group,
    required this.canGoBack,
    required this.child,
  });

  final BoxDecoration backdrop;
  final AdminGroup group;
  final bool canGoBack;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final index = adminGroups.indexOf(group);
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        // The area sits over the home screen, so an empty slot would get an
        // implied arrow that leaves it, which is what the Moonfin mark is for.
        automaticallyImplyLeading: false,
        backgroundColor: theme.colorScheme.surface,
        leading: canGoBack
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: context.pop,
              )
            : const Center(child: _ExitMark(size: 24)),
        titleSpacing: canGoBack ? 4 : 0,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.adminServerAdministrationTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 0.6,
              ),
            ),
            Text(
              group.title(l10n),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium,
            ),
          ],
        ),
      ),
      body: DecoratedBox(
        decoration: backdrop,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [Expanded(child: child), const AdminUnsavedBar()],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        // The rail's tint, not the theme's secondary container.
        indicatorColor: theme.colorScheme.primary.withValues(alpha: 0.14),
        selectedIndex: index < 0 ? 0 : index,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (i) =>
            context.go(Destinations.adminGroupPath(adminGroups[i].id)),
        destinations: [
          for (final g in adminGroups)
            NavigationDestination(
              icon: Icon(g.icon),
              selectedIcon: Icon(g.icon, color: theme.colorScheme.primary),
              label: g.title(l10n),
            ),
        ],
      ),
    );
  }
}

class _GroupRail extends StatelessWidget {
  const _GroupRail({required this.selected});

  final AdminGroup selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Semantics(
      container: true,
      label: l10n.adminAreasLabel,
      child: Container(
        width: 72,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            Colors.black.withValues(alpha: 0.18),
            theme.colorScheme.surface,
          ),
          border: Border(
            right: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        child: Column(
          children: [
            const _ExitMark(size: 34),
            const SizedBox(height: 18),
            for (final group in adminGroups)
              _RailButton(
                icon: group.icon,
                label: group.title(l10n),
                selected: group == selected,
                // Wide windows show the page list beside the rail, so a group
                // opens straight on its first page.
                onTap: () => context.go(group.pages.first.route),
              ),
          ],
        ),
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: selected
              ? scheme.primary.withValues(alpha: 0.14)
              : Colors.transparent,
          borderRadius: AppRadius.circular(10),
          child: InkWell(
            borderRadius: AppRadius.circular(10),
            onTap: onTap,
            child: SizedBox(
              width: 60,
              height: 58,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 22, color: color),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PageList extends StatelessWidget {
  const _PageList({required this.group, required this.selected});

  final AdminGroup group;
  final AdminPage? selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Semantics(
      container: true,
      label: l10n.adminPagesLabel,
      child: Container(
        width: 240,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.92),
          border: Border(
            right: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(10, 18, 10, 16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.adminServerAdministrationTitle.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      letterSpacing: 0.9,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(group.title(l10n), style: theme.textTheme.titleLarge),
                ],
              ),
            ),
            for (final page in group.pagesOn(AdminServerScope.of(context)))
              AdminPageTile(page: page, selected: page == selected),
          ],
        ),
      ),
    );
  }
}

/// A page with its description, used by the wide page list and the phone
/// group index.
class AdminPageTile extends StatelessWidget {
  const AdminPageTile({
    super.key,
    required this.page,
    this.selected = false,
    this.showChevron = false,
  });

  final AdminPage page;
  final bool selected;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Semantics(
        selected: selected,
        child: Material(
          color: selected ? scheme.surfaceContainerHighest : Colors.transparent,
          borderRadius: AppRadius.circular(9),
          child: InkWell(
            borderRadius: AppRadius.circular(9),
            // The phone's page list opens a page over itself, so the page
            // gets a back arrow to it.
            onTap: selected
                ? null
                : () => showChevron
                    ? context.push(page.route)
                    : context.go(page.route),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: page.buildIcon(
                      18,
                      selected ? scheme.primary : scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          page.title(l10n),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: selected ? scheme.onSurface : null,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          page.description(l10n),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (showChevron)
                    Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Breadcrumbs extends StatelessWidget {
  const _Breadcrumbs({required this.group, required this.page});

  final AdminGroup group;
  final AdminPage? page;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final crumbs = <(String, String)>[
      (group.title(l10n), group.pages.first.route),
      if (page != null) (page!.title(l10n), page!.route),
    ];
    return Row(
      children: [
        for (var i = 0; i < crumbs.length; i++) ...[
          if (i > 0) Icon(Icons.chevron_right, size: 16, color: muted),
          Flexible(
            child: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: i == crumbs.length - 1 ? null : muted,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: const Size(0, 32),
              ),
              onPressed: () => context.go(crumbs[i].$2),
              child: Text(
                crumbs[i].$1,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: i == crumbs.length - 1
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// The Moonfin mark with Exit under it. Tapping it leaves the area.
class _ExitMark extends StatelessWidget {
  const _ExitMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    void leave() => context.go(Destinations.home);
    return Semantics(
      button: true,
      label: l10n.adminExitTooltip,
      excludeSemantics: true,
      onTap: leave,
      child: Tooltip(
        message: l10n.adminExitTooltip,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: AppRadius.circular(10),
            onTap: leave,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/icons/tortugarr_admin_exit.png',
                    width: size,
                    height: size,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.exit,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BackedPageTransitions extends PageTransitionsTheme {
  _BackedPageTransitions(this._base, {required this.backdrop, this.panel})
    : super(builders: _base.builders);

  final PageTransitionsTheme _base;
  final Decoration backdrop;

  /// The wide layout's panel color, painted over [backdrop] the way the panel
  /// sits over the body.
  final Color? panel;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => _base.buildTransitions(
    route,
    context,
    animation,
    secondaryAnimation,
    DecoratedBox(
      decoration: backdrop,
      child: panel == null ? child : ColoredBox(color: panel!, child: child),
    ),
  );
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
