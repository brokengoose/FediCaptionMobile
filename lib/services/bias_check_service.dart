// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'dart:convert';

import '../core/html_utils.dart';
import '../models/ai_models.dart';
import '../models/app_settings.dart';
import '../models/bias_models.dart';
import 'ai_provider_service.dart';
import 'link_preview_fetcher.dart';
import 'local_bias_heuristics.dart';
import 'mastodon_service.dart';

/// Performs comprehensive pre-post racial and gender bias analysis across:
/// 1. Post contents (main text + Content Warning)
/// 2. Attachments (visual images/keyframes + alt-text descriptions)
/// 3. External links (fetched title, meta description, and text excerpt)
/// 4. Referenced messages (parent reply status + linked Mastodon posts)
///
/// Automatically falls back to [LocalBiasHeuristics] when the AI endpoint is offline.
class BiasCheckService {
  BiasCheckService({
    required AiProviderService aiProviderService,
    required LinkPreviewFetcher linkPreviewFetcher,
    required MastodonService mastodonService,
  })  : _aiProviderService = aiProviderService,
        _linkPreviewFetcher = linkPreviewFetcher,
        _mastodonService = mastodonService;

  final AiProviderService _aiProviderService;
  final LinkPreviewFetcher _linkPreviewFetcher;
  final MastodonService _mastodonService;

  static const int _maxLinksToFetch = 3;

  Future<BiasCheckResult> checkDraft({
    required BiasCheckInput input,
    required AppSettings settings,
    required AiCredentials credentials,
    MastodonSession? session,
  }) async {
    // 1. Extract URLs from post text + spoiler text and separate Mastodon status links vs external links.
    final urls = HtmlUtils.extractUrls('${input.postText}\n${input.spoilerText}');
    final referencedStatuses = List<ReferencedStatusContext>.from(
      input.referencedStatuses,
    );
    final externalLinks = <LinkedPageExcerpt>[];

    var fetchedCount = 0;
    for (final url in urls) {
      if (fetchedCount >= _maxLinksToFetch) break;

      if (session != null && HtmlUtils.looksLikeMastodonStatusUrl(url)) {
        final resolved = await _mastodonService.resolveStatusByUrl(
          instanceUrl: session.instanceUrl,
          accessToken: session.accessToken,
          statusUrl: url,
        );
        if (resolved != null) {
          referencedStatuses.add(
            ReferencedStatusContext.fromStatus(resolved, sourceUrl: url),
          );
          fetchedCount++;
          continue;
        }
      }

      final excerpt = await _linkPreviewFetcher.fetch(url);
      if (excerpt != null) {
        externalLinks.add(excerpt);
        fetchedCount++;
      }
    }

    final enrichedInput = BiasCheckInput(
      postText: input.postText,
      spoilerText: input.spoilerText,
      attachments: input.attachments,
      referencedStatuses: referencedStatuses,
    );

    // Always compute local deterministic check so it can act as offline fallback or safety backstop.
    final localResult = LocalBiasHeuristics.evaluate(
      input: enrichedInput,
      links: externalLinks,
    );

    // If user selected "No AI", return deterministic offline heuristics directly.
    if (settings.activeProvider == AiProviderType.none) {
      return localResult;
    }

    final checkedComponents = _buildCheckedComponentsList(
      enrichedInput,
      externalLinks,
    );
    if (checkedComponents.isEmpty) {
      return BiasCheckResult.clean;
    }

    // Collect visual frames from attachments for multimodal bias inspection.
    final visualMedia = <MediaBinaryPayload>[];
    for (final att in enrichedInput.attachments) {
      visualMedia.addAll(att.visualFrames);
    }

    try {
      final prompt = _buildBiasPrompt(
        input: enrichedInput,
        links: externalLinks,
      );

      final rawJson = await _aiProviderService.runMultimodalPrompt(
        settings: settings,
        credentials: credentials,
        systemPrompt:
            'You are an objective, fair racial and gender bias reviewer for social media posts. Analyze all provided components (post text, content warning, attached images/video keyframes and their alt-text, linked webpage excerpts, and referenced/replied-to messages) for explicit or implicit racial bias or gender bias — INCLUDING gendered profanity, slurs, or pejoratives (such as "bitch", "bitching", "bitchy", "cunt", "slut", "whore", "man up", "like a girl"), male-default terminology, gendered stereotypes, racial slurs, and racially loaded idioms (such as "gypped", "uppity", "whitelist/blacklist"). Avoid false positives on neutral discussions or anti-bias advocacy. Respond ONLY with valid JSON.',
        userPrompt: prompt,
        media: visualMedia,
        expectJson: true,
      );

      final aiResult = _parseAiResponse(
        rawJson: rawJson,
        checkedComponents: checkedComponents,
      );

      // Merge any deterministic local heuristic findings not already caught by AI.
      return _mergeWithLocalBackstop(aiResult, localResult);
    } catch (_) {
      // AI endpoint offline, unconfigured, or errored -> deterministic local fallback.
      return localResult;
    }
  }

  List<String> _buildCheckedComponentsList(
    BiasCheckInput input,
    List<LinkedPageExcerpt> links,
  ) {
    return [
      if (input.postText.trim().isNotEmpty) 'Post Text',
      if (input.spoilerText.trim().isNotEmpty) 'Content Warning',
      for (final a in input.attachments) 'Attachment ${a.index}',
      for (final l in links) 'Link (${l.url})',
      for (final r in input.referencedStatuses) r.locationLabel,
    ];
  }

  String _buildBiasPrompt({
    required BiasCheckInput input,
    required List<LinkedPageExcerpt> links,
  }) {
    final buffer = StringBuffer();
    buffer.writeln(
      'Review the following Mastodon draft and its associated context for explicit or implicit racial bias or gender bias.',
    );
    buffer.writeln();

    buffer.writeln('=== Post Text ===');
    buffer.writeln(input.postText.trim().isEmpty ? '(empty)' : input.postText.trim());
    buffer.writeln();

    if (input.spoilerText.trim().isNotEmpty) {
      buffer.writeln('=== Content Warning ===');
      buffer.writeln(input.spoilerText.trim());
      buffer.writeln();
    }

    for (final att in input.attachments) {
      buffer.writeln(
        '=== Attachment ${att.index} (${att.isVideo ? 'Video' : 'Image'}) ===',
      );
      buffer.writeln(
        'Alt-text: ${att.altText.trim().isEmpty ? '(no alt-text)' : att.altText.trim()}',
      );
      if (att.visualFrames.isNotEmpty) {
        buffer.writeln(
          'Visual media attached (${att.visualFrames.length} image/frame payload(s) included). Inspect the visual content as well as the alt-text.',
        );
      }
      buffer.writeln();
    }

    for (final link in links) {
      buffer.writeln('=== Link (${link.url}) ===');
      buffer.writeln(link.toPromptText());
      buffer.writeln();
    }

    for (final ref in input.referencedStatuses) {
      buffer.writeln('=== ${ref.locationLabel} ===');
      if (ref.spoilerText.trim().isNotEmpty) {
        buffer.writeln('Content Warning: ${ref.spoilerText.trim()}');
      }
      buffer.writeln('Text: ${ref.contentText.trim()}');
      if (ref.mediaAltTexts.isNotEmpty) {
        buffer.writeln('Media Alt-Text: ${ref.mediaAltTexts.join(' | ')}');
      }
      buffer.writeln();
    }

    buffer.writeln('Respond ONLY with a JSON object matching this exact schema:');
    buffer.writeln('''
{
  "has_bias": true or false,
  "summary": "Brief 1-2 sentence summary of what was checked and what was found.",
  "findings": [
    {
      "location": "Exact location: 'Post Text', 'Content Warning', 'Attachment 1', 'Link (https://...)', or 'Referenced Message (@user)'",
      "bias_type": "e.g. 'Implicit Racial Bias', 'Explicit Racial Bias', 'Implicit Gender Bias', 'Explicit Gender Bias'",
      "explanation": "Concise explanation of the bias found.",
      "excerpt": "Short relevant snippet if applicable"
    }
  ],
  "suggested_alternate_wording": "If the Post Text itself contains bias, provide a complete rewritten version of the Post Text that preserves the user's meaning while being more inclusive and unbiased. Otherwise null."
}
''');

    return buffer.toString();
  }

  BiasCheckResult _parseAiResponse({
    required String rawJson,
    required List<String> checkedComponents,
  }) {
    final cleaned = _extractJsonObject(rawJson);
    final decoded = jsonDecode(cleaned) as Map<String, dynamic>;

    final rawFindings = (decoded['findings'] as List<dynamic>?) ?? const [];
    final findings = rawFindings
        .whereType<Map<String, dynamic>>()
        .map(BiasFinding.fromJson)
        .where((f) => f.explanation.trim().isNotEmpty)
        .toList();

    final hasBias = (decoded['has_bias'] as bool? ?? false) || findings.isNotEmpty;
    final summary = (decoded['summary'] as String?)?.trim();
    final suggested = (decoded['suggested_alternate_wording'] as String?)?.trim();

    return BiasCheckResult(
      hasBias: hasBias,
      summary: (summary != null && summary.isNotEmpty)
          ? summary
          : (hasBias
              ? 'Checked ${checkedComponents.join(', ')} and detected potential racial or gender bias.'
              : 'No racial or gender bias detected.'),
      checkedComponents: checkedComponents,
      findings: findings,
      suggestedAlternateWording:
          (suggested != null && suggested.isNotEmpty) ? suggested : null,
      usedLocalFallback: false,
    );
  }

  BiasCheckResult _mergeWithLocalBackstop(
    BiasCheckResult aiResult,
    BiasCheckResult localResult,
  ) {
    if (!localResult.hasBias) return aiResult;
    if (!aiResult.hasBias) return localResult;

    final mergedFindings = List<BiasFinding>.from(aiResult.findings);
    for (final localFinding in localResult.findings) {
      final alreadyCovered = mergedFindings.any(
        (f) =>
            f.location.toLowerCase() == localFinding.location.toLowerCase() &&
            localFinding.excerpt != null &&
            (f.explanation.toLowerCase().contains(
                  localFinding.excerpt!.toLowerCase(),
                ) ||
                (f.excerpt ?? '').toLowerCase().contains(
                      localFinding.excerpt!.toLowerCase(),
                    )),
      );
      if (!alreadyCovered) {
        mergedFindings.add(localFinding);
      }
    }

    return BiasCheckResult(
      hasBias: true,
      summary: aiResult.summary,
      checkedComponents: aiResult.checkedComponents,
      findings: mergedFindings,
      suggestedAlternateWording:
          aiResult.suggestedAlternateWording ?? localResult.suggestedAlternateWording,
      usedLocalFallback: false,
    );
  }

  String _extractJsonObject(String input) {
    var trimmed = input.trim();
    if (trimmed.startsWith('```')) {
      trimmed = trimmed
          .replaceFirst(RegExp(r'^```(?:json)?\s*', caseSensitive: false), '')
          .replaceFirst(RegExp(r'\s*```$'), '')
          .trim();
    }
    final firstBrace = trimmed.indexOf('{');
    final lastBrace = trimmed.lastIndexOf('}');
    if (firstBrace >= 0 && lastBrace > firstBrace) {
      trimmed = trimmed.substring(firstBrace, lastBrace + 1);
    }
    // Strip trailing commas before '}' or ']' that smaller on-device LLMs sometimes emit.
    return trimmed.replaceAll(RegExp(r',\s*([}\]])'), r'$1');
  }
}
