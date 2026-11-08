import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonfin/data/services/tortugarr/tortugarr_plugin_client.dart';
import 'package:moonfin/ui/screens/admin/plugins/tortugarr_server_settings_screen.dart';
import 'package:server_core/server_core.dart';

class _MockClient extends Mock implements MediaServerClient {}

class _Adapter implements HttpClientAdapter {
  final List<RequestOptions> sent = [];
  Map<String, Object?> settings = {
    'SonarrUrl': 'http://sonarr:8989',
    'SonarrApiKeySet': true,
    'RadarrApiKeySet': false,
    'AdultEnabled': false,
    'MinMovieBytes': 700 * 1024 * 1024,
    'SpaceBufferBytes': 5 * 1024 * 1024 * 1024,
    'DownloadClientType': 'qbittorrent',
  };

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? _, Future<void>? __) async {
    sent.add(o);
    if (o.method == 'PUT') settings = {...settings, ...(o.data as Map).cast<String, Object?>()};
    return ResponseBody.fromString(jsonEncode(settings), 200, headers: {Headers.contentTypeHeader: ['application/json']});
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  testWidgets('shows the settings, keys as set or not, and saves a switch at once', (tester) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final client = _MockClient();
    when(() => client.baseUrl).thenReturn('http://lab:8096');
    when(() => client.accessToken).thenReturn('tok');
    when(() => client.deviceInfo).thenReturn(const DeviceInfo(id: 'd', name: 't', appName: 'Tortugarr', appVersion: '1'));
    final adapter = _Adapter();
    final plugin = TortugarrPluginClient(dio: Dio(BaseOptions(validateStatus: (_) => true))..httpClientAdapter = adapter, client: client);
    await tester.pumpWidget(MaterialApp(home: TortugarrServerSettingsScreen(client: plugin)));
    await tester.pumpAndSettle();

    expect(find.text('http://sonarr:8989'), findsOneWidget);
    expect(find.text('Set (hidden)'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('5 GB'), 300);
    expect(find.text('5 GB'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Adult library'), 300);
    await tester.tap(find.text('Adult library'));
    await tester.pumpAndSettle();
    final put = adapter.sent.lastWhere((o) => o.method == 'PUT');
    expect(put.data, {'AdultEnabled': true});

    await tester.scrollUntilVisible(find.text('700 MB'), 300);
    expect(find.text('700 MB'), findsOneWidget);
  });
}
