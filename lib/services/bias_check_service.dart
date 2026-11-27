// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'dart:convert';

import '../core/html_utils.dart';
import '../core/json_coerce.dart';
import '../core/language/bias_language_pack.dart';
import '../core/language/language_pack_registry.dart';
import '../core/language/language_registry.dart';
import '../models/ai_models.dart';
import '../models/app_settings.dart';
import '../models/bias_models.dart';
import '../state/quote_cache_controller.dart';
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
    QuoteCacheController? quoteCache,
  })  : _aiProviderService = aiProviderService,
        _linkPreviewFetcher = linkPreviewFetcher,
        _mastodonService = mastodonService,
        _quoteCache = quoteCache;

  final AiProviderService _aiProviderService;
  final LinkPreviewFetcher _linkPreviewFetcher;
  final MastodonService _mastodonService;
  final QuoteCacheController? _quoteCache;

  static const int _maxLinksToFetch = 3;

  Future<BiasCheckResult> checkDraft({
    required BiasCheckInput input,
    required AppSettings settings,
    required AiCredentials credentials,
    MastodonSession? session,
    String? contentLanguageCode,
    String? responseLanguageCode,
    BiasComponentLabels labels = const BiasComponentLabels.english(),
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
        final resolved = _quoteCache != null
            ? await _quoteCache.resolve(url, session: session)
            : await _mastodonService.resolveStatusByUrl(
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

    final effectiveContentLang =
        LanguageRegistry.resolveCode(contentLanguageCode) ??
            LanguageRegistry.detectScriptLanguage(
              '${enrichedInput.postText}\n${enrichedInput.spoilerText}',
            );
    final biasPack = LanguagePackRegistry.biasPackFor(
      effectiveContentLang,
      fallbackToEnglish: false,
    );

    // Always compute local deterministic check so it can act as offline fallback or safety backstop.
    final localResult = LocalBiasHeuristics.evaluate(
      input: enrichedInput,
      links: externalLinks,
      languageCode: effectiveContentLang,
      pack: biasPack,
      labels: labels,
    );

    // If user selected "No AI", return deterministic offline heuristics directly.
    if (settings.activeProvider == AiProviderType.none) {
      return localResult;
    }

    final checkedComponents = _buildCheckedComponentsList(
      enrichedInput,
      externalLinks,
      labels: labels,
    );
    if (checkedComponents.isEmpty) {
      return BiasCheckResult(
        hasBias: false,
        summary: labels.cleanSummary,
        checkedComponents: const [],
        findings: const [],
      );
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
        labels: labels,
        responseLanguageCode: responseLanguageCode,
      );

      final rawJson = await _aiProviderService.runMultimodalPrompt(
        settings: settings,
        credentials: credentials,
        systemPrompt: _buildSystemPrompt(
          biasPack: biasPack,
          responseLanguageCode: responseLanguageCode,
        ),
        userPrompt: prompt,
        media: visualMedia,
        expectJson: true,
      );

      final aiResult = _parseAiResponse(
        rawJson: rawJson,
        checkedComponents: checkedComponents,
        labels: labels,
      );

      // Merge any deterministic local heuristic findings not already caught by AI.
      return _mergeWithLocalBackstop(aiResult, localResult);
    } catch (_) {
      // AI endpoint offline, unconfigured, or errored -> deterministic local fallback.
      return localResult;
    }
  }

  String _buildSystemPrompt({
    required BiasLanguagePack? biasPack,
    String? responseLanguageCode,
  }) {
    final examples = biasPack?.promptBiasExamples ?? const [];
    final examplesPhrase = examples.isNotEmpty
        ? ' (such as ${examples.map((e) => '"$e"').join(', ')})'
        : '';
    final normalizedResp = LanguageRegistry.resolveCode(responseLanguageCode);
    final languageInstruction =
        (normalizedResp != null && normalizedResp != 'en')
            ? ' Write "summary", "bias_type", and "explanation" in ${LanguageRegistry.englishNameFor(normalizedResp)}, while keeping "suggested_alternate_wording" in the draft\'s original language.'
            : '';

    return 'You are an objective, fair racial and gender bias reviewer for social media posts. '
        'Analyze all provided components (post text, content warning, attached images/video keyframes and their alt-text, linked webpage excerpts, and referenced/replied-to messages) '
        'for explicit or implicit racial bias or gender bias — INCLUDING gendered profanity, slurs, or pejoratives, '
        'male-default terminology, gendered stereotypes, racial slurs, and racially loaded idioms$examplesPhrase. '
        'Avoid false positives on neutral discussions or anti-bias advocacy.$languageInstruction Respond ONLY with valid JSON.';
  }

  List<String> _buildCheckedComponentsList(
    BiasCheckInput input,
    List<LinkedPageExcerpt> links, {
    required BiasComponentLabels labels,
  }) {
    return [
      if (input.postText.trim().isNotEmpty) labels.postText,
      if (input.spoilerText.trim().isNotEmpty) labels.contentWarning,
      for (final a in input.attachments) labels.attachmentLabel(a.index),
      for (final l in links) labels.linkLabel(l.url),
      for (final r in input.referencedStatuses)
        labels.referencedMessageLabel(r.authorHandle),
    ];
  }

  String _buildBiasPrompt({
    required BiasCheckInput input,
    required List<LinkedPageExcerpt> links,
    required BiasComponentLabels labels,
    String? responseLanguageCode,
  }) {
    final buffer = StringBuffer();
    buffer.writeln(
      'Review the following Mastodon draft and its associated context for explicit or implicit racial bias or gender bias.',
    );
    final normalizedResp = LanguageRegistry.resolveCode(responseLanguageCode);
    if (normalizedResp != null && normalizedResp != 'en') {
      final respName = LanguageRegistry.englishNameFor(normalizedResp);
      buffer.writeln(
        'Write the "summary", "bias_type", and "explanation" fields in $respName, and keep "suggested_alternate_wording" in the same language as the post text.',
      );
    }
    buffer.writeln();

    buffer.writeln('=== ${labels.postText} ===');
    buffer.writeln(input.postText.trim().isEmpty ? '(empty)' : input.postText.trim());
    buffer.writeln();

    if (input.spoilerText.trim().isNotEmpty) {
      buffer.writeln('=== ${labels.contentWarning} ===');
      buffer.writeln(input.spoilerText.trim());
      buffer.writeln();
    }

    for (final att in input.attachments) {
      buffer.writeln(
        '=== ${labels.attachmentLabel(att.index)} (${att.isVideo ? 'Video' : 'Image'}) ===',
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
      buffer.writeln('=== ${labels.linkLabel(link.url)} ===');
      buffer.writeln(link.toPromptText());
      buffer.writeln();
    }

    for (final ref in input.referencedStatuses) {
      buffer.writeln('=== ${labels.referencedMessageLabel(ref.authorHandle)} ===');
      if (ref.spoilerText.trim().isNotEmpty) {
        buffer.writeln('${labels.contentWarning}: ${ref.spoilerText.trim()}');
      }
      buffer.writeln('Text: ${ref.contentText.trim()}');
      if (ref.mediaAltTexts.isNotEmpty) {
        buffer.writeln('Media Alt-Text: ${ref.mediaAltTexts.join(' | ')}');
      }
      buffer.writeln();
    }

    final exampleAtt = labels.attachmentLabel(1);
    final exampleLink = labels.linkLabel('https://...');
    final exampleRef = labels.referencedMessageLabel('user');
    buffer.writeln('Respond ONLY with a JSON object matching this exact schema:');
    buffer.writeln('''
{
  "has_bias": true or false,
  "summary": "Brief 1-2 sentence summary of what was checked and what was found.",
  "findings": [
    {
      "location": "Exact location: '${labels.postText}', '${labels.contentWarning}', '$exampleAtt', '$exampleLink', or '$exampleRef'",
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
    required BiasComponentLabels labels,
  }) {
    final cleaned = _extractJsonObject(rawJson);
    final decoded = jsonDecode(cleaned) as Map<String, dynamic>;

    final rawFindings = jsonList(decoded['findings']);
    final findings = rawFindings
        .whereType<Map<String, dynamic>>()
        .map(BiasFinding.fromJson)
        .where((f) => f.explanation.trim().isNotEmpty)
        .toList();

    final hasBias = jsonBool(decoded['has_bias']) || findings.isNotEmpty;
    final summary = jsonString(decoded['summary'])?.trim();
    final suggested =
        jsonString(decoded['suggested_alternate_wording'])?.trim();

    return BiasCheckResult(
      hasBias: hasBias,
      summary: (summary != null && summary.isNotEmpty)
          ? summary
          : (hasBias
              ? labels.aiFallbackBiasSummary(checkedComponents.join(', '))
              : labels.aiFallbackCleanSummary),
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
