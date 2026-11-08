import 'package:flutter/material.dart';
import 'package:moonfin_design/moonfin_design.dart';

import '../../../l10n/app_localizations.dart';
import '../focus/focusable_wrapper.dart';

/// A book library section's See all, a D-pad stop in the section heading.
/// The section's items step Up onto it, Down goes back to them and Up again
/// moves on to the section above.
class BookSeeAllButton extends StatelessWidget {
  final VoidCallback onPressed;
  final FocusNode? focusNode;
  final VoidCallback? onNavigateUp;
  final VoidCallback? onNavigateDown;

  const BookSeeAllButton({
    super.key,
    required this.onPressed,
    this.focusNode,
    this.onNavigateUp,
    this.onNavigateDown,
  });

  @override
  Widget build(BuildContext context) {
    return FocusableWrapper(
      highlightOnHover: true,
      focusNode: focusNode,
      borderRadius: 16,
      autoScroll: true,
      disableScale: true,
      onSelect: onPressed,
      onNavigateUp: onNavigateUp,
      onNavigateDown: onNavigateDown,
      onNavigateLeft: () {},
      onNavigateRight: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          AppLocalizations.of(context).seeAll,
          style: TextStyle(
            fontSize: 13,
            color: AppColorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}
