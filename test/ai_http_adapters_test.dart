// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'dart:convert';
import 'dart:typed_data';

import 'package:fedicaption_mobile/models/ai_models.dart';
import 'package:fedicaption_mobile/services/ai/ai_http_adapters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('AiHttpAdapters', () {
    test(
      'normalizeBaseUrl falls back and strips multiple trailing slashes',
      () {
        expect(
          AiHttpAdapters.normalizeBaseUrl('', fallback: 'https://fallback/v1'),
          'https://fallback/v1',
        );
        expect(
          AiHttpAdapters.normalizeBaseUrl(
            '  https://example.org/v1///  ',
            fallback: 'https://fallback/v1',
          ),
          'https://example.org/v1',
        );
      },
    );

    test('callGemini sends x-goog-api-key header, JSON mode, and supports >256KB isolate base64', () async {
      late http.Request captured;
      final largePayload = Uint8List.fromList(
        List<int>.generate(300 * 1024, (i) => i % 251),
      );
      final client = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': '{"ok": true}'},
                  ],
                },
              },
            ],
          }),
          200,
        );
      });
      final adapters = AiHttpAdapters(client);

      final reply = await adapters.callGemini(
        apiKey: '  AIzaSecret123  ',
        model: 'models/gemini-2.5-flash',
        systemPrompt: 'System',
        userPrompt: 'Describe',
        media: [MediaBinaryPayload(bytes: largePayload, mimeType: 'video/mp4')],
        expectJson: true,
      );

      expect(reply, '{"ok": true}');
      expect(captured.url.query, isEmpty);
      expect(
        captured.url.path,
        endsWith('/models/gemini-2.5-flash:generateContent'),
      );
      expect(captured.headers['x-goog-api-key'], 'AIzaSecret123');
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['generationConfig'], {
        'responseMimeType': 'application/json',
      });
      final contents = body['contents'] as List<dynamic>;
      final parts =
          (contents.first as Map<String, dynamic>)['parts'] as List<dynamic>;
      expect(parts, hasLength(2));
      final inlineData =
          (parts[1] as Map<String, dynamic>)['inline_data']
              as Map<String, dynamic>;
      expect(inlineData['mime_type'], 'video/mp4');
      expect(inlineData['data'], base64Encode(largePayload));
    });

    test(
      'callGemini extracts provider error message without echoing key',
      () async {
        final client = MockClient(
          (_) async => http.Response(
            jsonEncode({
              'error': {'message': 'Quota exceeded'},
            }),
            429,
          ),
        );
        final adapters = AiHttpAdapters(client);

        expect(
          () => adapters.callGemini(
            apiKey: 'AIzaSecret',
            model: 'gemini-2.5-flash',
            systemPrompt: 'sys',
            userPrompt: 'usr',
            media: const [],
            expectJson: false,
          ),
          throwsA(
            isA<AiProviderException>()
                .having((e) => e.message, 'message', contains('Quota exceeded'))
                .having(
                  (e) => e.message,
                  'message',
                  isNot(contains('AIzaSecret')),
                ),
          ),
        );
      },
    );

    test('callOpenAiCompatible guards missing OpenAI key and sends Bearer auth + response_format', () async {
      final adaptersNoNet = AiHttpAdapters(
        MockClient((_) async => throw StateError('unexpected call')),
      );
      expect(
        () => adaptersNoNet.callOpenAiCompatible(
          baseUrl: 'https://api.openai.com/v1',
          apiKey: '',
          model: 'gpt-4o',
          systemPrompt: 'sys',
          userPrompt: 'usr',
          media: const [],
          expectJson: true,
        ),
        throwsA(
          isA<AiProviderException>().having(
            (e) => e.message,
            'message',
            contains('OpenAI API key is not configured'),
          ),
        ),
      );

      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': '  Alt text result  '},
              },
            ],
          }),
          200,
        );
      });
      final adapters = AiHttpAdapters(client);

      final reply = await adapters.callOpenAiCompatible(
        baseUrl: 'https://api.openai.com/v1/',
        apiKey: 'sk-test-key',
        model: 'gpt-4o-mini',
        systemPrompt: 'sys',
        userPrompt: 'describe',
        media: [
          MediaBinaryPayload(
            bytes: Uint8List.fromList([1, 2, 3]),
            mimeType: 'image/png',
          ),
        ],
        expectJson: true,
      );

      expect(reply, 'Alt text result');
      expect(
        captured.url.toString(),
        'https://api.openai.com/v1/chat/completions',
      );
      expect(captured.headers['Authorization'], 'Bearer sk-test-key');
      final sent = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(sent['response_format'], {'type': 'json_object'});
    });

    test('callAnthropic sends x-api-key and anthropic-version headers and parses text blocks', () async {
      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({
            'content': [
              {'type': 'text', 'text': 'First line'},
              {'type': 'text', 'text': 'Second line'},
            ],
          }),
          200,
        );
      });
      final adapters = AiHttpAdapters(client);

      final reply = await adapters.callAnthropic(
        apiKey: 'sk-ant-123',
        model: 'claude-sonnet-4-5',
        systemPrompt: 'sys',
        userPrompt: 'describe',
        media: [
          MediaBinaryPayload(
            bytes: Uint8List.fromList([7, 8, 9]),
            mimeType: 'image/jpeg',
          ),
        ],
      );

      expect(reply, 'First line\nSecond line');
      expect(captured.headers['x-api-key'], 'sk-ant-123');
      expect(captured.headers['anthropic-version'], isNotEmpty);
    });

    test(
      'callLocal hits Ollama /api/chat first and strips base URL slashes',
      () async {
        late http.Request captured;
        final client = MockClient((req) async {
          captured = req;
          return http.Response(
            jsonEncode({
              'message': {'content': 'Local ollama response'},
            }),
            200,
          );
        });
        final adapters = AiHttpAdapters(client);

        final reply = await adapters.callLocal(
          baseUrl: 'http://127.0.0.1:11434/',
          apiKey: '',
          model: 'llava',
          systemPrompt: 'sys',
          userPrompt: 'describe',
          media: [
            MediaBinaryPayload(
              bytes: Uint8List.fromList([4, 5]),
              mimeType: 'image/png',
            ),
          ],
          expectJson: true,
        );

        expect(reply, 'Local ollama response');
        expect(captured.url.toString(), 'http://127.0.0.1:11434/api/chat');
        final sent = jsonDecode(captured.body) as Map<String, dynamic>;
        expect(sent['format'], 'json');
      },
    );
  });
}
