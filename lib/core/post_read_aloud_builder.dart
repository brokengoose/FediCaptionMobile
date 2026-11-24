// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import '../l10n/l10n.dart';
import '../models/mastodon_models.dart';
import 'html_utils.dart';

/// Assembles a readable plain-text script combining a post's content warning,
/// body text, media alt-text descriptions, and any embedded quoted post.
class PostReadAloudBuilder {
  PostReadAloudBuilder._();

  static final RegExp _terminalPunctuation = RegExp(r'[.!?…:;。！？]$');

  /// Builds the full speech string for [status] using localized labels in [l10n].
  /// Returns an empty string when the post has no readable text or alt-text.
  static String build({
    required MastodonStatus status,
    required AppLocalizations l10n,
    String? bodyOverride,
    String? spoilerOverride,
    Map<String, String> translatedAltTexts = const {},
    String? Function(String mediaId)? aiAltTextLookup,
    MastodonStatus? embeddedQuote,
  }) {
    final target = status.displayStatus;
    final segments = <String>[];

    final spoiler = (spoilerOverride ?? target.spoilerText).trim();
    if (spoiler.isNotEmpty) {
      segments.add(l10n.statusReadAloudContentWarning(spoiler));
    }

    final body = _resolveBodyText(target.contentHtml, bodyOverride: bodyOverride);
    if (body.isNotEmpty) {
      segments.add(body);
    }

    _appendMediaAltSegments(
      segments: segments,
      attachments: target.mediaAttachments,
      l10n: l10n,
      translatedAltTexts: translatedAltTexts,
      aiAltTextLookup: aiAltTextLookup,
    );

    if (embeddedQuote != null) {
      final quoted = embeddedQuote.displayStatus;
      final quotedSegments = <String>[];

      final quotedSpoiler = quoted.spoilerText.trim();
      if (quotedSpoiler.isNotEmpty) {
        quotedSegments.add(l10n.statusReadAloudContentWarning(quotedSpoiler));
      }

      final quotedBody = quoted.plainText.trim();
      if (quotedBody.isNotEmpty) {
        quotedSegments.add(quotedBody);
      }

      _appendMediaAltSegments(
        segments: quotedSegments,
        attachments: quoted.mediaAttachments,
        l10n: l10n,
        aiAltTextLookup: aiAltTextLookup,
      );

      if (quotedSegments.isNotEmpty) {
        segments.add(
          l10n.statusReadAloudQuotedPost(quoted.account.effectiveDisplayName),
        );
        segments.addAll(quotedSegments);
      }
    }

    if (segments.isEmpty) return '';
    return segments.map(_ensureSentencePause).join(' ');
  }

  static String _resolveBodyText(String contentHtml, {String? bodyOverride}) {
    if (bodyOverride != null) {
      return bodyOverride.trim();
    }
    final quoteMatch = HtmlUtils.extractLeadingQuote(contentHtml);
    final bodyHtml = quoteMatch != null ? quoteMatch.remainingHtml : contentHtml;
    return HtmlUtils.htmlToPlainText(bodyHtml).trim();
  }

  static void _appendMediaAltSegments({
    required List<String> segments,
    required List<MastodonMediaAttachment> attachments,
    required AppLocalizations l10n,
    Map<String, String> translatedAltTexts = const {},
    String? Function(String mediaId)? aiAltTextLookup,
  }) {
    final multiple = attachments.length > 1;
    for (var i = 0; i < attachments.length; i++) {
      final att = attachments[i];
      final aiAlt = aiAltTextLookup?.call(att.id)?.trim() ?? '';
      final translatedAlt = translatedAltTexts[att.id]?.trim() ?? '';
      final authorAlt = (att.description ?? '').trim();

      final effectiveAlt = aiAlt.isNotEmpty
          ? aiAlt
          : (translatedAlt.isNotEmpty ? translatedAlt : authorAlt);
      if (effectiveAlt.isEmpty) continue;

      if (multiple) {
        segments.add(
          att.isVideo
              ? l10n.statusReadAloudVideoAltNumbered(i + 1, effectiveAlt)
              : l10n.statusReadAloudImageAltNumbered(i + 1, effectiveAlt),
        );
      } else {
        segments.add(
          att.isVideo
              ? l10n.statusReadAloudVideoAlt(effectiveAlt)
              : l10n.statusReadAloudImageAlt(effectiveAlt),
        );
      }
    }
  }

  static String _ensureSentencePause(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _terminalPunctuation.hasMatch(trimmed)) {
      return trimmed;
    }
    return '$trimmed.';
  }
}
