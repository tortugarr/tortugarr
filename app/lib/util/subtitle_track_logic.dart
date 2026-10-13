import 'dart:ui' as ui;
import '../preference/preference_constants.dart';
import 'language_matching.dart';

bool isExternalSubtitleStream(Map<String, dynamic> stream) {
  if (stream['IsExternal'] == true) {
    return true;
  }
  final deliveryMethod =
      (stream['DeliveryMethod'] as String?)?.trim().toLowerCase();
  return deliveryMethod == 'external';
}

bool isSdhSubtitleStream(Map<String, dynamic> stream) {
  if (stream['IsHearingImpaired'] == true) return true;
  final titleParts = [
    stream['DisplayTitle'] as String?,
    stream['Title'] as String?,
    stream['Name'] as String?,
  ].whereType<String>().map((s) => s.toLowerCase()).join(' ');
  return RegExp(
    r'\b(sdh|cc|hoh|hearing\s*impaired|closed\s*caption)\b',
  ).hasMatch(titleParts);
}

bool isSpecialSubtitleStream(Map<String, dynamic> stream) {
  if (stream['IsCommentary'] == true) return true;
  final titleParts = [
    stream['DisplayTitle'] as String?,
    stream['Title'] as String?,
    stream['Name'] as String?,
  ].whereType<String>().map((s) => s.toLowerCase()).join(' ');
  return RegExp(
    r'\b(commentary|commentaries|jump\s*scare)\b',
  ).hasMatch(titleParts);
}

bool shouldRenderSubtitleNatively(String? codec) {
  if (codec == null) return false;
  final normalized = codec.trim().toLowerCase();
  return normalized == 'ass' ||
      normalized == 'ssa' ||
      normalized == 'pgs' ||
      normalized == 'pgssub' ||
      normalized == 'hdmv_pgs_subtitle' ||
      normalized == 'dvdsub' ||
      normalized == 'vobsub' ||
      normalized == 'dvd_subtitle' ||
      normalized == 'dvbsub' ||
      normalized == 'dvb_subtitle' ||
      normalized == 'xsub';
}

/// Internal streams first, external streams last.
List<Map<String, dynamic>> sortedSubtitleStreams(
  List<Map<String, dynamic>> streams,
) {
  final internal =
      streams.where((s) => !isExternalSubtitleStream(s)).toList(growable: false);
  final external =
      streams.where(isExternalSubtitleStream).toList(growable: false);
  return [...internal, ...external];
}

/// Determines which stream index should be active given current state and prefs.
/// Returns -1 for explicit "none", null to fall back to the IsDefault flag.
int? computeEffectiveSubtitleIndex({
  required List<Map<String, dynamic>> subtitleStreams,
  required int? selectedSubtitleIndex,
  required int? activePlaybackSubtitleIndex,
  required SubtitleMode subtitleMode,
  required String preferredLanguage,
  required String fallbackLanguage,
  required bool preferSdh,
  required bool pgsDirectPlay,
  required bool assDirectPlay,
  required String preferredAudioLanguage,
  required String? activeAudioLanguage,
}) {
  bool matchLang(String? streamLang, String targetLang) {
    final targetNormalized = normalizeLanguage(targetLang);
    if (targetNormalized.isEmpty || targetNormalized == 'none') {
      return false;
    }
    final targetIso3 = toIso3Language(targetNormalized);
    return languageMatchesPreferred(streamLang, targetNormalized, targetIso3);
  }

  if (selectedSubtitleIndex != null) return selectedSubtitleIndex;
  if (activePlaybackSubtitleIndex != null) return activePlaybackSubtitleIndex;

  if (subtitleMode == SubtitleMode.none) {
    return -1;
  }

  if (subtitleMode == SubtitleMode.foreign) {
    final activeAudio = activeAudioLanguage ?? '';
    final preferredAudio = preferredAudioLanguage.trim();
    
    bool isAudioNative;
    if (preferredAudio.isNotEmpty && preferredAudio != 'auto') {
      final preferredNormalized = normalizeLanguage(preferredAudio);
      final preferredIso3 = toIso3Language(preferredNormalized);
      final activeNormalized = normalizeLanguage(activeAudio);
      final activeIso3 = toIso3Language(activeNormalized);
      isAudioNative = (preferredIso3 == activeIso3);
    } else {
      final sysLang = ui.PlatformDispatcher.instance.locale.languageCode;
      final sysNormalized = normalizeLanguage(sysLang);
      final sysIso3 = toIso3Language(sysNormalized);
      final activeNormalized = normalizeLanguage(activeAudio);
      final activeIso3 = toIso3Language(activeNormalized);
      isAudioNative = (sysIso3 == activeIso3);
    }
    
    if (isAudioNative) {
      return -1;
    }
  }

  // Check if primary (preferred) or secondary (fallback) languages are available in the streams
  final isPrimaryAvailable = preferredLanguage.isNotEmpty &&
      preferredLanguage != 'none' &&
      subtitleStreams.any((s) => matchLang(s['Language'], preferredLanguage));
  final isSecondaryAvailable = fallbackLanguage.isNotEmpty &&
      fallbackLanguage != 'none' &&
      subtitleStreams.any((s) => matchLang(s['Language'], fallbackLanguage));

  final bothUnavailable = !isPrimaryAvailable && !isSecondaryAvailable;

  final candidates = <Map<String, dynamic>>[];
  for (final stream in subtitleStreams) {
    if (stream['Index'] == null) continue;
    if (subtitleMode == SubtitleMode.forced) {
      if (stream['IsForced'] == true) {
        candidates.add(stream);
      }
    } else if (subtitleMode == SubtitleMode.flagged) {
      if (stream['IsDefault'] == true ||
          stream['IsForced'] == true ||
          (bothUnavailable && matchLang(stream['Language'], 'eng'))) {
        candidates.add(stream);
      }
    } else {
      candidates.add(stream);
    }
  }

  if (candidates.isEmpty) {
    return -1;
  }

  int getFormatPriority(Map<String, dynamic> stream) {
    final codec = (stream['Codec'] as String?)?.trim().toLowerCase() ?? '';
    final isPgs = codec == 'pgs' || codec == 'pgssub' || codec == 'hdmv_pgs_subtitle' || codec == 'dvdsub' || codec == 'vobsub';
    final isAss = codec == 'ass' || codec == 'ssa';
    
    if (isPgs && pgsDirectPlay) return 2;
    if (isAss && assDirectPlay) return 1;
    return 0;
  }

  final candidatesWithIndex = candidates.map((stream) {
    final originalIndex = subtitleStreams.indexOf(stream);
    return (stream: stream, originalIndex: originalIndex);
  }).toList();

  candidatesWithIndex.sort((a, b) {
    final streamA = a.stream;
    final streamB = b.stream;

    // 1. Language matching: Preferred > Fallback > Others
    final aPrefMatch = matchLang(streamA['Language'], preferredLanguage);
    final bPrefMatch = matchLang(streamB['Language'], preferredLanguage);
    if (aPrefMatch != bPrefMatch) {
      return aPrefMatch ? -1 : 1;
    }

    final aFallMatch = matchLang(streamA['Language'], fallbackLanguage);
    final bFallMatch = matchLang(streamB['Language'], fallbackLanguage);
    if (aFallMatch != bFallMatch) {
      return aFallMatch ? -1 : 1;
    }

    // 1.5. English fallback: if preferred and fallback are not found, prefer English
    final aEngMatch = matchLang(streamA['Language'], 'eng');
    final bEngMatch = matchLang(streamB['Language'], 'eng');
    if (aEngMatch != bEngMatch) {
      return aEngMatch ? -1 : 1;
    }

    // 1.6. Push commentary and warning tracks below normal dialogue
    final aSpecial = isSpecialSubtitleStream(streamA);
    final bSpecial = isSpecialSubtitleStream(streamB);
    if (aSpecial != bSpecial) {
      return aSpecial ? 1 : -1;
    }

    // 2 and 3. SDH match and internal vs external, ordered by preferSdh. With SDH
    // on we match SDH first, with it off we keep internal tracks first so a bad
    // external download cannot beat an internal SDH track.
    if (preferSdh) {
      final aSdhMatch = isSdhSubtitleStream(streamA) == preferSdh;
      final bSdhMatch = isSdhSubtitleStream(streamB) == preferSdh;
      if (aSdhMatch != bSdhMatch) {
        return aSdhMatch ? -1 : 1;
      }

      final aInternal = !isExternalSubtitleStream(streamA);
      final bInternal = !isExternalSubtitleStream(streamB);
      if (aInternal != bInternal) {
        return aInternal ? -1 : 1;
      }
    } else {
      final aInternal = !isExternalSubtitleStream(streamA);
      final bInternal = !isExternalSubtitleStream(streamB);
      if (aInternal != bInternal) {
        return aInternal ? -1 : 1;
      }

      final aSdhMatch = isSdhSubtitleStream(streamA) == preferSdh;
      final bSdhMatch = isSdhSubtitleStream(streamB) == preferSdh;
      if (aSdhMatch != bSdhMatch) {
        return aSdhMatch ? -1 : 1;
      }
    }

    // 4. Fancy vs Normal
    final aFormat = getFormatPriority(streamA);
    final bFormat = getFormatPriority(streamB);
    if (aFormat != bFormat) {
      return aFormat > bFormat ? -1 : 1;
    }

    // 5. Forced flag (prefer non-forced for full subtitles, prefer forced for SubtitleMode.forced)
    final aForced = streamA['IsForced'] == true;
    final bForced = streamB['IsForced'] == true;
    if (aForced != bForced) {
      if (subtitleMode == SubtitleMode.forced) {
        return aForced ? -1 : 1;
      } else {
        return aForced ? 1 : -1;
      }
    }

    // 6. Default flag
    final aDefault = streamA['IsDefault'] == true;
    final bDefault = streamB['IsDefault'] == true;
    if (aDefault != bDefault) {
      return aDefault ? -1 : 1;
    }

    // 7. Tie-breaker: earlier stream index in the media container (smaller originalIndex is preferred)
    return a.originalIndex.compareTo(b.originalIndex);
  });

  return candidatesWithIndex.first.stream['Index'] as int?;
}

/// Maps the effective stream index to the dialog's 0-based option index,
/// where 0 is the "None" row and 1+ are stream rows.
int computeSubtitleDialogSelectedIndex(
  List<Map<String, dynamic>> displayStreams,
  int? effectiveSubtitleIndex,
) {
  if (effectiveSubtitleIndex != null) {
    if (effectiveSubtitleIndex == -1) return 0;
    final idx =
        displayStreams.indexWhere((s) => s['Index'] == effectiveSubtitleIndex);
    return idx == -1 ? 0 : idx + 1;
  }
  return displayStreams.indexWhere((s) => s['IsDefault'] == true) + 1;
}

/// Where a row of a subtitle menu points when the menu offers both the
/// server's subtitle streams and the captions the player found inside the
/// video. Row 0 is off, the streams follow, and the captions come last so
/// their arrival part way through a channel can't renumber the streams a
/// viewer already picked from.
///
/// Both positions are null for the off row and for a row past the end.
({int? streamPosition, int? captionPosition}) subtitleMenuRowTarget({
  required int row,
  required int streamCount,
  required int captionCount,
}) {
  if (row <= 0) return (streamPosition: null, captionPosition: null);
  if (row <= streamCount) {
    return (streamPosition: row - 1, captionPosition: null);
  }
  final captionPosition = row - streamCount - 1;
  if (captionPosition >= captionCount) {
    return (streamPosition: null, captionPosition: null);
  }
  return (streamPosition: null, captionPosition: captionPosition);
}

/// The row to mark as selected, given whichever of the two is active. A
/// caption wins when both are set, since selecting one turns the other off.
int subtitleMenuSelectedRow({
  required int streamPosition,
  required int captionPosition,
  required int streamCount,
}) {
  if (captionPosition >= 0) return streamCount + captionPosition + 1;
  if (streamPosition >= 0) return streamPosition + 1;
  return 0;
}

/// Maps a dialog result back to a stream index for state storage.
/// Returns -1 when the user selected "None" (result == 0).
int? mapSubtitleResultToStreamIndex(
  int result,
  List<Map<String, dynamic>> displayStreams,
) {
  if (result == 0) return -1;
  final streamPosition = result - 1;
  if (streamPosition >= 0 && streamPosition < displayStreams.length) {
    return displayStreams[streamPosition]['Index'] as int?;
  }
  return null;
}

/// A language the user can pick for the subtitle menus. [codes] are the
/// ISO 639 tags a track may carry, [names] the full names some files use.
class SubtitleMenuLanguage {
  const SubtitleMenuLanguage(this.code, this.endonym, this.codes, this.names);

  /// ISO 639-2 code stored in the preference.
  final String code;

  /// The language's own name, shown in the picker without translation.
  final String endonym;
  final Set<String> codes;
  final List<String> names;
}

/// The languages offered in Settings > Subtitle languages, in picker order.
const subtitleMenuLanguages = <SubtitleMenuLanguage>[
  SubtitleMenuLanguage('eng', 'English', {'eng', 'en'}, ['english', 'engelsk']),
  SubtitleMenuLanguage('nor', 'Norsk', {'nor', 'nob', 'nno', 'no', 'nb', 'nn'},
      ['norwegian', 'norsk', 'bokmal', 'bokmål', 'nynorsk']),
  SubtitleMenuLanguage('swe', 'Svenska', {'swe', 'sv'}, ['swedish', 'svenska', 'svensk']),
  SubtitleMenuLanguage('dan', 'Dansk', {'dan', 'da'}, ['danish', 'dansk']),
  SubtitleMenuLanguage('ger', 'Deutsch', {'ger', 'deu', 'de'}, ['german', 'deutsch', 'tysk']),
  SubtitleMenuLanguage('fre', 'Français', {'fre', 'fra', 'fr'},
      ['french', 'français', 'francais', 'fransk']),
  SubtitleMenuLanguage('spa', 'Español', {'spa', 'es'}, ['spanish', 'español', 'espanol', 'spansk']),
  SubtitleMenuLanguage('ita', 'Italiano', {'ita', 'it'}, ['italian', 'italiano', 'italiensk']),
  SubtitleMenuLanguage('dut', 'Nederlands', {'dut', 'nld', 'nl'},
      ['dutch', 'nederlands', 'nederlandsk']),
  SubtitleMenuLanguage('fin', 'Suomi', {'fin', 'fi'}, ['finnish', 'suomi', 'finsk']),
  SubtitleMenuLanguage('por', 'Português', {'por', 'pt'},
      ['portuguese', 'português', 'portugues', 'portugisisk']),
  SubtitleMenuLanguage('pol', 'Polski', {'pol', 'pl'}, ['polish', 'polski', 'polsk']),
];

/// Settings > Languages in Trending and Popular: the subtitle languages plus
/// the big non-European film and TV languages, so anyone can choose to keep
/// (for example) Japanese for anime. Only ISO 639-1 codes matter here: TMDB
/// tags titles with them (Cantonese is "cn" on TMDB).
const discoveryMenuLanguages = <SubtitleMenuLanguage>[
  ...subtitleMenuLanguages,
  SubtitleMenuLanguage('ice', 'Íslenska · Icelandic', {'ice', 'isl', 'is'}, ['icelandic']),
  SubtitleMenuLanguage('cze', 'Čeština · Czech', {'cze', 'ces', 'cs'}, ['czech']),
  SubtitleMenuLanguage('hun', 'Magyar · Hungarian', {'hun', 'hu'}, ['hungarian']),
  SubtitleMenuLanguage('rum', 'Română · Romanian', {'rum', 'ron', 'ro'}, ['romanian']),
  SubtitleMenuLanguage('gre', 'Ελληνικά · Greek', {'gre', 'ell', 'el'}, ['greek']),
  SubtitleMenuLanguage('tur', 'Türkçe · Turkish', {'tur', 'tr'}, ['turkish']),
  SubtitleMenuLanguage('rus', 'Русский · Russian', {'rus', 'ru'}, ['russian']),
  SubtitleMenuLanguage('ukr', 'Українська · Ukrainian', {'ukr', 'uk'}, ['ukrainian']),
  SubtitleMenuLanguage('jpn', '日本語 · Japanese (anime)', {'jpn', 'ja'}, ['japanese']),
  SubtitleMenuLanguage('kor', '한국어 · Korean', {'kor', 'ko'}, ['korean']),
  SubtitleMenuLanguage('chi', '中文 · Chinese (Mandarin)', {'chi', 'zho', 'zh'}, ['chinese', 'mandarin']),
  SubtitleMenuLanguage('yue', '粵語 · Cantonese', {'yue', 'cn'}, ['cantonese']),
  SubtitleMenuLanguage('tha', 'ไทย · Thai', {'tha', 'th'}, ['thai']),
  SubtitleMenuLanguage('vie', 'Tiếng Việt · Vietnamese', {'vie', 'vi'}, ['vietnamese']),
  SubtitleMenuLanguage('ind', 'Bahasa Indonesia · Indonesian', {'ind', 'id'}, ['indonesian']),
  SubtitleMenuLanguage('tgl', 'Tagalog · Filipino', {'tgl', 'fil', 'tl'}, ['tagalog', 'filipino']),
  SubtitleMenuLanguage('hin', 'हिन्दी · Hindi', {'hin', 'hi'}, ['hindi']),
  SubtitleMenuLanguage('tam', 'தமிழ் · Tamil', {'tam', 'ta'}, ['tamil']),
  SubtitleMenuLanguage('tel', 'తెలుగు · Telugu', {'tel', 'te'}, ['telugu']),
  SubtitleMenuLanguage('mal', 'മലയാളം · Malayalam', {'mal', 'ml'}, ['malayalam']),
  SubtitleMenuLanguage('kan', 'ಕನ್ನಡ · Kannada', {'kan', 'kn'}, ['kannada']),
  SubtitleMenuLanguage('ara', 'العربية · Arabic', {'ara', 'ar'}, ['arabic']),
  SubtitleMenuLanguage('heb', 'עברית · Hebrew', {'heb', 'he'}, ['hebrew']),
  SubtitleMenuLanguage('per', 'فارسی · Persian', {'per', 'fas', 'fa'}, ['persian', 'farsi']),
];

/// Picked by default: Norwegian and English.
const defaultSubtitleMenuLanguageCodes = <String>{'nor', 'eng'};

/// Picked by default for Settings > Languages in Trending and Popular:
/// English, Norwegian, Swedish, Danish, German and French.
const defaultDiscoveryLanguageCodes = <String>{
  'eng', 'nor', 'swe', 'dan', 'ger', 'fre',
};

/// TMDB original_language codes (ISO 639-1) for languages picked from
/// [languages] (stored as ISO 639-2 codes).
Set<String> tmdbCodesFor(
  Set<String> picked, {
  List<SubtitleMenuLanguage> languages = subtitleMenuLanguages,
}) => {
  for (final language in languages)
    if (picked.contains(language.code))
      ...language.codes.where((c) => c.length == 2),
};

/// True when [stream] belongs in the short subtitle menu: a track in one of
/// the [languages] the user picked (ISO 639-2 codes from
/// [subtitleMenuLanguages]), or one whose language is unknown (it may well be
/// one of them). Forced tracks get no special treatment.
bool isMenuLanguageSubtitleStream(
  Map<String, dynamic> stream, {
  Set<String> languages = defaultSubtitleMenuLanguageCodes,
}) {
  final language = (stream['Language'] as String?)?.trim().toLowerCase() ?? '';
  // No language tag: keep it whatever the title says, it may well be one of
  // the picked languages.
  if (language.isEmpty || language == 'und') return true;
  for (final candidate in subtitleMenuLanguages) {
    if (candidate.codes.contains(language)) {
      return languages.contains(candidate.code);
    }
  }
  // Some files carry a full name instead of an ISO code.
  if (language.length > 3) {
    for (final candidate in subtitleMenuLanguages) {
      if (!languages.contains(candidate.code)) continue;
      if (candidate.names.any(language.contains)) return true;
    }
  }
  return false;
}

/// The subtitle streams a menu should list. With [showAll] off only tracks in
/// the picked [languages] and unknown-language tracks are kept. A track in
/// another language is not listed even when it is the one playing (the player
/// switches such auto-selected tracks off, see [shouldAutoDisableSubtitle]).
/// If anything goes wrong every stream is returned.
List<Map<String, dynamic>> filterSubtitleMenuStreams(
  List<Map<String, dynamic>> streams, {
  required bool showAll,
  Set<String> languages = defaultSubtitleMenuLanguageCodes,
}) {
  if (showAll || streams.isEmpty) return streams;
  try {
    return streams
        .where((s) => isMenuLanguageSubtitleStream(s, languages: languages))
        .toList(growable: false);
  } catch (_) {
    return streams;
  }
}

/// True when the subtitle track [activeIndex] that playback started with
/// (for example a forced or default track the file switches on by itself) is
/// in a language the user did not pick, so it should be switched off.
bool shouldAutoDisableSubtitle(
  List<Map<String, dynamic>> subtitleStreams,
  int? activeIndex, {
  required bool showAll,
  Set<String> languages = defaultSubtitleMenuLanguageCodes,
}) {
  if (showAll || activeIndex == null || activeIndex < 0) return false;
  try {
    for (final stream in subtitleStreams) {
      if (stream['Index'] == activeIndex) {
        return !isMenuLanguageSubtitleStream(stream, languages: languages);
      }
    }
  } catch (_) {}
  return false;
}
