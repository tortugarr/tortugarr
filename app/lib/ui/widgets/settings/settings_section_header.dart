import 'package:flutter/material.dart';

/// Section header above a group of settings. Public so both the side-panel
/// part files and the standalone settings screens share one header.
class SettingsSectionHeader extends StatelessWidget {
  final String text;

  const SettingsSectionHeader(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
