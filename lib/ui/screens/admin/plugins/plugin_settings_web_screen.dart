import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../../../util/webview_environment.dart';

/// A plugin's settings page from the server's own web client, inside the app
/// (2026-11-08). Before, it opened in the TV's browser, which asked first and
/// then had to be signed in by hand. The app's session goes into the page's
/// storage before the web client starts, so the page opens signed in.
class PluginSettingsWebScreen extends StatefulWidget {
  final String title;
  final Uri url;

  /// The web client's saved-server entry (jellyfin_credentials).
  final Map<String, dynamic> credentials;

  const PluginSettingsWebScreen({
    super.key,
    required this.title,
    required this.url,
    required this.credentials,
  });

  /// jellyfin-web's `jellyfin_credentials` for one server and user.
  static Map<String, dynamic> credentialsFor({
    required String serverAddress,
    required String serverId,
    required String userId,
    required String accessToken,
  }) =>
      {
        'Servers': [
          {
            'ManualAddress': serverAddress,
            'Id': serverId,
            'UserId': userId,
            'AccessToken': accessToken,
            'DateLastAccessed': DateTime.now().millisecondsSinceEpoch,
            'LastConnectionMode': 2,
          },
        ],
      };

  /// The script that puts the session in place before the web client reads it.
  static String signInScript(Map<String, dynamic> credentials) {
    final value = jsonEncode(jsonEncode(credentials));
    return 'try { localStorage.setItem("jellyfin_credentials", $value); } catch (e) {}';
  }

  @override
  State<PluginSettingsWebScreen> createState() => _PluginSettingsWebScreenState();
}

class _PluginSettingsWebScreenState extends State<PluginSettingsWebScreen> {
  InAppWebViewController? _web;
  bool _loading = true;

  Future<void> _back() async {
    final web = _web;
    if (web != null && await web.canGoBack()) {
      await web.goBack();
    } else if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _back),
        ),
        body: Stack(
          children: [
            InAppWebView(
              webViewEnvironment: gWebViewEnvironment,
              initialUrlRequest: URLRequest(url: WebUri.uri(widget.url)),
              initialUserScripts: UnmodifiableListView([
                UserScript(
                  source: PluginSettingsWebScreen.signInScript(widget.credentials),
                  injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                ),
              ]),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                domStorageEnabled: true,
                supportZoom: false,
                mediaPlaybackRequiresUserGesture: true,
              ),
              onWebViewCreated: (c) => _web = c,
              onLoadStop: (_, _) {
                if (mounted && _loading) setState(() => _loading = false);
              },
              onReceivedError: (_, _, _) {
                if (mounted && _loading) setState(() => _loading = false);
              },
            ),
            if (_loading) const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}

