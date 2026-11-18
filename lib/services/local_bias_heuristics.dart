// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import '../models/bias_models.dart';

class _BiasRule {
  const _BiasRule({
    required this.pattern,
    required this.replacement,
    required this.biasType,
    required this.explanation,
  });

  final RegExp pattern;
  final String replacement;
  final String biasType;
  final String explanation;
}

/// Deterministic local heuristic checker for gender-exclusive and racially loaded terms.
/// Ensures pre-post bias checking always works even when the AI endpoint is offline.
class LocalBiasHeuristics {
  LocalBiasHeuristics._();

  static final List<_BiasRule> _rules = [
    _BiasRule(
      pattern: RegExp(r'\bmankind\b', caseSensitive: false),
      replacement: 'humanity',
      biasType: 'Implicit Gender Bias',
      explanation: '"mankind" defaults to male terminology; consider "humanity" or "humankind".',
    ),
    _BiasRule(
      pattern: RegExp(r'\bmanpower\b', caseSensitive: false),
      replacement: 'workforce',
      biasType: 'Implicit Gender Bias',
      explanation: '"manpower" uses male-centered language; consider "workforce" or "staffing".',
    ),
    _BiasRule(
      pattern: RegExp(r'\bchairmen\b', caseSensitive: false),
      replacement: 'chairpersons',
      biasType: 'Implicit Gender Bias',
      explanation: '"chairmen" assumes male leadership; consider "chairpersons" or "chairs".',
    ),
    _BiasRule(
      pattern: RegExp(r'\bchairman\b', caseSensitive: false),
      replacement: 'chairperson',
      biasType: 'Implicit Gender Bias',
      explanation: '"chairman" assumes a male role; consider "chairperson" or "chair".',
    ),
    _BiasRule(
      pattern: RegExp(r'\bpolicemen\b', caseSensitive: false),
      replacement: 'police officers',
      biasType: 'Implicit Gender Bias',
      explanation: '"policemen" is gender-exclusive; consider "police officers".',
    ),
    _BiasRule(
      pattern: RegExp(r'\bpoliceman\b', caseSensitive: false),
      replacement: 'police officer',
      biasType: 'Implicit Gender Bias',
      explanation: '"policeman" is gender-exclusive; consider "police officer".',
    ),
    _BiasRule(
      pattern: RegExp(r'\bfiremen\b', caseSensitive: false),
      replacement: 'firefighters',
      biasType: 'Implicit Gender Bias',
      explanation: '"firemen" is gender-exclusive; consider "firefighters".',
    ),
    _BiasRule(
      pattern: RegExp(r'\bfireman\b', caseSensitive: false),
      replacement: 'firefighter',
      biasType: 'Implicit Gender Bias',
      explanation: '"fireman" is gender-exclusive; consider "firefighter".',
    ),
    _BiasRule(
      pattern: RegExp(r'\bhey\s+guys\b', caseSensitive: false),
      replacement: 'hey everyone',
      biasType: 'Implicit Gender Bias',
      explanation: '"hey guys" uses a male-default plural; consider "hey everyone" or "hey folks".',
    ),
    _BiasRule(
      pattern: RegExp(r'\byou\s+guys\b', caseSensitive: false),
      replacement: 'everyone',
      biasType: 'Implicit Gender Bias',
      explanation: '"you guys" uses a male-default plural; consider "everyone" or "you all".',
    ),
    _BiasRule(
      pattern: RegExp(r'\bhusbands\s+and\s+wives\b', caseSensitive: false),
      replacement: 'spouses and partners',
      biasType: 'Implicit Gender Bias',
      explanation: '"husbands and wives" assumes binary heterosexual couples; consider "spouses and partners".',
    ),
    _BiasRule(
      pattern: RegExp(r'\bwhitelisted\b', caseSensitive: false),
      replacement: 'allowlisted',
      biasType: 'Implicit Racial Bias',
      explanation: '"whitelisted" associates white with permitted/good; consider "allowlisted".',
    ),
    _BiasRule(
      pattern: RegExp(r'\bwhitelist\b', caseSensitive: false),
      replacement: 'allowlist',
      biasType: 'Implicit Racial Bias',
      explanation: '"whitelist" associates white with permitted/good; consider "allowlist".',
    ),
    _BiasRule(
      pattern: RegExp(r'\bblacklisted\b', caseSensitive: false),
      replacement: 'blocklisted',
      biasType: 'Implicit Racial Bias',
      explanation: '"blacklisted" associates black with bad/blocked; consider "blocklisted".',
    ),
    _BiasRule(
      pattern: RegExp(r'\bblacklist\b', caseSensitive: false),
      replacement: 'blocklist',
      biasType: 'Implicit Racial Bias',
      explanation: '"blacklist" associates black with bad/blocked; consider "blocklist".',
    ),
    _BiasRule(
      pattern: RegExp(r'\bmaster\s*[/\-]\s*slave\b', caseSensitive: false),
      replacement: 'primary/replica',
      biasType: 'Implicit Racial Bias',
      explanation: '"master/slave" draws on slavery terminology; consider "primary/replica" or "leader/follower".',
    ),
    _BiasRule(
      pattern: RegExp(r'\bgrandfathered\b', caseSensitive: false),
      replacement: 'legacy-exempted',
      biasType: 'Implicit Racial Bias',
      explanation: '"grandfathered" originates from Jim Crow voter disenfranchisement clauses; consider "legacy-exempted".',
    ),
    _BiasRule(
      pattern: RegExp(r'\bbusinessmen\b', caseSensitive: false),
      replacement: 'businesspeople',
      biasType: 'Implicit Gender Bias',
      explanation: '"businessmen" is gender-exclusive; consider "businesspeople".',
    ),
    _BiasRule(
      pattern: RegExp(r'\bbusinessman\b', caseSensitive: false),
      replacement: 'businessperson',
      biasType: 'Implicit Gender Bias',
      explanation: '"businessman" is gender-exclusive; consider "businessperson".',
    ),
    _BiasRule(
      pattern: RegExp(r'\bspokesman\b', caseSensitive: false),
      replacement: 'spokesperson',
      biasType: 'Implicit Gender Bias',
      explanation: '"spokesman" is gender-exclusive; consider "spokesperson".',
    ),
    _BiasRule(
      pattern: RegExp(r'\bstewardess\b', caseSensitive: false),
      replacement: 'flight attendant',
      biasType: 'Implicit Gender Bias',
      explanation: '"stewardess" is gendered occupational language; consider "flight attendant".',
    ),
    _BiasRule(
      pattern: RegExp(r'\bman-made\b', caseSensitive: false),
      replacement: 'human-made',
      biasType: 'Implicit Gender Bias',
      explanation: '"man-made" uses male-default wording; consider "human-made" or "artificial".',
    ),
  ];

  /// Scans all text-bearing components of a draft and produces findings plus
  /// suggested alternate wording for the main post text if biased terms are found.
  static BiasCheckResult evaluate({
    required BiasCheckInput input,
    List<LinkedPageExcerpt> links = const [],
  }) {
    final findings = <BiasFinding>[];
    final checkedComponents = <String>[];

    String rewrittenPostText = input.postText;
    bool postTextModified = false;

    if (input.postText.trim().isNotEmpty) {
      checkedComponents.add('Post Text');
      final postScan = _scanAndRewrite(input.postText, 'Post Text');
      findings.addAll(postScan.findings);
      if (postScan.modified) {
        rewrittenPostText = postScan.rewritten;
        postTextModified = true;
      }
    }

    if (input.spoilerText.trim().isNotEmpty) {
      checkedComponents.add('Content Warning');
      findings.addAll(
        _scanAndRewrite(input.spoilerText, 'Content Warning').findings,
      );
    }

    for (final attachment in input.attachments) {
      final loc = 'Attachment ${attachment.index}';
      checkedComponents.add(loc);
      if (attachment.altText.trim().isNotEmpty) {
        findings.addAll(_scanAndRewrite(attachment.altText, loc).findings);
      }
    }

    for (final link in links) {
      final loc = 'Link (${link.url})';
      checkedComponents.add(loc);
      final combined = link.toPromptText();
      if (combined.isNotEmpty) {
        findings.addAll(_scanAndRewrite(combined, loc).findings);
      }
    }

    for (final ref in input.referencedStatuses) {
      final loc = ref.locationLabel;
      checkedComponents.add(loc);
      final combined = [
        ref.spoilerText,
        ref.contentText,
        ...ref.mediaAltTexts,
      ].where((s) => s.trim().isNotEmpty).join('\n');
      if (combined.isNotEmpty) {
        findings.addAll(_scanAndRewrite(combined, loc).findings);
      }
    }

    if (findings.isEmpty) {
      return BiasCheckResult(
        hasBias: false,
        summary: 'No racial or gender bias detected via local check.',
        checkedComponents: checkedComponents,
        findings: const [],
        usedLocalFallback: true,
      );
    }

    final checkedLabel = checkedComponents.join(', ');
    final summary =
        'Checked $checkedLabel (offline heuristic check) and found ${findings.length} potential racial or gender bias ${findings.length == 1 ? 'issue' : 'issues'}.';

    return BiasCheckResult(
      hasBias: true,
      summary: summary,
      checkedComponents: checkedComponents,
      findings: findings,
      suggestedAlternateWording: postTextModified ? rewrittenPostText : null,
      usedLocalFallback: true,
    );
  }

  static ({List<BiasFinding> findings, String rewritten, bool modified})
      _scanAndRewrite(String text, String location) {
    final findings = <BiasFinding>[];
    var rewritten = text;
    var modified = false;

    for (final rule in _rules) {
      final match = rule.pattern.firstMatch(text);
      if (match != null) {
        findings.add(
          BiasFinding(
            location: location,
            biasType: rule.biasType,
            explanation: rule.explanation,
            excerpt: match.group(0),
          ),
        );
        rewritten = rewritten.replaceAllMapped(rule.pattern, (m) {
          final original = m.group(0) ?? '';
          return _matchCapitalization(original, rule.replacement);
        });
        modified = true;
      }
    }

    return (findings: findings, rewritten: rewritten, modified: modified);
  }

  static String _matchCapitalization(String original, String replacement) {
    if (original.isEmpty || replacement.isEmpty) return replacement;
    if (original == original.toUpperCase() && original != original.toLowerCase()) {
      return replacement.toUpperCase();
    }
    if (original[0] == original[0].toUpperCase() &&
        original[0] != original[0].toLowerCase()) {
      return replacement[0].toUpperCase() + replacement.substring(1);
    }
    return replacement;
  }
}
