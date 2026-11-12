import 'package:flutter/material.dart';

import '../theme_spec.dart';

/// Tortugarr's own theme: a harbour tavern at night. Dark wood surfaces,
/// parchment text, brass accents, a pirate display face for headings only
/// (body text stays in the default font so it reads from the sofa), and a
/// warm lantern glow around the focused card. Kept cheap for weak TVs: no
/// glass/blur, one soft shadow on the focused item only.
const tortugaThemeSpec = ThemeSpec(
  id: 'tortuga',
  displayName: 'Tortuga',
  headingFontFamily: 'TortugaHeading',
  cardFocusGlow: true,
  // Warm lamp-lit cast over the home backdrop instead of the cool default.
  backdropTint: Color(0x8C24150A),
  navSurface: Color(0xFF2A1C10),
  semantic: ThemeSemanticTokens(
    statusAvailable: Color(0xFF6F9A4A),
    statusRequested: Color(0xFF8A5A9E),
    statusPending: Color(0xFFD9B44A),
    statusDownloading: Color(0xFF6FB3A8),
    statusError: Color(0xFFC0452F),
    mediaTypeBadgeMovie: Color(0xFF3E6B78),
    mediaTypeBadgeShow: Color(0xFF8B4A2E),
  ),
  colors: ThemeColorTokens(
    background: Color(0xFF14100C),
    onBackground: Color(0xFFEADBC0),
    surface: Color(0xFF1F1812),
    onSurface: Color(0xFFEADBC0),
    surfaceVariant: Color(0xFF3A2E1E),
    scrim: Color(0xCC14100C),
    accent: Color(0xFFD9B44A),
    onAccent: Color(0xFF14100C),
    buttonNormal: Color(0xFF2A2117),
    buttonFocused: Color(0xFFD9B44A),
    buttonDisabled: Color(0xFF1F1812),
    buttonActive: Color(0xFFC7783A),
    onButtonNormal: Color(0xFFEADBC0),
    onButtonFocused: Color(0xFF14100C),
    onButtonDisabled: Color(0xFF6E5E46),
    inputBackground: Color(0xFF1F1812),
    inputFocused: Color(0xFF2A2117),
    inputBorder: Color(0xFF5A4A30),
    inputBorderFocused: Color(0xFFD9B44A),
    rangeTrack: Color(0xFF3A2E1E),
    rangeProgress: Color(0xFFD9B44A),
    rangeThumb: Color(0xFFF0CF6A),
    seekbarBuffered: Color(0xFF6E5E46),
    badgeBackground: Color(0xFF8B2E1F),
    onBadge: Color(0xFFF4E9D4),
    badgeUnplayed: Color(0xFFC7783A),
    badgeWatched: Color(0xFF6F9A4A),
    recordingActive: Color(0xFFC0452F),
    recordingScheduled: Color(0xFFD9B44A),
    error: Color(0xFFC0452F),
  ),
  borders: ThemeBorderTokens(
    cardBorder: BorderSide(color: Color(0x1FEADBC0)),
    chipBorder: BorderSide(color: Color(0xFF5A4A30)),
    focusBorder: BorderSide(color: Color(0xFFD9B44A), width: 2.5),
    cardRadius: BorderRadius.all(Radius.circular(6)),
    chipRadius: BorderRadius.all(Radius.circular(16)),
    chipBackground: Color(0xFF2A2117),
    navBorder: BorderSide(color: Color(0xFF2A2117)),
    focusGlow: [
      BoxShadow(
        color: Color(0x80FFB84D),
        blurRadius: 22,
        spreadRadius: 3,
      ),
    ],
  ),
);
