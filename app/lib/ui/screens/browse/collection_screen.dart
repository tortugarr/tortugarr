import 'package:flutter/material.dart';
import 'package:moonfin_design/moonfin_design.dart';

import '../../../l10n/app_localizations.dart';
import '../../widgets/focus/request_initial_focus.dart';
import '../../widgets/navigation_layout.dart';

class CollectionScreen extends StatelessWidget {
  final String collectionId;

  const CollectionScreen({super.key, required this.collectionId});

  @override
  Widget build(BuildContext context) => RequestInitialFocus(
        child: Scaffold(
          backgroundColor: AppColorScheme.background,
          body: NavigationLayout(
            showBackButton: true,
            child: Center(
              child: Text(AppLocalizations.of(context).collectionPlaceholder),
            ),
          ),
        ),
      );
}
