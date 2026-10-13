import 'package:flutter/material.dart';

const Color _defaultGlow = Color(0xFF4A5A78);

const Map<String, Color> _genreTones = <String, Color>{
  'horror': Color(0xFF8A0F1A),
  'thriller': Color(0xFF2E6FB0),
  'mystery': Color(0xFF3B4E8C),
  'crime': Color(0xFF5A2B2B),
  'sci-fi': Color(0xFFE0B23A),
  'science fiction': Color(0xFFE0B23A),
  'fantasy': Color(0xFF6A3FB0),
  'romance': Color(0xFFC85C8E),
  'comedy': Color(0xFFE08A2E),
  'animation': Color(0xFF2FA8A0),
  'family': Color(0xFF3FA85C),
  'documentary': Color(0xFF6E7A52),
  'drama': Color(0xFF7A5230),
  'action': Color(0xFFC0451E),
  'adventure': Color(0xFFB07A2E),
  'war': Color(0xFF5C5A3E),
  'western': Color(0xFF9A5A22),
  'music': Color(0xFFB03F8A),
  'history': Color(0xFF8A6A3A),
  'kids': Color(0xFF3FA0C8),
  'reality': Color(0xFFB0903A),
};

Color glowColorForGenres(List<String> genres) {
  for (final genre in genres) {
    final normalized = genre.trim().toLowerCase();
    if (normalized.isEmpty) continue;

    final exact = _genreTones[normalized];
    if (exact != null) return exact;

    for (final entry in _genreTones.entries) {
      if (normalized.contains(entry.key)) {
        return entry.value;
      }
    }
  }
  return _defaultGlow;
}
