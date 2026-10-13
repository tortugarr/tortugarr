/// English names for the app's locales, keyed by [Locale.toLanguageTag].
///
/// Shown next to each language's own name in the interface-language pickers,
/// so someone stuck in a language they can't read can still find their way
/// back to English or their own language.
const Map<String, String> kLocaleEnglishNames = {
  'af': 'Afrikaans', 'ar': 'Arabic', 'be': 'Belarusian', 'bg': 'Bulgarian',
  'bn': 'Bengali', 'ca': 'Catalan', 'cs': 'Czech', 'cy': 'Welsh', 'da': 'Danish',
  'de': 'German', 'el': 'Greek', 'en': 'English', 'en-GB': 'English (UK)',
  'eo': 'Esperanto', 'es': 'Spanish', 'es-419': 'Spanish (Latin America)',
  'es-AR': 'Spanish (Argentina)', 'es-DO': 'Spanish (Dominican Republic)',
  'es-MX': 'Spanish (Mexico)', 'et': 'Estonian', 'fa': 'Persian', 'fi': 'Finnish',
  'fr': 'French', 'gl': 'Galician', 'he': 'Hebrew', 'hi': 'Hindi', 'hr': 'Croatian',
  'hu': 'Hungarian', 'id': 'Indonesian', 'it': 'Italian', 'ja': 'Japanese',
  'kk': 'Kazakh', 'kn': 'Kannada', 'ko': 'Korean', 'lt': 'Lithuanian',
  'lv': 'Latvian', 'mk': 'Macedonian', 'ml': 'Malayalam', 'mn': 'Mongolian',
  'nb': 'Norwegian', 'nl': 'Dutch', 'pa': 'Punjabi', 'pl': 'Polish',
  'pt': 'Portuguese', 'pt-BR': 'Portuguese (Brazil)', 'pt-PT': 'Portuguese (Portugal)',
  'ro': 'Romanian', 'ru': 'Russian', 'si': 'Sinhala', 'sk': 'Slovak',
  'sl': 'Slovenian', 'sq': 'Albanian', 'sr': 'Serbian', 'sv': 'Swedish',
  'sw': 'Swahili', 'ta': 'Tamil', 'te': 'Telugu', 'th': 'Thai', 'tl': 'Filipino',
  'tr': 'Turkish', 'ug': 'Uyghur', 'uk': 'Ukrainian', 'vi': 'Vietnamese',
  'yue': 'Cantonese', 'yue-CN': 'Cantonese (Simplified)',
  'yue-HK': 'Cantonese (Hong Kong)', 'zh': 'Chinese (Simplified)',
  'zh-Hant': 'Chinese (Traditional)',
};

/// "Norsk (Norwegian)"; just the native name when both are the same.
String bilingualLocaleLabel(String tag, String nativeName) {
  final english = kLocaleEnglishNames[tag];
  if (english == null || english.toLowerCase() == nativeName.toLowerCase()) {
    return nativeName;
  }
  return '$nativeName ($english)';
}

/// The "System default" row always carries the English words too.
String bilingualSystemDefaultLabel(String localized) =>
    localized.toLowerCase() == 'system default'
        ? localized
        : '$localized (System default)';
