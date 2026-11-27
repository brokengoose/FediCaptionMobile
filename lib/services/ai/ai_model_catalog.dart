// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/constants.dart';
import '../../models/ai_models.dart';
import '../../models/app_settings.dart';
import '../on_device_ai_service.dart';
import 'ai_http_adapters.dart';

/// Curated fallback catalogs and dynamic model discovery across all supported AI providers.
class AiModelCatalog {
  const AiModelCatalog(this._client);

  final http.Client _client;

  /// Sorts model options alphabetically (case-insensitive by display name, then ID).
  static List<AiModelOption> sortAlphabetically(
    Iterable<AiModelOption> models,
  ) {
    final sorted = List<AiModelOption>.from(models);
    sorted.sort((a, b) {
      final byName = a.displayName.toLowerCase().compareTo(
        b.displayName.toLowerCase(),
      );
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
      case AiProviderType.onDevice:
        models = const [
          AiModelOption(
            id: OnDeviceAiService.modelAuto,
            displayName: 'On-Device Auto (Vision Prompt + Image Describer)',
          ),
          AiModelOption(
            id: OnDeviceAiService.modelImageDescriber,
            displayName: 'On-Device Image Describer (Fast Alt-Text)',
          ),
          AiModelOption(
            id: OnDeviceAiService.modelMultimodalPrompt,
            displayName: 'On-Device Multimodal Prompt (Custom Detail & Bias)',
          ),
        ];
      case AiProviderType.gemini:
        models = const [
          AiModelOption(id: 'gemini-1.5-pro', displayName: 'Gemini 1.5 Pro'),
          AiModelOption(
            id: 'gemini-2.0-flash',
            displayName: 'Gemini 2.0 Flash',
          ),
          AiModelOption(
            id: 'gemini-2.5-flash',
            displayName: 'Gemini 2.5 Flash',
          ),
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
          AiModelOption(id: 'minicpm-v', displayName: 'MiniCPM-V (Ollama/LAN)'),
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
    if (provider == AiProviderType.onDevice) {
      return defaultModelsFor(AiProviderType.onDevice);
    }
    try {
      final fetched = switch (provider) {
        AiProviderType.onDevice => defaultModelsFor(AiProviderType.onDevice),
        AiProviderType.gemini => await _fetchGeminiModels(
          credentials.geminiApiKey,
        ),
        AiProviderType.openai => await _fetchOpenAiModels(
          baseUrl: settings.openAiBaseUrl,
          apiKey: credentials.openAiApiKey,
        ),
        AiProviderType.anthropic => await _fetchAnthropicModels(
          credentials.anthropicApiKey,
        ),
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

    final uri = Uri.parse('${AppConstants.geminiBaseUrl}/models');
    // Key in a header so it can't leak via exception messages that include the URI.
    final res = await _client
        .get(uri, headers: {'x-goog-api-key': trimmed})
        .timeout(const Duration(seconds: 12));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw AiProviderException('Gemini models error (${res.statusCode})');
    }

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final rawModels = (decoded['models'] as List<dynamic>?) ?? const [];
    final results = <AiModelOption>[];

    for (final item in rawModels.whereType<Map<String, dynamic>>()) {
      final methods =
          (item['supportedGenerationMethods'] as List<dynamic>?)
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

    return results;
  }

  Future<List<AiModelOption>> _fetchOpenAiModels({
    required String baseUrl,
    required String apiKey,
  }) async {
    final normalizedBase = AiHttpAdapters.normalizeBaseUrl(
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

    return results;
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
    return data
        .whereType<Map<String, dynamic>>()
        .map((item) {
          final id = (item['id'] as String?) ?? '';
          final displayName = (item['display_name'] as String?)?.trim();
          return AiModelOption(
            id: id,
            displayName: (displayName != null && displayName.isNotEmpty)
                ? '$displayName ($id)'
                : id,
          );
        })
        .where((m) => m.id.isNotEmpty)
        .toList();
  }

  /// Queries Ollama (`/api/tags`) first, then OpenAI-compatible LM Studio (`/v1/models`).
  Future<List<AiModelOption>> _fetchLocalModels({
    required String baseUrl,
    required String apiKey,
  }) async {
    final normalizedBase = AiHttpAdapters.normalizeBaseUrl(
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
        results.addAll(
          await _fetchOpenAiModels(baseUrl: v1Base, apiKey: apiKey),
        );
      } catch (_) {
        // Ignore and fall back to curated defaults in caller.
      }
    }

    return results;
  }
}
