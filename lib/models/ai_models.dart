// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'dart:typed_data';

/// Supported AI vision and language providers.
enum AiProviderType {
  gemini('gemini', 'Google Gemini API'),
  openai('openai', 'OpenAI / Compatible API'),
  anthropic('anthropic', 'Anthropic Claude API'),
  local('local', 'Local (Ollama / LM Studio / On-Device Fallback)');

  const AiProviderType(this.id, this.displayName);

  final String id;
  final String displayName;

  static AiProviderType fromId(String? id) {
    return AiProviderType.values.firstWhere(
      (e) => e.id == id,
      orElse: () => AiProviderType.gemini,
    );
  }
}

/// Detail level for AI-generated image and video alt-text descriptions.
enum CaptionDetailLevel {
  concise(
    'concise',
    'Concise',
    '1-2 sentences (150-300 characters)',
    150,
    300,
  ),
  descriptive(
    'descriptive',
    'Descriptive',
    '2-4 sentences (300-700 characters)',
    300,
    700,
  ),
  detailed(
    'detailed',
    'Detailed',
    'Comprehensive (600-1200 characters) including layout, lighting, colors, and full text transcription',
    600,
    1200,
  );

  const CaptionDetailLevel(
    this.id,
    this.label,
    this.guidance,
    this.minTargetChars,
    this.maxTargetChars,
  );

  final String id;
  final String label;
  final String guidance;
  final int minTargetChars;
  final int maxTargetChars;

  static CaptionDetailLevel fromId(String? id) {
    return CaptionDetailLevel.values.firstWhere(
      (e) => e.id == id,
      orElse: () => CaptionDetailLevel.descriptive,
    );
  }
}

/// Model option rendered inside the Settings model drop-down picker.
class AiModelOption {
  const AiModelOption({
    required this.id,
    required this.displayName,
    this.supportsVision = true,
  });

  final String id;
  final String displayName;
  final bool supportsVision;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiModelOption &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Binary image or video payload passed to an AI provider.
class MediaBinaryPayload {
  const MediaBinaryPayload({
    required this.bytes,
    required this.mimeType,
    this.isVideo = false,
  });

  final Uint8List bytes;
  final String mimeType;
  final bool isVideo;
}
