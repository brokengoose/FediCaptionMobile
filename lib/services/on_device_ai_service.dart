// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:edge_gen_ai/edge_gen_ai.dart';
import 'package:flutter/foundation.dart';

/// Snapshot of built-in OS on-device AI availability (Apple Foundation Models
/// on iPhone / Google Gemini Nano via ML Kit GenAI & AICore on Pixel & Samsung).
class OnDeviceAiStatus {
  const OnDeviceAiStatus({
    required this.promptAvailability,
    required this.imageDescriptionAvailability,
    required this.engineName,
  });

  final EdgeGenAIAvailability promptAvailability;
  final EdgeGenAIAvailability imageDescriptionAvailability;
  final String engineName;

  bool get isPromptReady => promptAvailability == EdgeGenAIAvailability.available;
  bool get isImageDescriberReady =>
      imageDescriptionAvailability == EdgeGenAIAvailability.available;

  bool get isPromptDownloadable =>
      promptAvailability == EdgeGenAIAvailability.downloadable;
  bool get isImageDescriberDownloadable =>
      imageDescriptionAvailability == EdgeGenAIAvailability.downloadable;

  bool get isReady => isPromptReady || isImageDescriberReady;
  bool get isDownloadable =>
      !isReady && (isPromptDownloadable || isImageDescriberDownloadable);
  bool get isNotYetReady =>
      !isReady &&
      !isDownloadable &&
      (promptAvailability == EdgeGenAIAvailability.notYetReady ||
          imageDescriptionAvailability == EdgeGenAIAvailability.notYetReady);

  /// True when the phone hardware supports on-device AI (either ready now or downloadable).
  bool get isUsable => isReady || isDownloadable;

  String get summaryMessage {
    if (isReady) {
      if (isImageDescriberReady && isPromptReady) {
        return 'Ready on this device ($engineName) — supports on-device image captioning and bias checking with zero network calls.';
      }
      if (isImageDescriberReady) {
        return 'On-device image description ready ($engineName). Bias checking will use offline heuristics.';
      }
      return 'On-device text & multimodal prompting ready ($engineName).';
    }
    if (isDownloadable) {
      return 'Supported on this device ($engineName). Tap "Download On-Device Model" to provision the OS-managed model.';
    }
    if (isNotYetReady) {
      return 'Supported on this device ($engineName), but not yet enabled. Turn on Apple Intelligence / device AI in system Settings.';
    }
    return 'Not available on this device or simulator ($engineName requires supported iPhone/Pixel/Samsung flagship hardware). You can use a Cloud API, Local LAN server, or No AI.';
  }

  static OnDeviceAiStatus unavailableForCurrentPlatform() {
    return OnDeviceAiStatus(
      promptAvailability: EdgeGenAIAvailability.unavailable,
      imageDescriptionAvailability: EdgeGenAIAvailability.unavailable,
      engineName: _currentEngineName(),
    );
  }

  static String _currentEngineName() {
    if (kIsWeb) return 'Web (no OS on-device model)';
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return 'Apple Foundation Models';
      case TargetPlatform.android:
        return 'Google Gemini Nano (ML Kit GenAI / AICore)';
      default:
        return 'On-Device AI';
    }
  }
}

/// Bridges FediCaption to native OS on-device AI via `edge_gen_ai`:
/// - iOS 26+/27+: Apple Foundation Models (Apple Intelligence)
/// - Android API 26+ (Pixel 8–11, Samsung Galaxy S23–S26 / Z Fold & Flip):
///   Google Gemini Nano via ML Kit GenAI & Android AICore.
class OnDeviceAiService {
  OnDeviceAiService({
    EdgeGenAIPrompt? promptClient,
    EdgeGenAIImageDescriber? imageDescriberClient,
  })  : _prompt = promptClient ?? EdgeGenAIPrompt(),
        _imageDescriber = imageDescriberClient ?? EdgeGenAIImageDescriber();

  final EdgeGenAIPrompt _prompt;
  final EdgeGenAIImageDescriber _imageDescriber;

  static const String modelAuto = 'on-device-auto';
  static const String modelImageDescriber = 'on-device-describer';
  static const String modelMultimodalPrompt = 'on-device-prompt';

  Future<OnDeviceAiStatus> checkStatus() async {
    final engineName = OnDeviceAiStatus._currentEngineName();
    if (kIsWeb) {
      return OnDeviceAiStatus.unavailableForCurrentPlatform();
    }

    EdgeGenAIAvailability promptAvail = EdgeGenAIAvailability.unavailable;
    EdgeGenAIAvailability imgAvail = EdgeGenAIAvailability.unavailable;

    try {
      promptAvail = await _prompt.checkAvailability();
    } catch (_) {
      promptAvail = EdgeGenAIAvailability.unavailable;
    }

    try {
      imgAvail = await _imageDescriber.checkAvailability();
    } catch (_) {
      imgAvail = EdgeGenAIAvailability.unavailable;
    }

    return OnDeviceAiStatus(
      promptAvailability: promptAvail,
      imageDescriptionAvailability: imgAvail,
      engineName: engineName,
    );
  }

  /// Downloads any downloadable OS-managed on-device models (e.g. Gemini Nano via AICore).
  Future<OnDeviceAiStatus> downloadModelsIfNeeded() async {
    final status = await checkStatus();

    if (status.isPromptDownloadable) {
      await for (final _ in _prompt.downloadModel()) {
        // Wait until stream finishes provisioning via AICore.
      }
    }
    if (status.isImageDescriberDownloadable) {
      await for (final _ in _imageDescriber.downloadModel()) {
        // Wait until stream finishes provisioning via AICore.
      }
    }

    return checkStatus();
  }

  /// Generates an on-device description for a single image.
  /// Uses multimodal prompting when custom detail/context is requested, or the
  /// dedicated ML Kit / Apple Image Describer when selected or as fallback.
  Future<String> describeImage({
    required Uint8List imageBytes,
    required String prompt,
    required String selectedModel,
  }) async {
    final status = await checkStatus();
    if (!status.isUsable) {
      throw StateError(status.summaryMessage);
    }

    if (status.isDownloadable) {
      await downloadModelsIfNeeded();
    }

    // 1. Dedicated fast on-device Image Describer (ML Kit Image Description / Apple Vision+FM).
    if (selectedModel == modelImageDescriber) {
      final result = await _imageDescriber.describeImage(imageBytes);
      if (result.trim().isNotEmpty) return result.trim();
    }

    // 2. Multimodal prompt (respects concise/descriptive/detailed + post context + custom instructions).
    try {
      final streamed = await _runPrompt(prompt, image: imageBytes);
      if (streamed.trim().isNotEmpty) {
        return streamed.trim();
      }
    } catch (_) {
      if (selectedModel == modelMultimodalPrompt) rethrow;
    }

    // 3. Fallback to dedicated Image Describer if multimodal prompt isn't supported for images.
    final fallback = await _imageDescriber.describeImage(imageBytes);
    if (fallback.trim().isEmpty) {
      throw StateError('On-device model returned an empty image description.');
    }
    return fallback.trim();
  }

  /// Describes multiple extracted video keyframes on-device (one image per call)
  /// and synthesizes them into a single cohesive narrative description.
  Future<String> describeVideoKeyframes({
    required List<Uint8List> keyframes,
    required String framePrompt,
    required String synthesisPromptTemplate,
    required String selectedModel,
  }) async {
    if (keyframes.isEmpty) {
      throw StateError('No video keyframes available for on-device analysis.');
    }
    if (keyframes.length == 1) {
      return describeImage(
        imageBytes: keyframes.first,
        prompt: framePrompt,
        selectedModel: selectedModel,
      );
    }

    final frameDescriptions = <String>[];
    for (var i = 0; i < keyframes.length; i++) {
      final desc = await describeImage(
        imageBytes: keyframes[i],
        prompt: 'Briefly describe keyframe ${i + 1} of ${keyframes.length} from a video, including any visible text.',
        selectedModel: selectedModel,
      );
      frameDescriptions.add('Frame ${i + 1}: $desc');
    }

    final combinedPrompt =
        '$synthesisPromptTemplate\n\nSequential keyframe descriptions:\n${frameDescriptions.join('\n')}';

    try {
      final synthesized = await _runPrompt(combinedPrompt);
      if (synthesized.trim().isNotEmpty) {
        return synthesized.trim();
      }
    } catch (_) {
      // Fall back to joining individual frame descriptions cleanly.
    }

    return frameDescriptions.join(' ');
  }

  /// Runs a text or single-image multimodal prompt on-device (used for bias checking).
  Future<String> runPrompt({
    required String systemPrompt,
    required String userPrompt,
    Uint8List? imageBytes,
  }) async {
    final status = await checkStatus();
    if (!status.isPromptReady && !status.isPromptDownloadable) {
      throw StateError(status.summaryMessage);
    }
    if (status.isPromptDownloadable) {
      await downloadModelsIfNeeded();
    }

    final combined = '$systemPrompt\n\n$userPrompt';
    final output = await _runPrompt(combined, image: imageBytes);
    if (output.trim().isEmpty) {
      throw StateError('On-device model returned an empty response.');
    }
    return output.trim();
  }

  /// Collects the latest full snapshot emitted by `EdgeGenAIPrompt.generateContent`.
  Future<String> _runPrompt(String prompt, {Uint8List? image}) async {
    var latest = '';
    await for (final snapshot in _prompt.generateContent(
      prompt,
      image: image,
    )) {
      latest = snapshot;
    }
    return latest;
  }
}
