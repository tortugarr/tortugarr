library;

import 'package:flutter/material.dart';

const Color _defaultGlow = Color(0xFF4A5A78);

const Map<String, Color> _genreTones = <String, Color>{
  'horror': Color(0xFF8A0F1A), // crimson
  'thriller': Color(0xFF2E6FB0), // icy blue
  'mystery': Color(0xFF3B4E8C), // deep indigo
  'crime': Color(0xFF5A2B2B), // dried-blood maroon
  'sci-fi': Color(0xFFE0B23A), // starlight gold
  'science fiction': Color(0xFFE0B23A),
  'fantasy': Color(0xFF6A3FB0), // arcane violet
  'romance': Color(0xFFC85C8E), // rose
  'comedy': Color(0xFFE08A2E), // warm amber
  'animation': Color(0xFF2FA8A0), // playful teal
  'family': Color(0xFF3FA85C), // friendly green
  'documentary': Color(0xFF6E7A52), // muted olive
  'drama': Color(0xFF7A5230), // sepia
  'action': Color(0xFFC0451E), // ember orange
  'adventure': Color(0xFFB07A2E), // expedition bronze
  'war': Color(0xFF5C5A3E), // field khaki
  'western': Color(0xFF9A5A22), // desert clay
  'music': Color(0xFFB03F8A), // magenta
  'history': Color(0xFF8A6A3A), // parchment gold
  'kids': Color(0xFF3FA0C8), // sky blue
  'reality': Color(0xFFB0903A), // studio gold
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
