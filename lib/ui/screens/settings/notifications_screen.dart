import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/services/tortugarr/tortugarr_plugin_client.dart';
import '../../../util/app_l10n.dart';
import '../../../util/platform_detection.dart';
import 'settings_app_bar.dart';

/// Phone notifications (G, 2026-11-08): the user's secret ntfy topic as a QR
/// code and link, what they want to hear about, and a test message. The
/// server's ntfy sends "ready to watch" and, to administrators, the problems
/// Tortugarr dealt with.
class NotificationsScreen extends StatefulWidget {
  /// Injectable for tests; defaults to the plugin.
  final TortugarrPluginClient? client;

  const NotificationsScreen({super.key, this.client});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final TortugarrPluginClient _plugin = widget.client ?? TortugarrPluginClient();
  Map<String, dynamic>? _me;
  bool _failed = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final me = await _plugin.myNotifications();
      if (mounted) setState(() => _me = me);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _set({bool? ready, bool? problems, bool? everything}) async {
    try {
      final me = await _plugin.setMyNotifications(ready: ready, problems: problems, everything: everything);
      if (mounted) setState(() => _me = me);
    } catch (_) {
      _snack(appL10n().tgNotifySaveFailed);
    }
  }

  Future<void> _test() async {
    setState(() => _sending = true);
    try {
      await _plugin.testNotification();
      _snack(appL10n().tgNotifyTestSent);
    } catch (_) {
      _snack(appL10n().tgNotifyTestFailed);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = appL10n();
    final theme = Theme.of(context);
    final me = _me;
    return Scaffold(
      appBar: buildSettingsAppBar(context, Text(l10n.tgNotifyTitle)),
      body: me == null
          ? Center(
              child: _failed
                  ? Text(l10n.tgNotifyUnavailable)
                  : const CircularProgressIndicator(),
            )
          : me['available'] != true
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(l10n.tgNotifyNotSetUp)))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [
                    Text(l10n.tgNotifyIntro, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 24,
                      runSpacing: 16,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          color: Colors.white,
                          child: QrImageView(
                            data: '${me['appUrl'] ?? me['subscribeUrl']}',
                            version: QrVersions.auto,
                            size: 180,
                          ),
                        ),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l10n.tgNotifyStep1),
                              const SizedBox(height: 6),
                              Text(l10n.tgNotifyStep2),
                              const SizedBox(height: 6),
                              Text(l10n.tgNotifyStep3),
                              const SizedBox(height: 12),
                              SelectableText('${l10n.tgNotifyServer}: ${me['server']}'),
                              SelectableText('${l10n.tgNotifyTopic}: ${me['topic']}'),
                              if (PlatformDetection.isMobile) ...[
                                const SizedBox(height: 12),
                                FilledButton.tonalIcon(
                                  onPressed: () => unawaited(launchUrl(
                                    Uri.parse('${me['appUrl']}'),
                                    mode: LaunchMode.externalApplication,
                                  )),
                                  icon: const Icon(Icons.open_in_new),
                                  label: Text(l10n.tgNotifyOpenApp),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SwitchListTile(
                      autofocus: true,
                      secondary: const Icon(Icons.check_circle_outline),
                      title: Text(l10n.tgNotifyReady),
                      subtitle: Text(l10n.tgNotifyReadySubtitle),
                      value: me['ready'] == true,
                      onChanged: (v) => unawaited(_set(ready: v)),
                    ),
                    if (me['isAdmin'] == true) ...[
                      SwitchListTile(
                        secondary: const Icon(Icons.warning_amber_rounded),
                        title: Text(l10n.tgNotifyProblems),
                        subtitle: Text(l10n.tgNotifyProblemsSubtitle),
                        value: me['problems'] == true,
                        onChanged: (v) => unawaited(_set(problems: v)),
                      ),
                      SwitchListTile(
                        secondary: const Icon(Icons.groups_outlined),
                        title: Text(l10n.tgNotifyEverything),
                        subtitle: Text(l10n.tgNotifyEverythingSubtitle),
                        value: me['everything'] == true,
                        onChanged: (v) => unawaited(_set(everything: v)),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                        onPressed: _sending ? null : () => unawaited(_test()),
                        icon: const Icon(Icons.notifications_active_outlined),
                        label: Text(l10n.tgNotifyTest),
                      ),
                    ),
                  ],
                ),
    );
  }
}
