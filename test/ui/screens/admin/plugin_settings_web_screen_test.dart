import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/ui/screens/admin/plugins/plugin_settings_web_screen.dart';

/// 2026-11-08: plugin settings open inside the app, signed in.
void main() {
  test('the web client gets this server and user, signed in', () {
    final c = PluginSettingsWebScreen.credentialsFor(
      serverAddress: 'http://192.168.1.15:8096',
      serverId: 'abc',
      userId: 'u1',
      accessToken: 'tok',
    );
    final server = (c['Servers'] as List).single as Map;
    expect(server['ManualAddress'], 'http://192.168.1.15:8096');
    expect(server['Id'], 'abc');
    expect(server['UserId'], 'u1');
    expect(server['AccessToken'], 'tok');
  });

  test('the sign-in script stores the credentials as a JSON string', () {
    final c = {'Servers': [{'AccessToken': 'a"b'}]};
    final script = PluginSettingsWebScreen.signInScript(c);
    expect(script, contains('localStorage.setItem("jellyfin_credentials", '));
    final literal = script.substring(script.indexOf(', ') + 2, script.lastIndexOf(');'));
    expect(jsonDecode(jsonDecode(literal) as String), c);
  });
}
