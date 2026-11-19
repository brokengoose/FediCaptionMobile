// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../models/ai_models.dart';
import '../models/app_settings.dart';
import 'caption_formatter.dart';
import 'video_frame_extractor.dart';

class AiProviderException implements Exception {
  const AiProviderException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Handles dynamic model discovery, accessible image/video alt-text generation,
/// and multimodal text+image analysis across Gemini, OpenAI-compatible, Anthropic,
/// and Local (Ollama / LM Studio LAN) endpoints.
class AiProviderService {
  AiProviderService({
    http.Client? client,
    VideoFrameExtractor? videoFrameExtractor,
  })  : _client = client ?? http.Client(),
        _videoFrameExtractor = videoFrameExtractor ?? const VideoFrameExtractor();

  final http.Client _client;
  final VideoFrameExtractor _videoFrameExtractor;

  /// Sorts model options alphabetically (case-insensitive by display name, then ID).
  static List<AiModelOption> sortAlphabetically(Iterable<AiModelOption> models) {
    final sorted = List<AiModelOption>.from(models);
    sorted.sort((a, b) {
      final byName =
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
      if (byName != 0) return byName;
      return a.id.toLowerCase().compareTo(b.id.toLowerCase());
    });
    return sorted;
  }

  /// Sensible fallback vision models (sorted alphabetically) when offline or
  /// before API credentials are provided.
  static List<AiModelOption> defaultModelsFor(AiProviderType provider) {
    final List<AiModelOption> models;
    switch (provider) {
      case AiProviderType.gemini:
        models = const [
          AiModelOption(id: 'gemini-1.5-pro', displayName: 'Gemini 1.5 Pro'),
          AiModelOption(id: 'gemini-2.0-flash', displayName: 'Gemini 2.0 Flash'),
          AiModelOption(id: 'gemini-2.5-flash', displayName: 'Gemini 2.5 Flash'),
          AiModelOption(id: 'gemini-2.5-pro', displayName: 'Gemini 2.5 Pro'),
        ];
      case AiProviderType.openai:
        models = const [
          AiModelOption(id: 'gpt-4.1', displayName: 'GPT-4.1'),
          AiModelOption(id: 'gpt-4.1-mini', displayName: 'GPT-4.1 mini'),
          AiModelOption(id: 'gpt-4o', displayName: 'GPT-4o'),
          AiModelOption(id: 'gpt-4o-mini', displayName: 'GPT-4o mini'),
        ];
      case AiProviderType.anthropic:
        models = const [
          AiModelOption(
            id: 'claude-3-5-haiku-latest',
            displayName: 'Claude 3.5 Haiku',
          ),
          AiModelOption(
            id: 'claude-3-7-sonnet-latest',
            displayName: 'Claude 3.7 Sonnet',
          ),
          AiModelOption(
            id: 'claude-sonnet-4-20250514',
            displayName: 'Claude Sonnet 4',
          ),
        ];
      case AiProviderType.local:
        models = const [
          AiModelOption(id: 'gemma3', displayName: 'Gemma 3 (Ollama/LAN)'),
          AiModelOption(
            id: 'llama3.2-vision',
            displayName: 'Llama 3.2 Vision (Ollama/LAN)',
          ),
          AiModelOption(id: 'llava', displayName: 'LLaVA (Ollama/LAN)'),
          AiModelOption(
            id: 'minicpm-v',
            displayName: 'MiniCPM-V (Ollama/LAN)',
          ),
          AiModelOption(
            id: 'on-device-fallback',
            displayName: 'On-Device Fallback (Heuristics Only)',
            supportsVision: false,
          ),
          AiModelOption(
            id: 'qwen2.5vl',
            displayName: 'Qwen 2.5 VL (Ollama/LAN)',
          ),
        ];
      case AiProviderType.none:
        return const [];
    }
    return sortAlphabetically(models);
  }

  /// Dynamically queries the selected provider's models endpoint and returns
  /// them sorted alphabetically. Falls back to [defaultModelsFor] if offline.
  Future<List<AiModelOption>> fetchAvailableModels({
    required AiProviderType provider,
    required AppSettings settings,
    required AiCredentials credentials,
  }) async {
    if (provider == AiProviderType.none) {
      return const [];
    }
    try {
      final fetched = switch (provider) {
        AiProviderType.gemini => await _fetchGeminiModels(credentials.geminiApiKey),
        AiProviderType.openai => await _fetchOpenAiModels(
            baseUrl: settings.openAiBaseUrl,
            apiKey: credentials.openAiApiKey,
          ),
        AiProviderType.anthropic =>
            await _fetchAnthropicModels(credentials.anthropicApiKey),
        AiProviderType.local => await _fetchLocalModels(
            baseUrl: settings.localBaseUrl,
            apiKey: credentials.localApiKey,
          ),
        AiProviderType.none => const <AiModelOption>[],
      };
      if (fetched.isNotEmpty) {
        return sortAlphabetically(fetched);
      }
    } catch (_) {
      // Fall back to curated defaults if unreachable or unconfigured.
    }
    return defaultModelsFor(provider);
  }

  Future<List<AiModelOption>> _fetchGeminiModels(String apiKey) async {
    final trimmed = apiKey.trim();
    if (trimmed.isEmpty) return const [];

    final uri = Uri.parse(
      '${AppConstants.geminiBaseUrl}/models?key=${Uri.encodeQueryComponent(trimmed)}',
    );
    final res = await _client.get(uri).timeout(const Duration(seconds: 12));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw AiProviderException('Gemini models error (${res.statusCode})');
    }

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final rawModels = (decoded['models'] as List<dynamic>?) ?? const [];
    final results = <AiModelOption>[];

    for (final item in rawModels.whereType<Map<String, dynamic>>()) {
      final methods = (item['supportedGenerationMethods'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [];
      if (!methods.contains('generateContent')) continue;

      final fullName = (item['name'] as String?) ?? '';
      final id = fullName.startsWith('models/')
          ? fullName.substring('models/'.length)
          : fullName;
      if (id.isEmpty) continue;
      if (id.contains('embedding') || id.contains('aqa')) continue;

      final displayName = (item['displayName'] as String?)?.trim();
      results.add(
        AiModelOption(
          id: id,
          displayName: (displayName != null && displayName.isNotEmpty)
              ? '$displayName ($id)'
              : id,
        ),
      );
    }

    return sortAlphabetically(results);
  }

  Future<List<AiModelOption>> _fetchOpenAiModels({
    required String baseUrl,
    required String apiKey,
  }) async {
    final normalizedBase = _normalizeBaseUrl(
      baseUrl,
      fallback: AppConstants.openAiDefaultBaseUrl,
    );
    final isOfficialOpenAi = normalizedBase.contains('api.openai.com');
    if (isOfficialOpenAi && apiKey.trim().isEmpty) {
      return const [];
    }

    final headers = <String, String>{
      'Accept': 'application/json',
      if (apiKey.trim().isNotEmpty) 'Authorization': 'Bearer ${apiKey.trim()}',
    };
    final res = await _client
        .get(Uri.parse('$normalizedBase/models'), headers: headers)
        .timeout(const Duration(seconds: 12));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw AiProviderException('OpenAI models error (${res.statusCode})');
    }

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final data = (decoded['data'] as List<dynamic>?) ?? const [];
    final results = <AiModelOption>[];

    for (final item in data.whereType<Map<String, dynamic>>()) {
      final id = (item['id'] as String?)?.trim() ?? '';
      if (id.isEmpty) continue;
      if (isOfficialOpenAi && _isNonChatOpenAiUtilityModel(id)) {
        continue;
      }
      results.add(AiModelOption(id: id, displayName: id));
    }

    return sortAlphabetically(results);
  }

  bool _isNonChatOpenAiUtilityModel(String id) {
    final lower = id.toLowerCase();
    const excluded = [
      'whisper',
      'tts',
      'embedding',
      'dall-e',
      'moderation',
      'babbage',
      'davinci',
      'curie',
      'ada',
      'realtime',
      'transcribe',
      'audio',
      'sora',
      'gpt-image',
    ];
    return excluded.any(lower.contains);
  }

  Future<List<AiModelOption>> _fetchAnthropicModels(String apiKey) async {
    final trimmed = apiKey.trim();
    if (trimmed.isEmpty) return const [];

    final res = await _client
        .get(
          Uri.parse('${AppConstants.anthropicBaseUrl}/models'),
          headers: {
            'x-api-key': trimmed,
            'anthropic-version': AppConstants.anthropicVersion,
            'Accept': 'application/json',
          },
        )
        .timeout(const Duration(seconds: 12));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw AiProviderException('Anthropic models error (${res.statusCode})');
    }

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final data = (decoded['data'] as List<dynamic>?) ?? const [];
    return data.whereType<Map<String, dynamic>>().map((item) {
      final id = (item['id'] as String?) ?? '';
      final displayName = (item['display_name'] as String?)?.trim();
      return AiModelOption(
        id: id,
        displayName: (displayName != null && displayName.isNotEmpty)
            ? '$displayName ($id)'
            : id,
      );
    }).where((m) => m.id.isNotEmpty).toList();
  }

  /// Queries Ollama (`/api/tags`) first, then OpenAI-compatible LM Studio (`/v1/models`).
  Future<List<AiModelOption>> _fetchLocalModels({
    required String baseUrl,
    required String apiKey,
  }) async {
    final normalizedBase = _normalizeBaseUrl(
      baseUrl,
      fallback: AppConstants.localDefaultBaseUrl,
    );
    final results = <AiModelOption>[];

    // 1. Try Ollama native /api/tags
    try {
      final ollamaBase = normalizedBase.endsWith('/v1')
          ? normalizedBase.substring(0, normalizedBase.length - 3)
          : normalizedBase;
      final res = await _client
          .get(Uri.parse('$ollamaBase/api/tags'))
          .timeout(const Duration(seconds: 6));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(res.body) as Map<String, dynamic>;
        final models = (decoded['models'] as List<dynamic>?) ?? const [];
        for (final item in models.whereType<Map<String, dynamic>>()) {
          final name = (item['name'] as String?)?.trim() ?? '';
          if (name.isEmpty) continue;
          results.add(AiModelOption(id: name, displayName: name));
        }
      }
    } catch (_) {
      // Try OpenAI-compatible endpoint below.
    }

    // 2. Fallback to LM Studio / vLLM / llama.cpp OpenAI-compatible /v1/models
    if (results.isEmpty) {
      try {
        final v1Base = normalizedBase.endsWith('/v1')
            ? normalizedBase
            : '$normalizedBase/v1';
        final fetched = await _fetchOpenAiModels(baseUrl: v1Base, apiKey: apiKey);
        results.addAll(fetched);
      } catch (_) {
        // Ignore and return fallback below.
      }
    }

    if (results.isNotEmpty) {
      results.add(
        const AiModelOption(
          id: 'on-device-fallback',
          displayName: 'On-Device Fallback (Heuristics Only)',
          supportsVision: false,
        ),
      );
      return sortAlphabetically(results);
    }

    return results;
  }

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
    if (settings.activeProvider == AiProviderType.local &&
        settings.localModel == 'on-device-fallback') {
      throw const AiProviderException(
        'On-device fallback does not run vision captioning. Configure an Ollama/LM Studio LAN server or cloud AI provider in Settings.',
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
      throw const AiProviderException('Unable to read media bytes for AI analysis.');
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

    final rawResponse = await runMultimodalPrompt(
      settings: settings,
      credentials: credentials,
      systemPrompt:
          'You are an expert accessibility specialist writing alt-text descriptions for blind and low-vision screen-reader users on Mastodon. Output ONLY the description text with no preamble, no quotes, and no markdown formatting.',
      userPrompt: prompt,
      media: mediaPayloads,
    );

    return CaptionFormatter.format(
      rawResponse,
      maxLength: maxAltTextLength,
    );
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
          mimeType: mimeType ?? _guessMimeType(localFilePath, isVideo: false),
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
          mimeType: mimeType ?? _guessMimeType(localFilePath, isVideo: true),
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
  }) {
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
    buffer.writeln('Detail level (${detailLevel.label}): ${detailLevel.guidance}.');
    buffer.writeln(
      'Output language: ${language.trim().isEmpty ? 'English' : language.trim()}.',
    );
    buffer.writeln(
      'Keep the description under ${maxLength - AppConstants.aiCaptionPrefix.length} characters.',
    );
    buffer.writeln(
      'Do NOT include prefixes like "Image of", "Photo of", "Video of", "Alt text:", or "AI generated description:" and do NOT wrap your answer in quotation marks.',
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
      case AiProviderType.gemini:
        return _callGemini(
          apiKey: credentials.geminiApiKey,
          model: settings.geminiModel,
          systemPrompt: systemPrompt,
          userPrompt: userPrompt,
          media: media,
          expectJson: expectJson,
        );
      case AiProviderType.openai:
        return _callOpenAiCompatible(
          baseUrl: settings.openAiBaseUrl,
          apiKey: credentials.openAiApiKey,
          model: settings.openAiModel,
          systemPrompt: systemPrompt,
          userPrompt: userPrompt,
          media: media,
          expectJson: expectJson,
        );
      case AiProviderType.anthropic:
        return _callAnthropic(
          apiKey: credentials.anthropicApiKey,
          model: settings.anthropicModel,
          systemPrompt: systemPrompt,
          userPrompt: userPrompt,
          media: media,
        );
      case AiProviderType.local:
        return _callLocal(
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

  Future<String> _callGemini({
    required String apiKey,
    required String model,
    required String systemPrompt,
    required String userPrompt,
    required List<MediaBinaryPayload> media,
    required bool expectJson,
  }) async {
    final key = apiKey.trim();
    if (key.isEmpty) {
      throw const AiProviderException(
        'Google Gemini API key is not configured. Add it in Settings.',
      );
    }

    final cleanModel = model.startsWith('models/')
        ? model.substring('models/'.length)
        : model;
    final uri = Uri.parse(
      '${AppConstants.geminiBaseUrl}/models/$cleanModel:generateContent?key=${Uri.encodeQueryComponent(key)}',
    );

    final parts = <Map<String, dynamic>>[
      {'text': userPrompt},
      for (final item in media)
        {
          'inline_data': {
            'mime_type': item.mimeType,
            'data': base64Encode(item.bytes),
          },
        },
    ];

    final body = <String, dynamic>{
      'systemInstruction': {
        'parts': [
          {'text': systemPrompt},
        ],
      },
      'contents': [
        {
          'role': 'user',
          'parts': parts,
        },
      ],
      if (expectJson)
        'generationConfig': {
          'responseMimeType': 'application/json',
        },
    };

    final res = await _client
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 60));

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw AiProviderException(
        'Gemini API error (${res.statusCode}): ${_extractErrorMessage(res.body)}',
      );
    }

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final candidates = (decoded['candidates'] as List<dynamic>?) ?? const [];
    if (candidates.isEmpty) {
      throw const AiProviderException('Gemini returned no response candidates.');
    }
    final content = (candidates.first as Map<String, dynamic>)['content']
        as Map<String, dynamic>?;
    final outParts = (content?['parts'] as List<dynamic>?) ?? const [];
    final text = outParts
        .whereType<Map<String, dynamic>>()
        .map((p) => (p['text'] as String?) ?? '')
        .join('\n')
        .trim();

    if (text.isEmpty) {
      throw const AiProviderException('Gemini returned an empty response.');
    }
    return text;
  }

  Future<String> _callOpenAiCompatible({
    required String baseUrl,
    required String apiKey,
    required String model,
    required String systemPrompt,
    required String userPrompt,
    required List<MediaBinaryPayload> media,
    required bool expectJson,
  }) async {
    final normalizedBase = _normalizeBaseUrl(
      baseUrl,
      fallback: AppConstants.openAiDefaultBaseUrl,
    );
    if (normalizedBase.contains('api.openai.com') && apiKey.trim().isEmpty) {
      throw const AiProviderException(
        'OpenAI API key is not configured. Add it in Settings.',
      );
    }

    final userContent = <Map<String, dynamic>>[
      {'type': 'text', 'text': userPrompt},
      for (final item in media.where((m) => !m.isVideo))
        {
          'type': 'image_url',
          'image_url': {
            'url': 'data:${item.mimeType};base64,${base64Encode(item.bytes)}',
          },
        },
    ];

    final body = <String, dynamic>{
      'model': model,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {
          'role': 'user',
          'content': userContent.length == 1 ? userPrompt : userContent,
        },
      ],
      if (expectJson && normalizedBase.contains('api.openai.com'))
        'response_format': {'type': 'json_object'},
    };

    final res = await _client
        .post(
          Uri.parse('$normalizedBase/chat/completions'),
          headers: {
            'Content-Type': 'application/json',
            if (apiKey.trim().isNotEmpty)
              'Authorization': 'Bearer ${apiKey.trim()}',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 60));

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw AiProviderException(
        'OpenAI-compatible API error (${res.statusCode}): ${_extractErrorMessage(res.body)}',
      );
    }

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final choices = (decoded['choices'] as List<dynamic>?) ?? const [];
    if (choices.isEmpty) {
      throw const AiProviderException('Provider returned no choices.');
    }
    final message = (choices.first as Map<String, dynamic>)['message']
        as Map<String, dynamic>?;
    final content = (message?['content'] as String?)?.trim() ?? '';
    if (content.isEmpty) {
      throw const AiProviderException('Provider returned an empty message.');
    }
    return content;
  }

  Future<String> _callAnthropic({
    required String apiKey,
    required String model,
    required String systemPrompt,
    required String userPrompt,
    required List<MediaBinaryPayload> media,
  }) async {
    final key = apiKey.trim();
    if (key.isEmpty) {
      throw const AiProviderException(
        'Anthropic API key is not configured. Add it in Settings.',
      );
    }

    final contentBlocks = <Map<String, dynamic>>[
      for (final item in media.where((m) => !m.isVideo))
        {
          'type': 'image',
          'source': {
            'type': 'base64',
            'media_type': item.mimeType,
            'data': base64Encode(item.bytes),
          },
        },
      {'type': 'text', 'text': userPrompt},
    ];

    final body = <String, dynamic>{
      'model': model,
      'max_tokens': 1024,
      'system': systemPrompt,
      'messages': [
        {
          'role': 'user',
          'content': contentBlocks,
        },
      ],
    };

    final res = await _client
        .post(
          Uri.parse('${AppConstants.anthropicBaseUrl}/messages'),
          headers: {
            'Content-Type': 'application/json',
            'x-api-key': key,
            'anthropic-version': AppConstants.anthropicVersion,
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 60));

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw AiProviderException(
        'Anthropic API error (${res.statusCode}): ${_extractErrorMessage(res.body)}',
      );
    }

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final blocks = (decoded['content'] as List<dynamic>?) ?? const [];
    final text = blocks
        .whereType<Map<String, dynamic>>()
        .where((b) => b['type'] == 'text')
        .map((b) => (b['text'] as String?) ?? '')
        .join('\n')
        .trim();
    if (text.isEmpty) {
      throw const AiProviderException('Anthropic returned an empty response.');
    }
    return text;
  }

  /// Calls local Ollama (`/api/chat`) first, falling back to OpenAI-compatible LM Studio (`/v1/chat/completions`).
  Future<String> _callLocal({
    required String baseUrl,
    required String apiKey,
    required String model,
    required String systemPrompt,
    required String userPrompt,
    required List<MediaBinaryPayload> media,
    required bool expectJson,
  }) async {
    if (model == 'on-device-fallback') {
      throw const AiProviderException(
        'On-device fallback selected; using local heuristics.',
      );
    }

    final normalizedBase = _normalizeBaseUrl(
      baseUrl,
      fallback: AppConstants.localDefaultBaseUrl,
    );

    // If URL ends in /v1, directly use OpenAI-compatible chat completions (LM Studio / llama.cpp / vLLM).
    if (normalizedBase.endsWith('/v1')) {
      return _callOpenAiCompatible(
        baseUrl: normalizedBase,
        apiKey: apiKey,
        model: model,
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        media: media,
        expectJson: expectJson,
      );
    }

    // Try Ollama /api/chat first.
    final imagesBase64 = media
        .where((m) => !m.isVideo)
        .map((m) => base64Encode(m.bytes))
        .toList();

    final ollamaBody = <String, dynamic>{
      'model': model,
      'stream': false,
      if (expectJson) 'format': 'json',
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {
          'role': 'user',
          'content': userPrompt,
          if (imagesBase64.isNotEmpty) 'images': imagesBase64,
        },
      ],
    };

    try {
      final res = await _client
          .post(
            Uri.parse('$normalizedBase/api/chat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(ollamaBody),
          )
          .timeout(const Duration(seconds: 90));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(res.body) as Map<String, dynamic>;
        final msg = decoded['message'] as Map<String, dynamic>?;
        final content = (msg?['content'] as String?)?.trim() ?? '';
        if (content.isNotEmpty) {
          return content;
        }
      }
    } catch (_) {
      // Fall through to LM Studio / OpenAI-compatible /v1 endpoint.
    }

    return _callOpenAiCompatible(
      baseUrl: '$normalizedBase/v1',
      apiKey: apiKey,
      model: model,
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      media: media,
      expectJson: expectJson,
    );
  }

  String _normalizeBaseUrl(String raw, {required String fallback}) {
    var trimmed = raw.trim();
    if (trimmed.isEmpty) trimmed = fallback;
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  String _guessMimeType(String path, {required bool isVideo}) {
    final lower = path.toLowerCase();
    if (isVideo) {
      if (lower.endsWith('.mov')) return 'video/quicktime';
      if (lower.endsWith('.webm')) return 'video/webm';
      return 'video/mp4';
    }
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  String _extractErrorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final err = decoded['error'];
        if (err is Map<String, dynamic> && err['message'] is String) {
          return err['message'] as String;
        }
        if (err is String) return err;
        if (decoded['message'] is String) return decoded['message'] as String;
      }
    } catch (_) {
      // Ignore parse error.
    }
    return body.length > 180 ? '${body.substring(0, 180)}…' : body;
  }
}
