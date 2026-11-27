// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import '../core/language/bias_language_pack.dart';
import '../core/language/language_pack_registry.dart';
import '../models/bias_models.dart';

/// Deterministic local heuristic checker driven by pluggable [BiasLanguagePack]s.
/// Ensures pre-post bias checking always works even when the AI endpoint is offline.
class LocalBiasHeuristics {
  LocalBiasHeuristics._();

  /// Scans all text-bearing components of a draft using [pack] (or the pack
  /// registered for [languageCode]) and produces findings plus suggested
  /// alternate wording for the main post text if biased terms are found.
  static BiasCheckResult evaluate({
    required BiasCheckInput input,
    List<LinkedPageExcerpt> links = const [],
    String? languageCode,
    BiasLanguagePack? pack,
    BiasComponentLabels labels = const BiasComponentLabels.english(),
  }) {
    final activePack = pack ?? LanguagePackRegistry.biasPackFor(languageCode);
    final findings = <BiasFinding>[];
    final checkedComponents = <String>[];

    final rules = activePack?.rules ?? const <BiasHeuristicRule>[];
    final matchCase = activePack?.matchCaseOnReplacement ?? true;

    String rewrittenPostText = input.postText;
    bool postTextModified = false;

    if (input.postText.trim().isNotEmpty) {
      checkedComponents.add(labels.postText);
      if (rules.isNotEmpty) {
        final postScan = _scanAndRewrite(
          input.postText,
          labels.postText,
          rules: rules,
          matchCase: matchCase,
        );
        findings.addAll(postScan.findings);
        if (postScan.modified) {
          rewrittenPostText = postScan.rewritten;
          postTextModified = true;
        }
      }
    }

    if (input.spoilerText.trim().isNotEmpty) {
      checkedComponents.add(labels.contentWarning);
      if (rules.isNotEmpty) {
        findings.addAll(
          _scanAndRewrite(
            input.spoilerText,
            labels.contentWarning,
            rules: rules,
            matchCase: matchCase,
          ).findings,
        );
      }
    }

    for (final attachment in input.attachments) {
      final loc = labels.attachmentLabel(attachment.index);
      checkedComponents.add(loc);
      if (rules.isNotEmpty && attachment.altText.trim().isNotEmpty) {
        findings.addAll(
          _scanAndRewrite(
            attachment.altText,
            loc,
            rules: rules,
            matchCase: matchCase,
          ).findings,
        );
      }
    }

    for (final link in links) {
      final loc = labels.linkLabel(link.url);
      checkedComponents.add(loc);
      final combined = link.toPromptText();
      if (rules.isNotEmpty && combined.isNotEmpty) {
        findings.addAll(
          _scanAndRewrite(
            combined,
            loc,
            rules: rules,
            matchCase: matchCase,
          ).findings,
        );
      }
    }

    for (final ref in input.referencedStatuses) {
      final loc = labels.referencedMessageLabel(ref.authorHandle);
      checkedComponents.add(loc);
      final combined = [
        ref.spoilerText,
        ref.contentText,
        ...ref.mediaAltTexts,
      ].where((s) => s.trim().isNotEmpty).join('\n');
      if (rules.isNotEmpty && combined.isNotEmpty) {
        findings.addAll(
          _scanAndRewrite(
            combined,
            loc,
            rules: rules,
            matchCase: matchCase,
          ).findings,
        );
      }
    }

    if (findings.isEmpty) {
      return BiasCheckResult(
        hasBias: false,
        summary: labels.localCleanSummary,
        checkedComponents: checkedComponents,
        findings: const [],
        usedLocalFallback: true,
      );
    }

    final checkedLabel = checkedComponents.join(', ');
    final summary = labels.findingsSummary(checkedLabel, findings.length);

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
  _scanAndRewrite(
    String text,
    String location, {
    required List<BiasHeuristicRule> rules,
    required bool matchCase,
  }) {
    final findings = <BiasFinding>[];
    var rewritten = text;
    var modified = false;

    for (final rule in rules) {
      // Match against the running rewritten text so compound phrases (e.g.
      // "son of a bitch") do not also trigger shorter sub-word rules ("bitch").
      final match = rule.pattern.firstMatch(rewritten);
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
          return matchCase
              ? _matchCapitalization(original, rule.replacement)
              : rule.replacement;
        });
        modified = true;
      }
    }

    return (findings: findings, rewritten: rewritten, modified: modified);
  }

  static String _matchCapitalization(String original, String replacement) {
    if (original.isEmpty || replacement.isEmpty) return replacement;
    if (original == original.toUpperCase() &&
        original != original.toLowerCase()) {
      return replacement.toUpperCase();
    }
    if (original[0] == original[0].toUpperCase() &&
        original[0] != original[0].toLowerCase()) {
      return replacement[0].toUpperCase() + replacement.substring(1);
    }
    return replacement;
  }
}
