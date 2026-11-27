// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import '../../core/language/language_pack_registry.dart';
import '../../core/language/language_registry.dart';
import '../../models/ai_models.dart';

/// Constructs screen-reader accessibility prompts for image and video alt-text generation.
class AiPromptBuilder {
  AiPromptBuilder._();

  static const String altTextSystemPrompt =
      'You are an expert accessibility specialist writing alt-text descriptions for blind and low-vision screen-reader users on Mastodon. Output ONLY the description text with no preamble, no quotes, and no markdown formatting.';

  /// Builds the user prompt instructing an AI vision model how to describe an
  /// image, inline video, or sequence of extracted video keyframes.
  static String buildAltTextPrompt({
    required bool isVideo,
    required bool isInlineVideo,
    required int frameCount,
    required CaptionDetailLevel detailLevel,
    required String language,
    String? postContext,
    String? customInstructions,
    required int maxLength,
  }) {
    final trimmedLanguage = language.trim();
    final pack = LanguagePackRegistry.captionPackFor(trimmedLanguage);
    final outputLanguage = trimmedLanguage.isEmpty
        ? 'English'
        : (LanguageRegistry.resolve(trimmedLanguage)?.englishName ??
              trimmedLanguage);

    final prefixBudget = maxLength - pack.captionPrefix.length;
    final bodyMaxChars = prefixBudget > 0 ? prefixBudget : maxLength;
    final forbiddenExamples = pack.forbiddenPrefixExamples.isNotEmpty
        ? pack.forbiddenPrefixExamples
        : [
            if (pack.captionPrefix.trim().isNotEmpty) pack.captionPrefix.trim(),
            'Alt text:',
          ];
    final formattedForbidden = forbiddenExamples.map((e) => '"$e"').join(', ');

    final buffer = StringBuffer();
    buffer.writeln(
      'Write an accessible alt-text description for a blind or low-vision screen-reader user.',
    );

    if (isVideo) {
      if (isInlineVideo) {
        buffer.writeln(
          'Analyze this video clip and synthesize the motion, actions, scene transitions, setting, emotional tone, and narrative progression into a cohesive description.',
        );
      } else {
        buffer.writeln(
          'These $frameCount evenly spaced keyframes come sequentially from a video. Synthesize them into one cohesive description of the motion, narrative progression, and scene changes rather than listing frames one by one.',
        );
      }
    } else {
      buffer.writeln(
        'Describe the primary subject, action, setting, emotional tone, and important visual details clearly and objectively.',
      );
    }

    buffer.writeln(
      'Transcribe any visible text (signs, screenshots, memes, captions, labels) verbatim.',
    );
    buffer.writeln(
      'Detail level (${detailLevel.label}): ${detailLevel.guidance}.',
    );
    buffer.writeln('Output language: $outputLanguage.');
    buffer.writeln('Keep the description under $bodyMaxChars characters.');
    buffer.writeln(
      'Do NOT include prefixes like $formattedForbidden and do NOT wrap your answer in quotation marks.',
    );

    if (postContext != null && postContext.trim().isNotEmpty) {
      buffer.writeln(
        'Helpful context from the author\'s draft post (use for names/subjects only, do not merely repeat the post): "${postContext.trim()}"',
      );
    }

    if (customInstructions != null && customInstructions.trim().isNotEmpty) {
      buffer.writeln('User custom instructions: ${customInstructions.trim()}');
    }

    return buffer.toString().trim();
  }
}
