import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonfin/data/services/socket_handler.dart';
import 'package:moonfin/l10n/app_localizations.dart';
import 'package:moonfin/ui/navigation/destinations.dart';
import 'package:moonfin/ui/screens/admin/admin_dashboard_screen.dart';
import 'package:moonfin/ui/screens/admin/admin_draft.dart';
import 'package:moonfin/ui/screens/admin/admin_nav.dart';
import 'package:moonfin/ui/screens/admin/widgets/active_sessions_card.dart';
import 'package:moonfin/ui/screens/admin/widgets/session_detail_sheet.dart';
import 'package:server_core/server_core.dart';

class _MockMediaServerClient extends Mock implements MediaServerClient {}

class _FakeSystemApi extends Fake implements SystemApi {
  Map<String, dynamic> info = {
    'ServerName': 'Moonbase',
    'Version': '10.12.2',
    // Obsolete and always true on 12.2, so it must not hide Restart.
    'CanSelfRestart': false,
  };

  @override
  Future<Map<String, dynamic>> getSystemInfo() async => info;
}

/// Emby 4.10's /System/Info, which is also its storage info: folder paths
/// and no sizes.
const _embyInfo = {
  'ServerName': 'Emby Box',
  'Version': '4.10.1.0',
  'OperatingSystem': 'Linux',
  'CanSelfRestart': true,
  'HasPendingRestart': true,
  'ProgramDataPath': '/config',
  'CachePath': '/config/cache',
  'LogPath': '/config/logs',
  'InternalMetadataPath': '/config/metadata',
  'TranscodingTempPath': '/config/transcoding-temp',
};

class _FakeAdminSystemApi extends Fake implements AdminSystemApi {
  final logCalls = <Map<String, Object?>>[];
  List<ActivityLogEntry> alerts = const [];
  int restarts = 0;
  StorageInfo? storage;

  @override
  Future<StorageInfo> getStorageInfo() async =>
      storage ?? (throw Exception('no storage'));

  @override
  Future<ActivityLogResult> getActivityLog({
    int? startIndex,
    int? limit,
    bool? hasUserId,
    DateTime? minDate,
    DateTime? maxDate,
    String? severity,
    String? username,
  }) async {
    logCalls.add({
      'startIndex': startIndex,
      'limit': limit,
      'hasUserId': hasUserId,
      'minDate': minDate,
    });
    final items = hasUserId == true
        ? [_entry('Axl started playing Dune')]
        : alerts;
    return ActivityLogResult(items: items, totalRecordCount: items.length);
  }

  // The zero counts should hide their cards.
  @override
  Future<Map<String, dynamic>> getItemCounts() async => {
    'MovieCount': 31,
    'SeriesCount': 0,
    'EpisodeCount': 0,
    'AlbumCount': 0,
    'SongCount': 0,
    'MusicVideoCount': 12,
    'BookCount': 0,
    'BoxSetCount': 45,
  };

  @override
  Future<void> restartServer() async => restarts++;
}

ActivityLogEntry _entry(String name) => ActivityLogEntry(
  id: name,
  name: name,
  type: 'VideoPlayback',
  date: DateTime.now().subtract(const Duration(minutes: 10)),
);

class _FakeSessionApi extends Fake implements SessionApi {
  final sessionCalls = <int?>[];
  final messages = <(String, String, int?)>[];
  final commands = <(String, String)>[];
  List<Map<String, dynamic>> sessions = [];

  @override
  Future<List<Map<String, dynamic>>> getSessions({
    String? controllableByUserId,
    int? activeWithinSeconds,
  }) async {
    sessionCalls.add(activeWithinSeconds);
    return sessions;
  }

  @override
  Future<void> sendMessage(
    String sessionId,
    String text, {
    String? header,
    int? timeoutMs,
  }) async => messages.add((sessionId, text, timeoutMs));

  @override
  Future<void> sendGeneralCommand(
    String sessionId,
    String commandName, {
    Map<String, String>? arguments,
  }) async => commands.add((sessionId, commandName));
}

class _FakeTasksApi extends Fake implements AdminTasksApi {
  String scanState = 'Idle';
  final started = <String>[];

  @override
  Future<List<Map<String, dynamic>>> getTasks({bool? isHidden}) async => [
    {
      'Id': 'scan-id',
      'Key': 'RefreshLibrary',
      'Name': 'Scan Media Library',
      'Category': 'Library',
      'State': scanState,
    },
  ];

  @override
  Future<void> startTask(String taskId) async => started.add(taskId);
}

class _FakePluginsApi extends Fake implements AdminPluginsApi {
  @override
  Future<List<PluginInfo>> getInstalledPlugins() async => const [];

  @override
  Future<List<PackageInfo>> getAvailablePackages() async => const [];
}

/// Counts /Items calls, since the dashboard counts should come from
/// /Items/Counts alone.
class _FakeItemsApi extends Fake implements ItemsApi {
  int calls = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls++;
    return Future.value(<String, dynamic>{'TotalRecordCount': 0});
  }
}

Map<String, dynamic> _session(
  String device, {
  bool remote = true,
  bool playing = true,
}) => {
  'Id': 'session-$device',
  'DeviceId': device,
  'DeviceName': device,
  'Client': 'Moonfin',
  'UserName': 'Axl',
  'UserId': 'u1',
  'ServerId': 'server',
  'SupportsRemoteControl': remote,
  'LastActivityDate': DateTime.now().toUtc().toIso8601String(),
  if (playing) 'NowPlayingItem': {'Name': 'Dune', 'RunTimeTicks': 100},
  if (playing) 'PlayState': {'PositionTicks': 50, 'PlayMethod': 'DirectPlay'},
};

void main() {
  late _FakeSystemApi info;
  late _FakeAdminSystemApi system;
  late _FakeSessionApi sessions;
  late _FakeTasksApi tasks;
  late _FakeItemsApi items;
  late AppLocalizations l10n;

  setUp(() async {
    info = _FakeSystemApi();
    system = _FakeAdminSystemApi();
    sessions = _FakeSessionApi()
      ..sessions = [_session('tv'), _session('phone', playing: false)];
    tasks = _FakeTasksApi();
    items = _FakeItemsApi();
    final client = _MockMediaServerClient();
    when(() => client.systemApi).thenReturn(info);
    when(() => client.adminSystemApi).thenReturn(system);
    when(() => client.sessionApi).thenReturn(sessions);
    when(() => client.adminTasksApi).thenReturn(tasks);
    when(() => client.adminPluginsApi).thenReturn(_FakePluginsApi());
    when(() => client.itemsApi).thenReturn(items);
    await GetIt.instance.reset();
    GetIt.instance
      ..registerSingleton<MediaServerClient>(client)
      ..registerSingleton<SocketHandler>(SocketHandler());
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  tearDown(() async {
    AdminDraft.active.value = null;
    await GetIt.instance.reset();
  });

  Future<void> pumpDashboard(
    WidgetTester tester, {
    bool settle = true,
    ServerType server = ServerType.jellyfin,
  }) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: Destinations.admin,
      routes: [
        GoRoute(
          path: Destinations.admin,
          builder: (_, _) => AdminServerScope(
            serverType: server,
            child: const Scaffold(body: AdminDashboardScreen()),
          ),
        ),
        GoRoute(
          path: Destinations.adminActivity,
          builder: (_, state) => Scaffold(body: Text('opened ${state.uri}')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      // A running task animates forever, so settle by hand.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }
  }

  testWidgets('the log panels ask for a day of user and a week of system entries', (
    tester,
  ) async {
    await pumpDashboard(tester);
    final now = DateTime.now();

    // Activity, the alerts panel, and (2026-11-08) the count of alerts not
    // seen yet for the Alerts tile.
    expect(system.logCalls, hasLength(3));
    final activity = system.logCalls.singleWhere((c) => c['limit'] == 7);
    final alerts = system.logCalls.singleWhere((c) => c['limit'] == 4);
    final unseen = system.logCalls.singleWhere((c) => c['limit'] == 1);
    expect(unseen['hasUserId'], isFalse);
    expect(activity['startIndex'], 0);
    expect(activity['hasUserId'], isTrue);
    expect(
      now.difference(activity['minDate']! as DateTime).inMinutes,
      closeTo(24 * 60, 1),
    );
    expect(alerts['startIndex'], 0);
    expect(alerts['hasUserId'], isFalse);
    expect(
      now.difference(alerts['minDate']! as DateTime).inMinutes,
      closeTo(7 * 24 * 60, 1),
    );
    expect(find.text('Axl started playing Dune'), findsOneWidget);
  });

  testWidgets('the alerts panel hides when there are no alerts', (
    tester,
  ) async {
    await pumpDashboard(tester);
    expect(find.text(l10n.adminDashboardAlerts.toUpperCase()), findsNothing);
  });

  testWidgets('the alerts panel lists the system entries', (tester) async {
    system.alerts = [_entry('Subtitle download failed')];
    await pumpDashboard(tester);
    expect(find.text(l10n.adminDashboardAlerts.toUpperCase()), findsOneWidget);
    expect(find.text('Subtitle download failed'), findsOneWidget);
  });

  testWidgets('See all opens the activity page in the matching view', (
    tester,
  ) async {
    system.alerts = [_entry('Subtitle download failed')];
    await pumpDashboard(tester);

    await tester.tap(find.text(l10n.seeAll).last);
    await tester.pumpAndSettle();
    expect(find.text('opened /admin/activity?useractivity=false'), findsOneWidget);
  });

  testWidgets('one 960 s sessions load feeds the count and the card', (
    tester,
  ) async {
    await pumpDashboard(tester);

    expect(sessions.sessionCalls, [960]);
    // The KPI tile and the sessions card header.
    expect(find.text('2'), findsNWidgets(2));
  });

  testWidgets('counts read BoxSetCount, add music videos, hide zeros', (
    tester,
  ) async {
    await pumpDashboard(tester);

    expect(find.text('45'), findsOneWidget);
    expect(find.text(l10n.musicVideos), findsOneWidget);
    expect(find.text(l10n.movies), findsOneWidget);
    expect(find.text(l10n.series), findsNothing);
    expect(items.calls, 0);
  });

  testWidgets('Restart shows without CanSelfRestart and asks first', (
    tester,
  ) async {
    await pumpDashboard(tester);

    await tester.tap(find.text(l10n.adminRestartServer));
    await tester.pumpAndSettle();
    expect(find.text(l10n.adminRestartServerConfirmation), findsOneWidget);
    expect(system.restarts, 0);

    await tester.tap(find.text(l10n.confirm));
    await tester.pumpAndSettle();
    expect(system.restarts, 1);
  });

  testWidgets('Jellyfin keeps the disk tile', (tester) async {
    await pumpDashboard(tester);
    expect(find.text(l10n.disk), findsOneWidget);
  });

  group('on Emby', () {
    setUp(() {
      info.info = Map.of(_embyInfo);
      system.storage = StorageInfo.fromJson(_embyInfo);
    });

    testWidgets('folder paths show without sizes and no disk tile', (
      tester,
    ) async {
      await pumpDashboard(tester, server: ServerType.emby);

      expect(find.text('/config/cache'), findsOneWidget);
      expect(find.text('/config/transcoding-temp'), findsOneWidget);
      expect(find.text(l10n.disk), findsNothing);
      expect(find.text(l10n.adminPercentUsed(0)), findsNothing);
    });

    testWidgets('a pending restart shows and Restart restarts', (tester) async {
      await pumpDashboard(tester, server: ServerType.emby);

      expect(find.text(l10n.adminRestartPending), findsOneWidget);
      await tester.tap(find.text(l10n.adminRestartServer));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.confirm));
      await tester.pumpAndSettle();
      expect(system.restarts, 1);
    });

    testWidgets('Restart hides when Emby can\'t restart itself', (
      tester,
    ) async {
      info.info = {..._embyInfo, 'CanSelfRestart': false};
      await pumpDashboard(tester, server: ServerType.emby);

      expect(find.text(l10n.adminRestartServer), findsNothing);
      expect(find.text(l10n.adminShutdownServer), findsOneWidget);
    });
  });

  testWidgets('Scan All Libraries starts the RefreshLibrary task', (
    tester,
  ) async {
    await pumpDashboard(tester);

    await tester.tap(find.text(l10n.adminScanAllLibraries));
    await tester.pumpAndSettle();
    expect(tasks.started, ['scan-id']);
  });

  testWidgets('Scan All Libraries is busy while that task runs', (
    tester,
  ) async {
    tasks.scanState = 'Running';
    await pumpDashboard(tester, settle: false);

    final button = tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text(l10n.adminScanAllLibraries),
        matching: find.bySubtype<ButtonStyleButton>(),
      ),
    );
    expect(button.onPressed, isNull);
  });

  group('session sheet', () {
    Future<void> pumpSheet(
      WidgetTester tester,
      Map<String, dynamic> session,
    ) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      sessions.sessions = [session];
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: SessionDetailSheet(session: session)),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a message goes out with TimeoutMs 5000', (tester) async {
      await pumpSheet(tester, _session('tv'));

      await tester.tap(find.text(l10n.adminSendMessage));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Server restarts soon');
      await tester.tap(find.text(l10n.send));
      await tester.pumpAndSettle();

      expect(sessions.messages, [('session-tv', 'Server restarts soon', 5000)]);
    });

    testWidgets('the home action says what it sends', (tester) async {
      await pumpSheet(tester, _session('tv'));

      await tester.tap(find.text(l10n.adminSessionGoHome));
      await tester.pumpAndSettle();
      expect(sessions.commands, [('session-tv', 'GoHome')]);
    });

    testWidgets('a session without remote control gets no controls', (
      tester,
    ) async {
      await pumpSheet(tester, _session('tv', remote: false));

      expect(find.text('Dune'), findsOneWidget);
      expect(find.text(l10n.adminSendMessage), findsNothing);
      expect(find.text(l10n.adminSessionGoHome), findsNothing);
      expect(find.text(l10n.stop), findsNothing);
    });
  });

  group('displayPlayMethod', () {
    Map<String, dynamic> playing(
      Map<String, dynamic>? transcoding, [
      String method = 'Transcode',
    ]) => {
      'NowPlayingItem': {'Name': 'Dune'},
      'PlayState': {'PlayMethod': method},
      'TranscodingInfo': ?transcoding,
    };

    test('nothing playing has no method', () {
      expect(displayPlayMethod(const {}), isNull);
    });

    test('direct video and audio is a remux', () {
      expect(
        displayPlayMethod(playing({'IsVideoDirect': true, 'IsAudioDirect': true})),
        'Remux',
      );
    });

    test('direct video with converted audio is a direct stream', () {
      expect(
        displayPlayMethod(playing({'IsVideoDirect': true, 'IsAudioDirect': false})),
        'DirectStream',
      );
    });

    test('converted video is a transcode', () {
      expect(
        displayPlayMethod(
          playing({'IsVideoDirect': false, 'VideoCodec': 'h264'}),
        ),
        'Transcode',
      );
    });

    test('a DirectStream play method shows as direct play', () {
      expect(displayPlayMethod(playing(null, 'DirectStream')), 'DirectPlay');
    });
  });
}
