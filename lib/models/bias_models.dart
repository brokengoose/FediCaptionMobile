// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import '../core/json_coerce.dart';
import 'ai_models.dart';
import 'mastodon_models.dart';

/// A single racial or gender bias finding with its exact source location.
class BiasFinding {
  const BiasFinding({
    required this.location,
    required this.biasType,
    required this.explanation,
    this.excerpt,
  });

  /// E.g., `Post Text`, `Content Warning`, `Attachment 1`,
  /// `Link (https://...)`, or `Referenced Message (@user)`.
  final String location;

  /// E.g., `Implicit Gender Bias`, `Implicit Racial Bias`, `Gender-Exclusive Language`.
  final String biasType;

  /// Concise explanation of why the content may exhibit racial or gender bias.
  final String explanation;

  /// Optional offending snippet or phrase.
  final String? excerpt;

  factory BiasFinding.fromJson(Map<String, dynamic> json) {
    final location = jsonString(json['location'])?.trim() ?? '';
    return BiasFinding(
      location: location.isNotEmpty ? location : 'Post Text',
      biasType: jsonString(json['bias_type']) ??
          jsonString(json['biasType']) ??
          'Potential Racial or Gender Bias',
      explanation: jsonString(json['explanation']) ?? '',
      excerpt: jsonString(json['excerpt']),
    );
  }
}

/// Result returned by the pre-post racial and gender bias checker.
class BiasCheckResult {
  const BiasCheckResult({
    required this.hasBias,
    required this.summary,
    required this.checkedComponents,
    required this.findings,
    this.suggestedAlternateWording,
    this.usedLocalFallback = false,
  });

  final bool hasBias;
  final String summary;
  final List<String> checkedComponents;
  final List<BiasFinding> findings;

  /// Populated when the main post text itself has bias and can be rewritten more inclusively.
  final String? suggestedAlternateWording;

  /// True when the result came from the deterministic local heuristic fallback.
  final bool usedLocalFallback;

  static const BiasCheckResult clean = BiasCheckResult(
    hasBias: false,
    summary: 'No racial or gender bias detected.',
    checkedComponents: [],
    findings: [],
  );
}

/// Extracted metadata and text excerpt from an external URL in the post.
class LinkedPageExcerpt {
  const LinkedPageExcerpt({
    required this.url,
    required this.title,
    required this.metaDescription,
    required this.textExcerpt,
  });

  final String url;
  final String title;
  final String metaDescription;
  final String textExcerpt;

  String toPromptText() {
    final parts = <String>[
      if (title.isNotEmpty) 'Title: $title',
      if (metaDescription.isNotEmpty) 'Description: $metaDescription',
      if (textExcerpt.isNotEmpty) 'Excerpt: $textExcerpt',
    ];
    return parts.join('\n');
  }
}

/// Context for a replied-to or referenced Mastodon status.
class ReferencedStatusContext {
  const ReferencedStatusContext({
    required this.authorHandle,
    required this.contentText,
    this.spoilerText = '',
    this.mediaAltTexts = const [],
    this.sourceUrl,
  });

  final String authorHandle;
  final String contentText;
  final String spoilerText;
  final List<String> mediaAltTexts;
  final String? sourceUrl;

  /// Builds a [ReferencedStatusContext] from a Mastodon status (unwrapping
  /// boosts via [MastodonStatus.displayStatus]).
  factory ReferencedStatusContext.fromStatus(
    MastodonStatus status, {
    String? sourceUrl,
  }) {
    final target = status.displayStatus;
    return ReferencedStatusContext(
      authorHandle: target.account.acct,
      contentText: target.plainText,
      spoilerText: target.spoilerText,
      mediaAltTexts: target.mediaAttachments
          .map((m) => (m.description ?? '').trim())
          .where((d) => d.isNotEmpty)
          .toList(),
      sourceUrl: sourceUrl ?? target.permalinkUrl,
    );
  }

  String get locationLabel => 'Referenced Message (@$authorHandle)';
}

/// Visual attachment context supplied to the bias checker.
class BiasAttachmentInput {
  const BiasAttachmentInput({
    required this.index,
    required this.altText,
    required this.isVideo,
    this.visualFrames = const [],
  });

  /// 1-based attachment index (`Attachment 1`, `Attachment 2`, ...).
  final int index;
  final String altText;
  final bool isVideo;
  final List<MediaBinaryPayload> visualFrames;
}

/// Complete input bundle for the pre-post bias check.
class BiasCheckInput {
  const BiasCheckInput({
    required this.postText,
    this.spoilerText = '',
    this.attachments = const [],
    this.referencedStatuses = const [],
  });

  final String postText;
  final String spoilerText;
  final List<BiasAttachmentInput> attachments;
  final List<ReferencedStatusContext> referencedStatuses;
}
