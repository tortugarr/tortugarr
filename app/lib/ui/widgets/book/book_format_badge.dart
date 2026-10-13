import 'package:flutter/material.dart';
import 'package:moonfin_design/moonfin_design.dart';

import '../../../l10n/app_localizations.dart';

/// Small glyph chip identifying a card as a book or an audiobook. Solid
/// scrim colors (no glass) so rows of cards stay cheap on TV GPUs.
class BookFormatBadge extends StatelessWidget {
  final bool isAudiobook;

  const BookFormatBadge({super.key, required this.isAudiobook});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      label: isAudiobook ? l10n.bookFormatAudiobook : l10n.bookFormatBook,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColorScheme.scrim.withValues(alpha: 0.72),
          borderRadius: AppRadius.circular(4),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          child: Icon(
            isAudiobook ? Icons.headphones_rounded : Icons.menu_book_rounded,
            size: 12,
            color: AppColorScheme.onBadge,
          ),
        ),
      ),
    );
  }
}

/// Compact text chip layered on a card image, e.g. "6h 12m left" on
/// audiobooks. Solid scrim background, theme badge foreground.
class BookProgressChip extends StatelessWidget {
  final String label;

  const BookProgressChip({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColorScheme.scrim.withValues(alpha: 0.78),
        borderRadius: AppRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          label,
          style: TextStyle(
            color: AppColorScheme.onBadge,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

/// Formats a duration as a short "6h 12m" / "42m" label for chips.
String formatBookDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes % 60;
  if (hours > 0) return '${hours}h ${minutes}m';
  return '${minutes}m';
}
