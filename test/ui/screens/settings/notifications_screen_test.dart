import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonfin/data/services/tortugarr/tortugarr_plugin_client.dart';
import 'package:moonfin/l10n/app_localizations.dart';
import 'package:moonfin/ui/screens/settings/notifications_screen.dart';
import 'package:server_core/server_core.dart';

class _MockClient extends Mock implements MediaServerClient {}

class _Adapter implements HttpClientAdapter {
  final Map<String, Object?>? Function(RequestOptions) answer;
  final List<RequestOptions> sent = [];
  _Adapter(this.answer);

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? _, Future<void>? __) async {
    sent.add(o);
    final body = answer(o);
    return ResponseBody.fromString(body == null ? '' : jsonEncode(body), body == null ? 204 : 200,
        headers: {Headers.contentTypeHeader: ['application/json']});
  }

  @override
  void close({bool force = false}) {}
}

Map<String, Object?> _me({bool isAdmin = true, bool ready = true}) => {
      'available': true,
      'server': 'http://192.168.1.15:8099',
      'topic': 'tortugarr-abc',
      'subscribeUrl': 'http://192.168.1.15:8099/tortugarr-abc',
      'appUrl': 'ntfy://192.168.1.15:8099/tortugarr-abc?secure=false',
      'ready': ready,
      'problems': isAdmin,
      'everything': false,
      'isAdmin': isAdmin,
    };

Future<_Adapter> _pump(WidgetTester tester, Map<String, Object?>? Function(RequestOptions) answer) async {
  tester.view.physicalSize = const Size(1280, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final client = _MockClient();
  when(() => client.baseUrl).thenReturn('http://lab:8096');
  when(() => client.accessToken).thenReturn('tok');
  when(() => client.deviceInfo).thenReturn(const DeviceInfo(id: 'd', name: 't', appName: 'Tortugarr', appVersion: '1'));
  final adapter = _Adapter(answer);
  final plugin = TortugarrPluginClient(dio: Dio(BaseOptions(validateStatus: (_) => true))..httpClientAdapter = adapter, client: client);
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: NotificationsScreen(client: plugin),
  ));
  await tester.pumpAndSettle();
  return adapter;
}

void main() {
  testWidgets('shows server, topic and the admin switches; a switch saves', (tester) async {
    final adapter = await _pump(tester, (o) => o.method == 'POST' ? null : _me(ready: o.method == 'PUT' ? false : true));
    expect(find.text('Server: http://192.168.1.15:8099'), findsOneWidget);
    expect(find.text('Topic: tortugarr-abc'), findsOneWidget);
    expect(find.text('Problems Tortugarr dealt with'), findsOneWidget);
    await tester.tap(find.text('Ready to watch'));
    await tester.pumpAndSettle();
    final put = adapter.sent.lastWhere((o) => o.method == 'PUT');
    expect(put.data, {'ready': false});
    await tester.tap(find.text('Send test'));
    await tester.pumpAndSettle();
    expect(adapter.sent.any((o) => o.method == 'POST' && o.uri.path.endsWith('/Notifications/Test')), isTrue);
    expect(find.text('Test sent. Check your phone.'), findsOneWidget);
  });

  testWidgets('a regular user sees no admin switches', (tester) async {
    await _pump(tester, (_) => _me(isAdmin: false));
    expect(find.text('Ready to watch'), findsOneWidget);
    expect(find.text('Problems Tortugarr dealt with'), findsNothing);
  });

  testWidgets('a server without ntfy says so', (tester) async {
    await _pump(tester, (_) => {'available': false});
    expect(find.textContaining('not set up on the server'), findsOneWidget);
  });
}
