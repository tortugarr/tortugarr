import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../widgets/focus/request_initial_focus.dart';

class ItemListScreen extends StatelessWidget {
  final String itemId;

  const ItemListScreen({super.key, required this.itemId});

  @override
  Widget build(BuildContext context) =>
      RequestInitialFocus(child: _buildContent(context));

  Widget _buildContent(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.trackList)),
      body: Center(child: Text(l10n.itemListPlaceholder)),
    );
  }
}
