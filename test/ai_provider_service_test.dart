// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'dart:convert';
import 'dart:typed_data';

import 'package:fedicaption_mobile/core/constants.dart';
import 'package:fedicaption_mobile/models/ai_models.dart';
import 'package:fedicaption_mobile/models/app_settings.dart';
import 'package:fedicaption_mobile/services/ai_provider_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('AiProviderService dynamic model discovery', () {
    test('filters Gemini models to those supporting generateContent', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), contains('generativelanguage.googleapis.com/v1beta/models'));
        return http.Response(
          jsonEncode({
            'models': [
              {
                'name': 'models/gemini-2.5-flash',
                'displayName': 'Gemini 2.5 Flash',
                'supportedGenerationMethods': ['generateContent'],
              },
              {
                'name': 'models/text-embedding-004',
                'displayName': 'Text Embedding',
                'supportedGenerationMethods': ['embedContent'],
              },
            ],
          }),
          200,
        );
      });

      final service = AiProviderService(client: mockClient);
      final models = await service.fetchAvailableModels(
        provider: AiProviderType.gemini,
        settings: const AppSettings(),
        credentials: const AiCredentials(geminiApiKey: 'test-key'),
      );

      expect(models.map((m) => m.id), ['gemini-2.5-flash']);
    });

    test('filters OpenAI utility models (whisper, tts, embeddings) on api.openai.com', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'data': [
              {'id': 'gpt-4o'},
              {'id': 'whisper-1'},
              {'id': 'tts-1'},
              {'id': 'text-embedding-3-small'},
              {'id': 'gpt-4o-mini'},
            ],
          }),
          200,
        );
      });

      final service = AiProviderService(client: mockClient);
      final models = await service.fetchAvailableModels(
        provider: AiProviderType.openai,
        settings: const AppSettings(),
        credentials: const AiCredentials(openAiApiKey: 'sk-test'),
      );

      final ids = models.map((m) => m.id).toList();
      expect(ids, containsAll(['gpt-4o', 'gpt-4o-mini']));
      expect(ids, isNot(contains('whisper-1')));
      expect(ids, isNot(contains('tts-1')));
      expect(ids, isNot(contains('text-embedding-3-small')));
    });

    test('queries Anthropic models with x-api-key and anthropic-version headers', () async {
      final mockClient = MockClient((request) async {
        expect(request.headers['x-api-key'], 'sk-ant-test');
        expect(request.headers['anthropic-version'], AppConstants.anthropicVersion);
        return http.Response(
          jsonEncode({
            'data': [
              {'id': 'claude-sonnet-4-20250514', 'display_name': 'Claude Sonnet 4'},
            ],
          }),
          200,
        );
      });

      final service = AiProviderService(client: mockClient);
      final models = await service.fetchAvailableModels(
        provider: AiProviderType.anthropic,
        settings: const AppSettings(),
        credentials: const AiCredentials(anthropicApiKey: 'sk-ant-test'),
      );

      expect(models.first.id, 'claude-sonnet-4-20250514');
    });

    test('queries Ollama /api/tags for local LAN provider and sorts models alphabetically', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/api/tags')) {
          return http.Response(
            jsonEncode({
              'models': [
                {'name': 'qwen2.5vl:latest'},
                {'name': 'mistral:latest'},
                {'name': 'llama3.2-vision:latest'},
              ],
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      final service = AiProviderService(client: mockClient);
      final models = await service.fetchAvailableModels(
        provider: AiProviderType.local,
        settings: const AppSettings(localBaseUrl: 'http://192.168.1.50:11434'),
        credentials: const AiCredentials(),
      );

      expect(
        models.map((m) => m.id).toList(),
        [
          'llama3.2-vision:latest',
          'mistral:latest',
          'on-device-fallback',
          'qwen2.5vl:latest',
        ],
      );
    });

    test('defaultModelsFor returns alphabetically sorted lists and empty for No AI', () {
      for (final provider in AiProviderType.values) {
        final models = AiProviderService.defaultModelsFor(provider);
        if (provider == AiProviderType.none) {
          expect(models, isEmpty);
          continue;
        }
        final names = models.map((m) => m.displayName.toLowerCase()).toList();
        final sortedNames = List<String>.from(names)..sort();
        expect(names, sortedNames);
      }
    });

    test('sorts OpenAI models alphabetically', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'data': [
              {'id': 'o3-mini'},
              {'id': 'gpt-4o-mini'},
              {'id': 'gpt-4.1'},
              {'id': 'gpt-4o'},
            ],
          }),
          200,
        );
      });

      final service = AiProviderService(client: mockClient);
      final models = await service.fetchAvailableModels(
        provider: AiProviderType.openai,
        settings: const AppSettings(),
        credentials: const AiCredentials(openAiApiKey: 'sk-test'),
      );

      expect(
        models.map((m) => m.id).toList(),
        ['gpt-4.1', 'gpt-4o', 'gpt-4o-mini', 'o3-mini'],
      );
    });

    test('generateAltText cleans output and prepends mandatory prefix', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': '"Photo of a wooden lighthouse overlooking rocky cliffs."'},
                  ],
                },
              },
            ],
          }),
          200,
        );
      });

      final service = AiProviderService(client: mockClient);
      final caption = await service.generateAltText(
        settings: const AppSettings(activeProvider: AiProviderType.gemini),
        credentials: const AiCredentials(geminiApiKey: 'test-key'),
        isVideo: false,
        detailLevel: CaptionDetailLevel.descriptive,
        maxAltTextLength: 1500,
        preExtractedMedia: [
          MediaBinaryPayload(
            bytes: Uint8List.fromList([1, 2, 3, 4]),
            mimeType: 'image/jpeg',
          ),
        ],
      );

      expect(
        caption,
        'AI generated description: A wooden lighthouse overlooking rocky cliffs.',
      );
    });
  });
}
