// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../core/media_utils.dart';
import '../models/ai_models.dart';
import '../models/app_settings.dart';
import 'ai/ai_http_adapters.dart';
import 'ai/ai_model_catalog.dart';
import 'ai/ai_prompt_builder.dart';
import 'caption_formatter.dart';
import 'on_device_ai_service.dart';
import 'video_frame_extractor.dart';

export 'ai/ai_http_adapters.dart' show AiProviderException;

/// High-level facade coordinating dynamic model discovery, accessible image/video
/// alt-text generation, and multimodal prompting across On-Device OS AI
/// (Apple Foundation Models & Google Gemini Nano via ML Kit GenAI), Google Gemini,
/// OpenAI-compatible, Anthropic Claude, and Local LAN (Ollama / LM Studio) servers.
class AiProviderService {
  AiProviderService({
    http.Client? client,
    VideoFrameExtractor? videoFrameExtractor,
    OnDeviceAiService? onDeviceAiService,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       _videoFrameExtractor =
           videoFrameExtractor ?? const VideoFrameExtractor(),
       _onDeviceAi = onDeviceAiService ?? OnDeviceAiService() {
    _catalog = AiModelCatalog(_client);
    _adapters = AiHttpAdapters(_client);
  }

  final http.Client _client;
  final bool _ownsClient;
  final VideoFrameExtractor _videoFrameExtractor;
  final OnDeviceAiService _onDeviceAi;
  late final AiModelCatalog _catalog;
  late final AiHttpAdapters _adapters;

  /// Sorts model options alphabetically (case-insensitive by display name, then ID).
  static List<AiModelOption> sortAlphabetically(
    Iterable<AiModelOption> models,
  ) => AiModelCatalog.sortAlphabetically(models);

  /// Sensible fallback vision models (sorted alphabetically) when offline or
  /// before API credentials are provided.
  static List<AiModelOption> defaultModelsFor(AiProviderType provider) =>
      AiModelCatalog.defaultModelsFor(provider);

  /// Dynamically queries the selected provider's models endpoint and returns
  /// them sorted alphabetically. Falls back to [defaultModelsFor] if offline.
  Future<List<AiModelOption>> fetchAvailableModels({
    required AiProviderType provider,
    required AppSettings settings,
    required AiCredentials credentials,
  }) => _catalog.fetchAvailableModels(
    provider: provider,
    settings: settings,
    credentials: credentials,
  );

  /// Builds the screen-reader accessibility prompt for images and videos.
  String buildAltTextPrompt({
    required bool isVideo,
    required bool isInlineVideo,
    required int frameCount,
    required CaptionDetailLevel detailLevel,
    required String language,
    String? postContext,
    String? customInstructions,
    required int maxLength,
  }) => AiPromptBuilder.buildAltTextPrompt(
    isVideo: isVideo,
    isInlineVideo: isInlineVideo,
    frameCount: frameCount,
    detailLevel: detailLevel,
    language: language,
    postContext: postContext,
    customInstructions: customInstructions,
    maxLength: maxLength,
  );

  /// Generates an accessible alt-text description for an image or video,
  /// automatically enforcing the mandatory prefix and server character limit.
  Future<String> generateAltText({
    required AppSettings settings,
    required AiCredentials credentials,
    required bool isVideo,
    required CaptionDetailLevel detailLevel,
    required int maxAltTextLength,
    String? localFilePath,
    List<MediaBinaryPayload> preExtractedMedia = const [],
    String? mimeType,
    String? draftPostContext,
  }) async {
    if (settings.activeProvider == AiProviderType.none) {
      throw const AiProviderException(
        'AI is currently set to "No AI". Select an AI provider in Settings to generate alt-text automatically.',
      );
    }

    final mediaPayloads = await _prepareMediaPayloads(
      settings: settings,
      isVideo: isVideo,
      localFilePath: localFilePath,
      preExtractedMedia: preExtractedMedia,
      mimeType: mimeType,
    );

    if (mediaPayloads.isEmpty) {
      throw const AiProviderException(
        'Unable to read media bytes for AI analysis.',
      );
    }

    final prompt = buildAltTextPrompt(
      isVideo: isVideo,
      isInlineVideo: mediaPayloads.any((m) => m.isVideo),
      frameCount: mediaPayloads.length,
      detailLevel: detailLevel,
      language: settings.language,
      postContext: settings.includePostContext ? draftPostContext : null,
      customInstructions: settings.customInstructions,
      maxLength: maxAltTextLength,
    );

    if (settings.activeProvider == AiProviderType.onDevice) {
      final imageFrames = mediaPayloads
          .where((m) => !m.isVideo)
          .map((m) => m.bytes)
          .toList();
      if (imageFrames.isEmpty) {
        throw const AiProviderException(
          'On-device AI requires extracted image frames to describe this media.',
        );
      }
      try {
        final String rawOnDevice;
        if (isVideo && imageFrames.length > 1) {
          rawOnDevice = await _onDeviceAi.describeVideoKeyframes(
            keyframes: imageFrames,
            framePrompt: prompt,
            synthesisPromptTemplate: prompt,
            selectedModel: settings.onDeviceModel,
          );
        } else {
          rawOnDevice = await _onDeviceAi.describeImage(
            imageBytes: imageFrames.first,
            prompt: prompt,
            selectedModel: settings.onDeviceModel,
          );
        }
        return CaptionFormatter.format(
          rawOnDevice,
          maxLength: maxAltTextLength,
          language: settings.language,
        );
      } catch (e) {
        throw AiProviderException('On-device AI error: $e');
      }
    }

    final rawResponse = await runMultimodalPrompt(
      settings: settings,
      credentials: credentials,
      systemPrompt: AiPromptBuilder.altTextSystemPrompt,
      userPrompt: prompt,
      media: mediaPayloads,
    );

    return CaptionFormatter.format(
      rawResponse,
      maxLength: maxAltTextLength,
      language: settings.language,
    );
  }

  /// Executes a text or multimodal prompt against the currently configured AI provider.
  Future<String> runMultimodalPrompt({
    required AppSettings settings,
    required AiCredentials credentials,
    required String systemPrompt,
    required String userPrompt,
    List<MediaBinaryPayload> media = const [],
    bool expectJson = false,
  }) async {
    switch (settings.activeProvider) {
      case AiProviderType.onDevice:
        final firstImage = media.where((m) => !m.isVideo).firstOrNull?.bytes;
        try {
          return await _onDeviceAi.runPrompt(
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            imageBytes: firstImage,
          );
        } catch (e) {
          throw AiProviderException('On-device AI error: $e');
        }
      case AiProviderType.gemini:
        return _adapters.callGemini(
          apiKey: credentials.geminiApiKey,
          model: settings.geminiModel,
          systemPrompt: systemPrompt,
          userPrompt: userPrompt,
          media: media,
          expectJson: expectJson,
        );
      case AiProviderType.openai:
        return _adapters.callOpenAiCompatible(
          baseUrl: settings.openAiBaseUrl,
          apiKey: credentials.openAiApiKey,
          model: settings.openAiModel,
          systemPrompt: systemPrompt,
          userPrompt: userPrompt,
          media: media,
          expectJson: expectJson,
        );
      case AiProviderType.anthropic:
        return _adapters.callAnthropic(
          apiKey: credentials.anthropicApiKey,
          model: settings.anthropicModel,
          systemPrompt: systemPrompt,
          userPrompt: userPrompt,
          media: media,
        );
      case AiProviderType.local:
        return _adapters.callLocal(
          baseUrl: settings.localBaseUrl,
          apiKey: credentials.localApiKey,
          model: settings.localModel,
          systemPrompt: systemPrompt,
          userPrompt: userPrompt,
          media: media,
          expectJson: expectJson,
        );
      case AiProviderType.none:
        throw const AiProviderException(
          'AI is disabled ("No AI"). Enable an AI provider in Settings to use AI features.',
        );
    }
  }

  /// Closes the internally owned HTTP client (no-op if an external client was injected).
  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }

  Future<List<MediaBinaryPayload>> _prepareMediaPayloads({
    required AppSettings settings,
    required bool isVideo,
    required String? localFilePath,
    required List<MediaBinaryPayload> preExtractedMedia,
    required String? mimeType,
  }) async {
    if (preExtractedMedia.isNotEmpty) {
      return preExtractedMedia;
    }
    if (localFilePath == null || localFilePath.isEmpty) {
      return const [];
    }

    final file = File(localFilePath);
    if (!await file.exists()) {
      return const [];
    }

    if (!isVideo) {
      final bytes = await file.readAsBytes();
      return [
        MediaBinaryPayload(
          bytes: bytes,
          mimeType:
              mimeType ??
              MediaUtils.guessMimeType(localFilePath, isVideo: false),
          isVideo: false,
        ),
      ];
    }

    // For Google Gemini: send inline video directly when within payload limit.
    final fileSize = await file.length();
    if (settings.activeProvider == AiProviderType.gemini &&
        fileSize > 0 &&
        fileSize <= AppConstants.geminiInlineVideoMaxBytes) {
      final bytes = await file.readAsBytes();
      return [
        MediaBinaryPayload(
          bytes: bytes,
          mimeType:
              mimeType ??
              MediaUtils.guessMimeType(localFilePath, isVideo: true),
          isVideo: true,
        ),
      ];
    }

    // Fallback to evenly spaced extracted keyframes for larger videos or frame-based providers.
    return _videoFrameExtractor.extractKeyframes(
      localFilePath,
      frameCount: settings.videoKeyframeCount,
    );
  }
}
