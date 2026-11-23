// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

typedef LinuxProcessStarter = Future<Process> Function(
  String executable,
  List<String> arguments,
);

/// Native iOS, macOS, Android, Windows, and Linux Text-to-Speech controller for
/// reading alt-text aloud.
class TtsService extends ChangeNotifier {
  TtsService({
    FlutterTts? tts,
    bool? isLinuxOverride,
    LinuxProcessStarter? linuxProcessStarter,
  })  : _isLinux = isLinuxOverride ??
            (!kIsWeb && defaultTargetPlatform == TargetPlatform.linux),
        _linuxProcessStarter = linuxProcessStarter ?? Process.start,
        _tts = (isLinuxOverride ??
                    (!kIsWeb && defaultTargetPlatform == TargetPlatform.linux)) &&
                tts == null
            ? null
            : (tts ?? FlutterTts()) {
    if (_tts != null) {
      _configure(_tts);
    }
  }

  final FlutterTts? _tts;
  final bool _isLinux;
  final LinuxProcessStarter _linuxProcessStarter;
  Process? _linuxProcess;
  int _speakGeneration = 0;
  String? _activeKey;
  bool _isSpeaking = false;
  bool _disposed = false;

  bool get isSpeaking => _isSpeaking;
  String? get activeKey => _activeKey;

  bool isSpeakingKey(String key) => _isSpeaking && _activeKey == key;

  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  void _resetState() {
    _isSpeaking = false;
    _activeKey = null;
    _safeNotify();
  }

  void _configure(FlutterTts tts) {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      tts.setSharedInstance(true);
      tts.setIosAudioCategory(
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

    tts.setCompletionHandler(_resetState);
    tts.setCancelHandler(_resetState);
    tts.setErrorHandler((_) => _resetState());
  }

  /// Speaks [text] (or stops if [key] is already being spoken) using the device's
  /// native TTS engine (`AVSpeechSynthesizer` on iOS/macOS, `TextToSpeech` on
  /// Android, SAPI on Windows, or `spd-say` / `espeak-ng` / `espeak` on Linux).
  Future<void> toggleSpeak({
    required String key,
    required String text,
    String? languageName,
    double speechRate = 0.5,
  }) async {
    if (_disposed) return;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    if (isSpeakingKey(key)) {
      await stop();
      return;
    }

    if (_isLinux && _tts == null) {
      await _toggleSpeakLinux(
        key: key,
        text: trimmed,
        languageName: languageName,
        speechRate: speechRate,
      );
      return;
    }

    final tts = _tts;
    if (tts == null) return;

    await tts.stop();
    try {
      await tts.setVolume(1.0);
      await tts.setSpeechRate(speechRate.clamp(0.25, 1.0));
    } catch (_) {
      // Ignore if platform rejects volume/rate call.
    }
    final langCode = _languageCodeFromName(languageName);
    if (langCode != null) {
      try {
        await tts.setLanguage(langCode);
      } catch (_) {
        // Ignore unsupported TTS locale and fall back to system default.
      }
    }

    if (_disposed) return;
    _activeKey = key;
    _isSpeaking = true;
    _safeNotify();

    await tts.speak(trimmed);
  }

  Future<void> _toggleSpeakLinux({
    required String key,
    required String text,
    String? languageName,
    double speechRate = 0.5,
  }) async {
    await _stopLinuxProcess();
    final gen = ++_speakGeneration;

    final clampedRate = speechRate.clamp(0.25, 1.0);
    final spdRate = ((clampedRate - 0.5) * 160).round().clamp(-80, 80);
    final espeakWpm = (100 + clampedRate * 150).round();
    final primaryLang =
        _languageCodeFromName(languageName)?.split('-').first.toLowerCase();

    final candidates = <(String, List<String>)>[
      (
        'spd-say',
        [
          '--wait',
          '--rate',
          '$spdRate',
          if (primaryLang != null) ...['--language', primaryLang],
          '--',
          text,
        ],
      ),
      (
        'espeak-ng',
        [
          '-s',
          '$espeakWpm',
          if (primaryLang != null) ...['-v', primaryLang],
          '--',
          text,
        ],
      ),
      (
        'espeak',
        [
          '-s',
          '$espeakWpm',
          if (primaryLang != null) ...['-v', primaryLang],
          '--',
          text,
        ],
      ),
    ];

    Process? started;
    for (final (executable, args) in candidates) {
      if (_disposed || _speakGeneration != gen) return;
      try {
        started = await _linuxProcessStarter(executable, args);
        break;
      } on ProcessException {
        // Binary not installed; try next Linux speech synthesizer.
      } on OSError {
        // Unavailable or permission error; try next Linux speech synthesizer.
      }
    }

    if (started == null) {
      if (_speakGeneration == gen) {
        _resetState();
      }
      return;
    }

    if (_disposed || _speakGeneration != gen) {
      _killProcessQuietly(started);
      return;
    }

    _linuxProcess = started;
    _activeKey = key;
    _isSpeaking = true;
    _safeNotify();

    started.exitCode.catchError((_) => -1).whenComplete(() {
      if (_speakGeneration == gen && !_disposed) {
        _linuxProcess = null;
        _resetState();
      }
    });
  }

  Future<void> _stopLinuxProcess() async {
    final proc = _linuxProcess;
    _linuxProcess = null;
    if (proc != null) {
      _killProcessQuietly(proc);
    }
  }

  void _killProcessQuietly(Process proc) {
    try {
      proc.kill(ProcessSignal.sigterm);
    } catch (_) {
      // Ignore if the speech process has already exited.
    }
  }

  Future<void> stop() async {
    if (_isLinux && _tts == null) {
      _speakGeneration++;
      await _stopLinuxProcess();
      _resetState();
      return;
    }
    await _tts?.stop();
    _resetState();
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
    _disposed = true;
    _speakGeneration++;
    final proc = _linuxProcess;
    _linuxProcess = null;
    if (proc != null) {
      _killProcessQuietly(proc);
    }
    _tts?.stop().catchError((_) {});
    super.dispose();
  }
}
