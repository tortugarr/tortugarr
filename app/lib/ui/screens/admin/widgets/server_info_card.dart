import 'package:flutter/material.dart';
import 'package:moonfin_design/moonfin_design.dart';

import '../../../../l10n/app_localizations.dart';
import 'admin_form_styles.dart';

class ServerInfoCard extends StatelessWidget {
  final Map<String, dynamic> systemInfo;

  const ServerInfoCard({super.key, required this.systemInfo});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final os = _value(
      systemInfo,
      const ['OperatingSystemDisplayName', 'OperatingSystem'],
      fallback: l10n.unknown,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        adminSectionLabel(context, l10n.adminServerInfo, icon: Icons.dns),
        adminGlassGroup(
          context,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.spaceLg,
                vertical: AppSpacing.spaceMd,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _row(l10n.name, systemInfo['ServerName'] as String? ?? ''),
                  _row(l10n.version, systemInfo['Version'] as String? ?? ''),
                  _row(l10n.os, os),
                  if (systemInfo['HasPendingRestart'] == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Chip(
                        avatar: Icon(Icons.warning,
                            size: 16, color: theme.colorScheme.error),
                        label: Text(l10n.adminRestartPending),
                        backgroundColor: theme.colorScheme.errorContainer,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _value(
    Map<String, dynamic> source,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final raw = source[key];
      final text = (raw ?? '').toString().trim();
      if (text.isNotEmpty) {
        return text;
      }
    }
    return fallback;
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          Expanded(child: Text(value, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}
