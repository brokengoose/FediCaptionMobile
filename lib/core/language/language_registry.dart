// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

/// Metadata describing a supported human language across captioning, bias
/// checking, translation, and text-to-speech.
class LanguageInfo {
  const LanguageInfo({
    required this.code,
    required this.englishName,
    required this.nativeName,
    required this.defaultTtsLocale,
    this.aliases = const [],
    this.usesWordSpaces = true,
    this.hasLetterCase = true,
  });

  /// Canonical lowercase ISO 639-1 / 639-2 primary language subtag (e.g. `en`).
  final String code;

  /// English name used in LLM prompts and fallback UI labels (e.g. `Spanish`).
  final String englishName;

  /// Endonym displayed to users in language selectors (e.g. `Español`).
  final String nativeName;

  /// Default BCP-47 locale tag used for platform TTS engines (e.g. `es-ES`).
  final String defaultTtsLocale;

  /// Alternative English/native/legacy names accepted during resolution.
  final List<String> aliases;

  /// Whether words are delimited by ASCII spaces when wrapping/truncating text.
  final bool usesWordSpaces;

  /// Whether the language's script distinguishes uppercase and lowercase letters.
  final bool hasLetterCase;
}

/// Centralized catalog and normalization helpers for language codes, display
/// names, endonyms, TTS locales, script characteristics, and offline script detection.
class LanguageRegistry {
  LanguageRegistry._();

  static const List<LanguageInfo> languages = [
    LanguageInfo(
      code: 'af',
      englishName: 'Afrikaans',
      nativeName: 'Afrikaans',
      defaultTtsLocale: 'af-ZA',
    ),
    LanguageInfo(
      code: 'ar',
      englishName: 'Arabic',
      nativeName: 'العربية',
      defaultTtsLocale: 'ar-SA',
      hasLetterCase: false,
    ),
    LanguageInfo(
      code: 'bg',
      englishName: 'Bulgarian',
      nativeName: 'Български',
      defaultTtsLocale: 'bg-BG',
    ),
    LanguageInfo(
      code: 'bn',
      englishName: 'Bengali',
      nativeName: 'বাংলা',
      defaultTtsLocale: 'bn-IN',
      hasLetterCase: false,
    ),
    LanguageInfo(
      code: 'ca',
      englishName: 'Catalan',
      nativeName: 'Català',
      defaultTtsLocale: 'ca-ES',
      aliases: ['catala'],
    ),
    LanguageInfo(
      code: 'cs',
      englishName: 'Czech',
      nativeName: 'Čeština',
      defaultTtsLocale: 'cs-CZ',
      aliases: ['cestina'],
    ),
    LanguageInfo(
      code: 'cy',
      englishName: 'Welsh',
      nativeName: 'Cymraeg',
      defaultTtsLocale: 'cy-GB',
    ),
    LanguageInfo(
      code: 'da',
      englishName: 'Danish',
      nativeName: 'Dansk',
      defaultTtsLocale: 'da-DK',
    ),
    LanguageInfo(
      code: 'de',
      englishName: 'German',
      nativeName: 'Deutsch',
      defaultTtsLocale: 'de-DE',
    ),
    LanguageInfo(
      code: 'el',
      englishName: 'Greek',
      nativeName: 'Ελληνικά',
      defaultTtsLocale: 'el-GR',
    ),
    LanguageInfo(
      code: 'en',
      englishName: 'English',
      nativeName: 'English',
      defaultTtsLocale: 'en-US',
    ),
    LanguageInfo(
      code: 'eo',
      englishName: 'Esperanto',
      nativeName: 'Esperanto',
      defaultTtsLocale: 'eo',
    ),
    LanguageInfo(
      code: 'es',
      englishName: 'Spanish',
      nativeName: 'Español',
      defaultTtsLocale: 'es-ES',
      aliases: ['espanol'],
    ),
    LanguageInfo(
      code: 'et',
      englishName: 'Estonian',
      nativeName: 'Eesti',
      defaultTtsLocale: 'et-EE',
    ),
    LanguageInfo(
      code: 'eu',
      englishName: 'Basque',
      nativeName: 'Euskara',
      defaultTtsLocale: 'eu-ES',
    ),
    LanguageInfo(
      code: 'fa',
      englishName: 'Persian',
      nativeName: 'فارسی',
      defaultTtsLocale: 'fa-IR',
      aliases: ['farsi'],
      hasLetterCase: false,
    ),
    LanguageInfo(
      code: 'fi',
      englishName: 'Finnish',
      nativeName: 'Suomi',
      defaultTtsLocale: 'fi-FI',
    ),
    LanguageInfo(
      code: 'fr',
      englishName: 'French',
      nativeName: 'Français',
      defaultTtsLocale: 'fr-FR',
      aliases: ['francais'],
    ),
    LanguageInfo(
      code: 'ga',
      englishName: 'Irish',
      nativeName: 'Gaeilge',
      defaultTtsLocale: 'ga-IE',
    ),
    LanguageInfo(
      code: 'gl',
      englishName: 'Galician',
      nativeName: 'Galego',
      defaultTtsLocale: 'gl-ES',
    ),
    LanguageInfo(
      code: 'he',
      englishName: 'Hebrew',
      nativeName: 'עברית',
      defaultTtsLocale: 'he-IL',
      hasLetterCase: false,
    ),
    LanguageInfo(
      code: 'hi',
      englishName: 'Hindi',
      nativeName: 'हिन्दी',
      defaultTtsLocale: 'hi-IN',
      hasLetterCase: false,
    ),
    LanguageInfo(
      code: 'hr',
      englishName: 'Croatian',
      nativeName: 'Hrvatski',
      defaultTtsLocale: 'hr-HR',
    ),
    LanguageInfo(
      code: 'hu',
      englishName: 'Hungarian',
      nativeName: 'Magyar',
      defaultTtsLocale: 'hu-HU',
    ),
    LanguageInfo(
      code: 'id',
      englishName: 'Indonesian',
      nativeName: 'Bahasa Indonesia',
      defaultTtsLocale: 'id-ID',
    ),
    LanguageInfo(
      code: 'is',
      englishName: 'Icelandic',
      nativeName: 'Íslenska',
      defaultTtsLocale: 'is-IS',
      aliases: ['islenska'],
    ),
    LanguageInfo(
      code: 'it',
      englishName: 'Italian',
      nativeName: 'Italiano',
      defaultTtsLocale: 'it-IT',
    ),
    LanguageInfo(
      code: 'ja',
      englishName: 'Japanese',
      nativeName: '日本語',
      defaultTtsLocale: 'ja-JP',
      usesWordSpaces: false,
      hasLetterCase: false,
    ),
    LanguageInfo(
      code: 'ko',
      englishName: 'Korean',
      nativeName: '한국어',
      defaultTtsLocale: 'ko-KR',
      hasLetterCase: false,
    ),
    LanguageInfo(
      code: 'lt',
      englishName: 'Lithuanian',
      nativeName: 'Lietuvių',
      defaultTtsLocale: 'lt-LT',
    ),
    LanguageInfo(
      code: 'lv',
      englishName: 'Latvian',
      nativeName: 'Latviešu',
      defaultTtsLocale: 'lv-LV',
    ),
    LanguageInfo(
      code: 'ms',
      englishName: 'Malay',
      nativeName: 'Bahasa Melayu',
      defaultTtsLocale: 'ms-MY',
    ),
    LanguageInfo(
      code: 'nl',
      englishName: 'Dutch',
      nativeName: 'Nederlands',
      defaultTtsLocale: 'nl-NL',
    ),
    LanguageInfo(
      code: 'no',
      englishName: 'Norwegian',
      nativeName: 'Norsk',
      defaultTtsLocale: 'nb-NO',
      aliases: ['nb', 'nn', 'bokmal', 'nynorsk'],
    ),
    LanguageInfo(
      code: 'pl',
      englishName: 'Polish',
      nativeName: 'Polski',
      defaultTtsLocale: 'pl-PL',
    ),
    LanguageInfo(
      code: 'pt',
      englishName: 'Portuguese',
      nativeName: 'Português',
      defaultTtsLocale: 'pt-BR',
      aliases: ['portugues'],
    ),
    LanguageInfo(
      code: 'ro',
      englishName: 'Romanian',
      nativeName: 'Română',
      defaultTtsLocale: 'ro-RO',
      aliases: ['romana'],
    ),
    LanguageInfo(
      code: 'ru',
      englishName: 'Russian',
      nativeName: 'Русский',
      defaultTtsLocale: 'ru-RU',
    ),
    LanguageInfo(
      code: 'sk',
      englishName: 'Slovak',
      nativeName: 'Slovenčina',
      defaultTtsLocale: 'sk-SK',
      aliases: ['slovencina'],
    ),
    LanguageInfo(
      code: 'sl',
      englishName: 'Slovenian',
      nativeName: 'Slovenščina',
      defaultTtsLocale: 'sl-SI',
      aliases: ['slovenscina'],
    ),
    LanguageInfo(
      code: 'sr',
      englishName: 'Serbian',
      nativeName: 'Српски',
      defaultTtsLocale: 'sr-RS',
    ),
    LanguageInfo(
      code: 'sv',
      englishName: 'Swedish',
      nativeName: 'Svenska',
      defaultTtsLocale: 'sv-SE',
    ),
    LanguageInfo(
      code: 'sw',
      englishName: 'Swahili',
      nativeName: 'Kiswahili',
      defaultTtsLocale: 'sw-KE',
    ),
    LanguageInfo(
      code: 'ta',
      englishName: 'Tamil',
      nativeName: 'தமிழ்',
      defaultTtsLocale: 'ta-IN',
      hasLetterCase: false,
    ),
    LanguageInfo(
      code: 'te',
      englishName: 'Telugu',
      nativeName: 'తెలుగు',
      defaultTtsLocale: 'te-IN',
      hasLetterCase: false,
    ),
    LanguageInfo(
      code: 'th',
      englishName: 'Thai',
      nativeName: 'ไทย',
      defaultTtsLocale: 'th-TH',
      usesWordSpaces: false,
      hasLetterCase: false,
    ),
    LanguageInfo(
      code: 'tl',
      englishName: 'Tagalog',
      nativeName: 'Tagalog',
      defaultTtsLocale: 'fil-PH',
      aliases: ['fil', 'filipino'],
    ),
    LanguageInfo(
      code: 'tr',
      englishName: 'Turkish',
      nativeName: 'Türkçe',
      defaultTtsLocale: 'tr-TR',
      aliases: ['turkce'],
    ),
    LanguageInfo(
      code: 'uk',
      englishName: 'Ukrainian',
      nativeName: 'Українська',
      defaultTtsLocale: 'uk-UA',
    ),
    LanguageInfo(
      code: 'ur',
      englishName: 'Urdu',
      nativeName: 'اردو',
      defaultTtsLocale: 'ur-PK',
      hasLetterCase: false,
    ),
    LanguageInfo(
      code: 'vi',
      englishName: 'Vietnamese',
      nativeName: 'Tiếng Việt',
      defaultTtsLocale: 'vi-VN',
      aliases: ['tieng viet'],
    ),
    LanguageInfo(
      code: 'zh',
      englishName: 'Chinese',
      nativeName: '中文',
      defaultTtsLocale: 'zh-CN',
      aliases: ['mandarin', 'cantonese'],
      usesWordSpaces: false,
      hasLetterCase: false,
    ),
  ];

  static final Map<String, LanguageInfo> _byCode = {
    for (final info in languages) info.code: info,
  };

  static final Map<String, LanguageInfo> _byLookupKey = _buildLookupMap();

  static Map<String, LanguageInfo> _buildLookupMap() {
    final map = <String, LanguageInfo>{};
    for (final info in languages) {
      map[info.code.toLowerCase()] = info;
      map[info.englishName.toLowerCase()] = info;
      map[info.nativeName.toLowerCase()] = info;
      for (final alias in info.aliases) {
        map[alias.toLowerCase()] = info;
      }
    }
    return map;
  }

  /// Normalizes a BCP-47 / ISO 639 language tag (e.g. `'en-US'`, `'pt_BR'`)
  /// into its lowercase primary subtag (`'en'`, `'pt'`), or `null` if invalid.
  static String? normalizeCode(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim().toLowerCase();
    if (trimmed.isEmpty || trimmed == 'und' || trimmed == 'unknown') {
      return null;
    }
    final primary = trimmed.split(RegExp(r'[-_]')).first;
    if (primary.length < 2 || primary.length > 3) return null;
    if (!RegExp(r'^[a-z]{2,3}$').hasMatch(primary)) return null;
    // Normalize Norwegian Bokmål / Nynorsk to 'no' for matching consistency.
    if (primary == 'nb' || primary == 'nn') return 'no';
    return primary;
  }

  /// Resolves an ISO code, BCP-47 tag, English name, endonym, or alias to its
  /// cataloged [LanguageInfo], or `null` if unknown.
  static LanguageInfo? resolve(String? nameOrCode) {
    if (nameOrCode == null) return null;
    final trimmed = nameOrCode.trim().toLowerCase();
    if (trimmed.isEmpty) return null;

    final direct = _byLookupKey[trimmed];
    if (direct != null) return direct;

    final normalized = normalizeCode(trimmed);
    if (normalized != null) {
      return _byCode[normalized] ?? _byLookupKey[normalized];
    }
    return null;
  }

  /// Resolves [nameOrCode] to its canonical primary ISO language code (e.g.
  /// `'Spanish'` -> `'es'`, `'en-US'` -> `'en'`), or `null` if unrecognized.
  static String? resolveCode(String? nameOrCode) {
    final info = resolve(nameOrCode);
    if (info != null) return info.code;
    return normalizeCode(nameOrCode);
  }

  /// Returns a human-readable English display name for [codeOrName].
  static String englishNameFor(String codeOrName) {
    final trimmed = codeOrName.trim();
    if (trimmed.isEmpty) return '';
    final info = resolve(trimmed);
    if (info != null) return info.englishName;
    final normalized = normalizeCode(trimmed) ?? trimmed.toLowerCase();
    return normalized.toUpperCase();
  }

  /// Returns the native endonym (e.g. `'Español'`, `'日本語'`) for [codeOrName],
  /// falling back to [englishNameFor].
  static String nativeNameFor(String codeOrName) {
    final info = resolve(codeOrName);
    if (info != null) return info.nativeName;
    return englishNameFor(codeOrName);
  }

  /// Resolves [nameOrCode] into a BCP-47 TTS locale tag (e.g. `'Spanish'` ->
  /// `'es-ES'`, `'es-MX'` -> `'es-MX'`), or `null` if unrecognized.
  static String? resolveTtsLocale(String? nameOrCode) {
    if (nameOrCode == null) return null;
    final trimmed = nameOrCode.trim();
    if (trimmed.isEmpty) return null;

    // Preserve explicit BCP-47 region/script subtags (e.g. 'es-MX', 'en_GB').
    if (trimmed.contains('-') || trimmed.contains('_')) {
      final parts = trimmed
          .split(RegExp(r'[-_]'))
          .where((p) => p.trim().isNotEmpty)
          .toList();
      if (parts.length >= 2 && RegExp(r'^[A-Za-z]{2,3}$').hasMatch(parts.first)) {
        final primary = parts.first.toLowerCase();
        final rest = parts.skip(1).map((seg) {
          if (seg.length == 2 && RegExp(r'^[A-Za-z]{2}$').hasMatch(seg)) {
            return seg.toUpperCase();
          }
          if (seg.length == 4 && RegExp(r'^[A-Za-z]{4}$').hasMatch(seg)) {
            return seg[0].toUpperCase() + seg.substring(1).toLowerCase();
          }
          return seg.toUpperCase();
        });
        return '$primary-${rest.join('-')}';
      }
    }

    final info = resolve(trimmed);
    if (info != null) return info.defaultTtsLocale;

    final normalized = normalizeCode(trimmed);
    if (normalized != null) {
      return _byCode[normalized]?.defaultTtsLocale ?? normalized;
    }
    return null;
  }

  /// Returns a primary lowercase language code suitable for Linux CLI speech
  /// synthesizers (`spd-say --language`, `espeak-ng -v`).
  static String? resolveLinuxTtsCode(String? nameOrCode) {
    final info = resolve(nameOrCode);
    if (info != null) return info.code;
    final locale = resolveTtsLocale(nameOrCode);
    if (locale == null) return null;
    return locale.split('-').first.toLowerCase();
  }

  /// Lightweight Unicode script heuristic used only when a post has no
  /// `language` tag and native language identification is unavailable.
  static String? detectScriptLanguage(String text) {
    var hiraganaKatakana = 0;
    var hangul = 0;
    var cjk = 0;
    var cyrillic = 0;
    var greek = 0;
    var arabic = 0;
    var hebrew = 0;
    var devanagari = 0;
    var thai = 0;

    for (final rune in text.runes) {
      if (rune >= 0x3040 && rune <= 0x30FF) {
        hiraganaKatakana++;
      } else if (rune >= 0xAC00 && rune <= 0xD7AF) {
        hangul++;
      } else if (rune >= 0x4E00 && rune <= 0x9FFF) {
        cjk++;
      } else if (rune >= 0x0400 && rune <= 0x04FF) {
        cyrillic++;
      } else if (rune >= 0x0370 && rune <= 0x03FF) {
        greek++;
      } else if (rune >= 0x0600 && rune <= 0x06FF) {
        arabic++;
      } else if (rune >= 0x0590 && rune <= 0x05FF) {
        hebrew++;
      } else if (rune >= 0x0900 && rune <= 0x097F) {
        devanagari++;
      } else if (rune >= 0x0E00 && rune <= 0x0E7F) {
        thai++;
      }
    }

    if (hiraganaKatakana >= 2) return 'ja';
    if (hangul >= 2) return 'ko';
    if (cjk >= 3) return 'zh';
    if (cyrillic >= 4) return 'ru';
    if (greek >= 4) return 'el';
    if (arabic >= 4) return 'ar';
    if (hebrew >= 4) return 'he';
    if (devanagari >= 4) return 'hi';
    if (thai >= 4) return 'th';
    return null;
  }
}
