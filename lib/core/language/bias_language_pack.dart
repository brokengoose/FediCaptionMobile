// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

/// High-level bias classifications used by heuristic rule packs.
enum BiasCategory {
  implicitGender,
  explicitGender,
  implicitRacial,
  explicitRacial,
}

/// A single language-specific inclusive-language or slur detection rule.
class BiasHeuristicRule {
  const BiasHeuristicRule({
    required this.pattern,
    required this.replacement,
    required this.category,
    required this.biasType,
    required this.explanation,
  });

  final RegExp pattern;
  final String replacement;
  final BiasCategory category;
  final String biasType;
  final String explanation;
}

/// Pluggable offline inclusive-language heuristic rules and prompt examples for
/// a specific draft language.
class BiasLanguagePack {
  const BiasLanguagePack({
    required this.languageCode,
    required this.rules,
    this.promptBiasExamples = const [],
    this.matchCaseOnReplacement = true,
  });

  /// Canonical lowercase ISO 639-1 language code (e.g. `'en'`).
  final String languageCode;

  /// Ordered heuristic rules evaluated sequentially against draft components.
  final List<BiasHeuristicRule> rules;

  /// Representative biased terms/idioms shown in the multimodal AI system prompt.
  final List<String> promptBiasExamples;

  /// Whether replacements should preserve original ASCII capitalization.
  final bool matchCaseOnReplacement;
}

/// Localized labels and summary builders injected into [LocalBiasHeuristics]
/// and [BiasCheckService] so findings and summaries appear in the active UI language.
class BiasComponentLabels {
  const BiasComponentLabels({
    required this.postText,
    required this.contentWarning,
    required this._attachmentLabel,
    required this._linkLabel,
    required this._referencedMessageLabel,
    required this.cleanSummary,
    required this.localCleanSummary,
    required this._findingsSummary,
    required this._aiFallbackBiasSummary,
    required this.aiFallbackCleanSummary,
  });

  const BiasComponentLabels.english()
    : postText = 'Post Text',
      contentWarning = 'Content Warning',
      _attachmentLabel = _defaultAttachmentLabel,
      _linkLabel = _defaultLinkLabel,
      _referencedMessageLabel = _defaultReferencedMessageLabel,
      cleanSummary = 'No racial or gender bias detected.',
      localCleanSummary = 'No racial or gender bias detected via local check.',
      _findingsSummary = _defaultFindingsSummary,
      _aiFallbackBiasSummary = _defaultAiFallbackBiasSummary,
      aiFallbackCleanSummary = 'No racial or gender bias detected.';

  final String postText;
  final String contentWarning;
  final String Function(int index) _attachmentLabel;
  final String Function(String url) _linkLabel;
  final String Function(String handle) _referencedMessageLabel;
  final String cleanSummary;
  final String localCleanSummary;
  final String Function(String checkedLabel, int count) _findingsSummary;
  final String Function(String checkedLabel) _aiFallbackBiasSummary;
  final String aiFallbackCleanSummary;

  String attachmentLabel(int index) => _attachmentLabel(index);
  String linkLabel(String url) => _linkLabel(url);
  String referencedMessageLabel(String handle) =>
      _referencedMessageLabel(handle);
  String findingsSummary(String checkedLabel, int count) =>
      _findingsSummary(checkedLabel, count);
  String aiFallbackBiasSummary(String checkedLabel) =>
      _aiFallbackBiasSummary(checkedLabel);

  static String _defaultAttachmentLabel(int index) => 'Attachment $index';
  static String _defaultLinkLabel(String url) => 'Link ($url)';
  static String _defaultReferencedMessageLabel(String handle) =>
      'Referenced Message (@$handle)';
  static String _defaultFindingsSummary(String checkedLabel, int count) =>
      'Checked $checkedLabel (offline heuristic check) and found $count potential racial or gender bias ${count == 1 ? 'issue' : 'issues'}.';
  static String _defaultAiFallbackBiasSummary(String checkedLabel) =>
      'Checked $checkedLabel and detected potential racial or gender bias.';
}
