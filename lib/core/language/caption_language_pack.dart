// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

/// Language-specific configuration for AI alt-text caption formatting and prompts.
///
/// Each supported caption language defines its own localized alt-text prefix,
/// preamble patterns to strip from raw LLM output, quotation styles, prompt
/// forbidden-prefix examples, and typography behavior.
class CaptionLanguagePack {
  const CaptionLanguagePack({
    required this.languageCode,
    required this.captionPrefix,
    this.redundantPrefixPatterns = const [],
    this.quotePairs = defaultQuotePairs,
    this.forbiddenPrefixExamples = const [],
    this.capitalizeFirstLetter = true,
    this.usesWordSpaces = true,
  });

  /// Canonical lowercase ISO 639-1 language code (e.g. `'en'`, `'es'`, `'ja'`).
  final String languageCode;

  /// Mandatory alt-text prefix prepended to AI-generated descriptions in this language.
  final String captionPrefix;

  /// Regexes matching redundant preambles or duplicate prefixes emitted by LLMs.
  final List<RegExp> redundantPrefixPatterns;

  /// Opening/closing quotation mark pairs stripped around raw LLM captions.
  final List<(String, String)> quotePairs;

  /// Example prefixes included in the negative constraint of AI caption prompts.
  final List<String> forbiddenPrefixExamples;

  /// Whether the first letter after [captionPrefix] should be uppercased.
  final bool capitalizeFirstLetter;

  /// Whether words are delimited by spaces when truncating on word boundaries.
  final bool usesWordSpaces;

  static const List<(String, String)> defaultQuotePairs = [
    ('"', '"'),
    ("'", "'"),
    ('“', '”'),
    ('‘', '’'),
    ('`', '`'),
    ('«', '»'),
    ('「', '」'),
    ('『', '』'),
    ('„', '“'),
  ];
}
