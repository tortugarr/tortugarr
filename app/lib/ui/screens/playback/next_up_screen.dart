import 'package:flutter/material.dart';
import 'package:moonfin_design/moonfin_design.dart';

import '../../../l10n/app_localizations.dart';
import '../../widgets/focus/request_initial_focus.dart';

class NextUpScreen extends StatelessWidget {
  final String itemId;

  const NextUpScreen({super.key, required this.itemId});

  @override
  Widget build(BuildContext context) =>
      RequestInitialFocus(child: _buildContent(context));

  Widget _buildContent(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColorScheme.background,
      body: Center(
        child: Text(
          l10n.nextUp,
            style: TextStyle(color: AppColorScheme.onSurface, fontSize: 24),
        ),
      ),
    );
  }
}
