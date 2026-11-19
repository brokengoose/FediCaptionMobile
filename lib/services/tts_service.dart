// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Native iOS and Android Text-to-Speech controller for reading alt-text aloud.
class TtsService extends ChangeNotifier {
  TtsService({FlutterTts? tts}) : _tts = tts ?? FlutterTts() {
    _configure();
  }

  final FlutterTts _tts;
  String? _activeKey;
  bool _isSpeaking = false;

  bool get isSpeaking => _isSpeaking;
  String? get activeKey => _activeKey;

  bool isSpeakingKey(String key) => _isSpeaking && _activeKey == key;

  void _configure() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      _tts.setSharedInstance(true);
      _tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
        ],
        IosTextToSpeechAudioMode.spokenAudio,
      );
    }

    _tts.setCompletionHandler(() {
      _isSpeaking = false;
      _activeKey = null;
      notifyListeners();
    });
    _tts.setCancelHandler(() {
      _isSpeaking = false;
      _activeKey = null;
      notifyListeners();
    });
    _tts.setErrorHandler((_) {
      _isSpeaking = false;
      _activeKey = null;
      notifyListeners();
    });
  }

  /// Speaks [text] (or stops if [key] is already being spoken).
  Future<void> toggleSpeak({
    required String key,
    required String text,
    String? languageName,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    if (isSpeakingKey(key)) {
      await stop();
      return;
    }

    await _tts.stop();
    try {
      await _tts.setVolume(1.0);
    } catch (_) {
      // Ignore if platform rejects volume call.
    }
    final langCode = _languageCodeFromName(languageName);
    if (langCode != null) {
      try {
        await _tts.setLanguage(langCode);
      } catch (_) {
        // Ignore unsupported TTS locale and fall back to system default.
      }
    }

    _activeKey = key;
    _isSpeaking = true;
    notifyListeners();

    await _tts.speak(trimmed);
  }

  Future<void> stop() async {
    await _tts.stop();
    _isSpeaking = false;
    _activeKey = null;
    notifyListeners();
  }

  String? _languageCodeFromName(String? name) {
    if (name == null || name.trim().isEmpty) return null;
    switch (name.trim().toLowerCase()) {
      case 'english':
        return 'en-US';
      case 'spanish':
      case 'español':
        return 'es-ES';
      case 'french':
      case 'français':
        return 'fr-FR';
      case 'german':
      case 'deutsch':
        return 'de-DE';
      case 'japanese':
      case '日本語':
        return 'ja-JP';
      case 'portuguese':
      case 'português':
        return 'pt-BR';
      case 'italian':
      case 'italiano':
        return 'it-IT';
      case 'korean':
        return 'ko-KR';
      case 'chinese':
      case 'mandarin':
        return 'zh-CN';
      default:
        return null;
    }
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }
}
