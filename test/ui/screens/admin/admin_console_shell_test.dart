import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:moonfin/data/services/socket_handler.dart';
import 'package:moonfin/di/providers.dart';
import 'package:moonfin/l10n/app_localizations.dart';
import 'package:moonfin/ui/navigation/destinations.dart';
import 'package:moonfin/ui/screens/admin/admin_draft.dart';
import 'package:moonfin/ui/screens/admin/admin_group_index_screen.dart';
import 'package:moonfin/ui/screens/admin/admin_shell_screen.dart';

/// A settings page with one field and a draft, like the real ones.
class _DraftPage extends StatefulWidget {
  const _DraftPage(this.label);
  final String label;

  @override
  State<_DraftPage> createState() => _DraftPageState();
}

class _DraftPageState extends State<_DraftPage> {
  final config = <String, dynamic>{'ServerName': 'Moonbase'};
  late final draft = AdminDraft.single(
    working: config,
    reload: () async => {'ServerName': 'Moonbase', 'Other': 1},
    post: (value) async => posted = value,
  );
  Map<String, dynamic>? posted;

  @override
  void initState() {
    super.initState();
    draft.claim();
  }

  @override
  void dispose() {
    draft.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: draft,
    builder: (context, _) => Column(
      children: [
        Text(widget.label),
        KeyedSubtree(
          key: ValueKey(draft.revision),
          child: TextFormField(
            key: const Key('field'),
            initialValue: config['ServerName'] as String,
            onChanged: (v) {
              config['ServerName'] = v;
              draft.touch();
            },
          ),
        ),
      ],
    ),
  );
}

void main() {
  late AppLocalizations l10n;

  // Exit reopens Settings in the app; the panel needs services these tests
  // do not register.
  setUpAll(() => AdminShellScreen.reopenSettingsOnExit = false);
  tearDownAll(() => AdminShellScreen.reopenSettingsOnExit = true);

  void setWindow(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<GoRouter> pumpShell(WidgetTester tester, String initial) async {
    GoRoute page(String path, Widget child) =>
        GoRoute(path: path, onExit: confirmAdminLeave, builder: (_, _) => child);
    final router = GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(path: Destinations.home, builder: (_, _) => const Text('home')),
        ShellRoute(
          navigatorKey: AdminShellScreen.navigatorKey,
          builder: (context, state, child) => AdminShellScreen(child: child),
          routes: [
            page(Destinations.admin, const Text('dashboard page')),
            page(Destinations.adminSettings, const _DraftPage('settings page')),
            page(Destinations.adminUsers, const Text('users page')),
            GoRoute(
              path: Destinations.adminGroup,
              builder: (_, s) =>
                  AdminGroupIndexScreen(groupId: s.pathParameters['groupId']!),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [socketHandlerProvider.overrideWithValue(SocketHandler())],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    l10n = AppLocalizations.of(tester.element(find.byType(AdminShellScreen)));
    return router;
  }

  tearDown(() => AdminDraft.active.value = null);

  testWidgets('a wide window shows the group rail and the page list', (
    tester,
  ) async {
    setWindow(tester, const Size(1400, 900));
    await pumpShell(tester, Destinations.admin);

    expect(find.text(l10n.adminGroupPeople), findsOneWidget);
    expect(find.text(l10n.adminPageDescActivity), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await tester.tap(find.text(l10n.adminGroupPeople));
    await tester.pumpAndSettle();
    expect(find.text('users page'), findsOneWidget);
    expect(find.text(l10n.adminPageDescDevices), findsOneWidget);
  });

  testWidgets('a phone uses group tabs that open the group page list', (
    tester,
  ) async {
    setWindow(tester, const Size(390, 844));
    await pumpShell(tester, Destinations.admin);

    expect(find.byType(NavigationBar), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(l10n.adminGroupSystem),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(l10n.adminPageDescNetworking), findsOneWidget);

    await tester.tap(find.text(l10n.adminDrawerSettings));
    await tester.pumpAndSettle();
    expect(find.text('settings page'), findsOneWidget);
  });

  testWidgets('a page opened from the phone list has a way back to it', (
    tester,
  ) async {
    setWindow(tester, const Size(390, 844));
    await pumpShell(tester, Destinations.adminGroupPath('people'));
    expect(find.byTooltip('Back'), findsNothing);

    await tester.tap(find.text(l10n.adminDrawerUsers));
    await tester.pumpAndSettle();
    expect(find.text('users page'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text(l10n.adminPageDescUsers), findsOneWidget);
  });

  testWidgets('the Moonfin mark leaves the area in both layouts', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    for (final size in const [Size(1400, 900), Size(390, 844)]) {
      setWindow(tester, size);
      await pumpShell(tester, Destinations.adminUsers);
      expect(
        tester.getSemantics(find.bySemanticsLabel(l10n.adminExitTooltip)),
        isSemantics(
          label: l10n.adminExitTooltip,
          isButton: true,
          hasTapAction: true,
        ),
        reason: '$size',
      );

      await tester.tap(find.text(l10n.exit));
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget, reason: '$size');
    }
    semantics.dispose();
  });

  testWidgets('an edit brings up the bar and discard puts it back', (
    tester,
  ) async {
    setWindow(tester, const Size(1400, 900));
    await pumpShell(tester, Destinations.adminSettings);
    expect(find.text(l10n.adminUnsavedChanges), findsNothing);

    await tester.enterText(find.byKey(const Key('field')), 'Renamed');
    await tester.pumpAndSettle();
    expect(find.text(l10n.adminUnsavedChanges), findsOneWidget);

    await tester.tap(find.text(l10n.adminDiscard));
    await tester.pumpAndSettle();
    expect(find.text(l10n.adminUnsavedChanges), findsNothing);
    expect(find.text('Moonbase'), findsOneWidget);
  });

  testWidgets('save lays only the edited key over a fresh copy', (
    tester,
  ) async {
    setWindow(tester, const Size(1400, 900));
    await pumpShell(tester, Destinations.adminSettings);
    await tester.enterText(find.byKey(const Key('field')), 'Renamed');
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.save));
    await tester.pumpAndSettle();

    final state = tester.state<_DraftPageState>(find.byType(_DraftPage));
    expect(state.posted, {'ServerName': 'Renamed', 'Other': 1});
    expect(find.text(l10n.adminUnsavedChanges), findsNothing);
  });

  testWidgets('leaving a dirty page asks first and stays on keep editing', (
    tester,
  ) async {
    setWindow(tester, const Size(1400, 900));
    final router = await pumpShell(tester, Destinations.adminSettings);
    await tester.enterText(find.byKey(const Key('field')), 'Renamed');
    await tester.pumpAndSettle();

    router.go(Destinations.adminUsers);
    await tester.pumpAndSettle();
    expect(find.text(l10n.adminLeaveTitle), findsOneWidget);

    await tester.tap(find.text(l10n.adminKeepEditing));
    await tester.pumpAndSettle();
    expect(find.text('settings page'), findsOneWidget);
    expect(find.text('users page'), findsNothing);

    router.go(Destinations.adminUsers);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.adminDiscard).last);
    await tester.pumpAndSettle();
    expect(find.text('users page'), findsOneWidget);
    expect(find.text(l10n.adminLeaveTitle), findsNothing);
  });

  // The "Settings saved" snackbar sits where the bar comes back, so the bar
  // has to clear it for an edit right after a save to reach Save.
  testWidgets('an edit right after a save can be saved again', (tester) async {
    setWindow(tester, const Size(1400, 900));
    await pumpShell(tester, Destinations.adminSettings);
    await tester.enterText(find.byKey(const Key('field')), 'One');
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.save));
    await tester.pumpAndSettle();
    expect(find.text(l10n.adminSettingsSaved), findsOneWidget);

    await tester.enterText(find.byKey(const Key('field')), 'Two');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text(l10n.adminSettingsSaved), findsNothing);

    await tester.tap(find.text(l10n.save), warnIfMissed: true);
    await tester.pumpAndSettle();
    final state = tester.state<_DraftPageState>(find.byType(_DraftPage));
    expect(state.posted?['ServerName'], 'Two');
  });

  testWidgets('a clean page leaves without asking', (tester) async {
    setWindow(tester, const Size(1400, 900));
    final router = await pumpShell(tester, Destinations.adminSettings);

    router.go(Destinations.adminUsers);
    await tester.pumpAndSettle();
    expect(find.text(l10n.adminLeaveTitle), findsNothing);
    expect(find.text('users page'), findsOneWidget);
  });
}
