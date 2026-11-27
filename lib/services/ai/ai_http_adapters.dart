// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/constants.dart';
import '../../models/ai_models.dart';

/// Exception thrown when an AI provider request fails or is misconfigured.
class AiProviderException implements Exception {
  const AiProviderException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Low-level HTTP transport adapters for cloud and LAN AI providers
/// (Google Gemini, OpenAI-compatible, Anthropic Claude, and Ollama / LM Studio).
class AiHttpAdapters {
  const AiHttpAdapters(this._client);

  final http.Client _client;

  /// Normalizes a provider base URL by falling back to [fallback] and stripping
  /// trailing slashes.
  static String normalizeBaseUrl(String raw, {required String fallback}) {
    var trimmed = raw.trim();
    if (trimmed.isEmpty) trimmed = fallback;
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  /// Extracts a human-readable error message from a provider JSON error body.
  static String extractErrorMessage(String body) {
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
      // Ignore parse error and fall back to truncated raw body.
    }
    return body.length > 180 ? '${body.substring(0, 180)}…' : body;
  }

  /// Executes a multimodal prompt against Google Gemini's `generateContent` API.
  Future<String> callGemini({
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
      '${AppConstants.geminiBaseUrl}/models/$cleanModel:generateContent',
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
        {'role': 'user', 'parts': parts},
      ],
      if (expectJson)
        'generationConfig': {'responseMimeType': 'application/json'},
    };

    final res = await _client
        .post(
          uri,
          // Key goes in a header, never the URL: http.ClientException
          // stringifies the URI, and those messages are shown in the UI.
          headers: {'Content-Type': 'application/json', 'x-goog-api-key': key},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 60));

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw AiProviderException(
        'Gemini API error (${res.statusCode}): ${extractErrorMessage(res.body)}',
      );
    }

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final candidates = (decoded['candidates'] as List<dynamic>?) ?? const [];
    if (candidates.isEmpty) {
      throw const AiProviderException(
        'Gemini returned no response candidates.',
      );
    }
    final content =
        (candidates.first as Map<String, dynamic>)['content']
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

  /// Executes a chat-completions prompt against OpenAI or any OpenAI-compatible server
  /// (OpenRouter, LM Studio, vLLM, llama.cpp).
  Future<String> callOpenAiCompatible({
    required String baseUrl,
    required String apiKey,
    required String model,
    required String systemPrompt,
    required String userPrompt,
    required List<MediaBinaryPayload> media,
    required bool expectJson,
  }) async {
    final normalizedBase = normalizeBaseUrl(
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
        'OpenAI-compatible API error (${res.statusCode}): ${extractErrorMessage(res.body)}',
      );
    }

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final choices = (decoded['choices'] as List<dynamic>?) ?? const [];
    if (choices.isEmpty) {
      throw const AiProviderException('Provider returned no choices.');
    }
    final message =
        (choices.first as Map<String, dynamic>)['message']
            as Map<String, dynamic>?;
    final content = (message?['content'] as String?)?.trim() ?? '';
    if (content.isEmpty) {
      throw const AiProviderException('Provider returned an empty message.');
    }
    return content;
  }

  /// Executes a prompt against Anthropic's Messages API (`POST /v1/messages`).
  Future<String> callAnthropic({
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
        {'role': 'user', 'content': contentBlocks},
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
        'Anthropic API error (${res.statusCode}): ${extractErrorMessage(res.body)}',
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

  /// Calls local Ollama (`/api/chat`) first, falling back to OpenAI-compatible
  /// LM Studio / vLLM / llama.cpp (`/v1/chat/completions`).
  Future<String> callLocal({
    required String baseUrl,
    required String apiKey,
    required String model,
    required String systemPrompt,
    required String userPrompt,
    required List<MediaBinaryPayload> media,
    required bool expectJson,
  }) async {
    final normalizedBase = normalizeBaseUrl(
      baseUrl,
      fallback: AppConstants.localDefaultBaseUrl,
    );

    if (normalizedBase.endsWith('/v1')) {
      return callOpenAiCompatible(
        baseUrl: normalizedBase,
        apiKey: apiKey,
        model: model,
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        media: media,
        expectJson: expectJson,
      );
    }

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
            headers: const {'Content-Type': 'application/json'},
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

    return callOpenAiCompatible(
      baseUrl: '$normalizedBase/v1',
      apiKey: apiKey,
      model: model,
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      media: media,
      expectJson: expectJson,
    );
  }
}
