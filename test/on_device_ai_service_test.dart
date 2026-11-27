// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'dart:typed_data';

import 'package:edge_gen_ai/edge_gen_ai.dart';
import 'package:fedicaption_mobile/services/on_device_ai_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePromptClient extends EdgeGenAIPrompt {
  _FakePromptClient({this.onGenerate});

  final Stream<String> Function(String prompt, Uint8List? image)? onGenerate;
  int checkCount = 0;
  int generateCount = 0;

  @override
  Future<EdgeGenAIAvailability> checkAvailability() async {
    checkCount++;
    return EdgeGenAIAvailability.available;
  }

  @override
  Stream<String> generateContent(
    String prompt, {
    Uint8List? image,
    EdgeGenAIGenerationOptions? options,
  }) {
    generateCount++;
    if (onGenerate != null) {
      return onGenerate!(prompt, image);
    }
    return Stream.value('Prompt response');
  }
}

class _FakeImageDescriberClient extends EdgeGenAIImageDescriber {
  _FakeImageDescriberClient({this.onDescribe});

  final Future<String> Function(Uint8List imageBytes)? onDescribe;
  int checkCount = 0;
  int describeCount = 0;

  @override
  Future<EdgeGenAIAvailability> checkAvailability() async {
    checkCount++;
    return EdgeGenAIAvailability.available;
  }

  @override
  Future<String> describeImage(Uint8List imageBytes) async {
    describeCount++;
    if (onDescribe != null) {
      return onDescribe!(imageBytes);
    }
    return 'Dedicated describer result';
  }
}

void main() {
  final sampleBytes = Uint8List.fromList([1, 2, 3, 4]);

  group('OnDeviceAiService', () {
    test('falls back from empty dedicated Image Describer to prompt without duplicate describer call', () async {
      final prompt = _FakePromptClient(
        onGenerate: (_, _) => Stream.value('Fallback multimodal caption'),
      );
      final describer = _FakeImageDescriberClient(
        onDescribe: (_) async => '   ',
      );
      final service = OnDeviceAiService(
        promptClient: prompt,
        imageDescriberClient: describer,
      );

      final result = await service.describeImage(
        imageBytes: sampleBytes,
        prompt: 'Describe image',
        selectedModel: OnDeviceAiService.modelImageDescriber,
      );

      expect(result, 'Fallback multimodal caption');
      expect(describer.describeCount, 1);
      expect(prompt.generateCount, 1);
    });

    test(
      'auto mode falls back to Image Describer when multimodal prompt throws',
      () async {
        final prompt = _FakePromptClient(
          onGenerate: (_, _) =>
              Stream.error(Exception('Vision prompt unsupported')),
        );
        final describer = _FakeImageDescriberClient(
          onDescribe: (_) async => 'A dog sitting on grass',
        );
        final service = OnDeviceAiService(
          promptClient: prompt,
          imageDescriberClient: describer,
        );

        final result = await service.describeImage(
          imageBytes: sampleBytes,
          prompt: 'Describe image',
          selectedModel: OnDeviceAiService.modelAuto,
        );

        expect(result, 'A dog sitting on grass');
        expect(describer.describeCount, 1);
      },
    );

    test('describeVideoKeyframes checks OS availability only once across all frames', () async {
      final prompt = _FakePromptClient(
        onGenerate: (p, img) => Stream.value(
          img == null ? 'Cohesive video summary.' : 'A scene frame.',
        ),
      );
      final describer = _FakeImageDescriberClient();
      final service = OnDeviceAiService(
        promptClient: prompt,
        imageDescriberClient: describer,
      );

      final result = await service.describeVideoKeyframes(
        keyframes: [sampleBytes, sampleBytes, sampleBytes],
        framePrompt: 'Describe frame',
        synthesisPromptTemplate: 'Synthesize frames',
        selectedModel: OnDeviceAiService.modelAuto,
      );

      expect(result, 'Cohesive video summary.');
      expect(prompt.checkCount, 1);
      expect(describer.checkCount, 1);
      expect(prompt.generateCount, 4); // 3 frames + 1 synthesis call
    });
  });
}
