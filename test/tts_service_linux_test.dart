// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'dart:async';
import 'dart:io';

import 'package:fedicaption_mobile/services/tts_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeProcess implements Process {
  final Completer<int> _exitCompleter = Completer<int>();
  final List<ProcessSignal> killSignals = <ProcessSignal>[];
  bool killed = false;

  void finish([int code = 0]) {
    if (!_exitCompleter.isCompleted) {
      _exitCompleter.complete(code);
    }
  }

  @override
  Future<int> get exitCode => _exitCompleter.future;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killed = true;
    killSignals.add(signal);
    finish(0);
    return true;
  }

  @override
  int get pid => 12345;

  @override
  IOSink get stdin => throw UnimplementedError();

  @override
  Stream<List<int>> get stderr => const Stream<List<int>>.empty();

  @override
  Stream<List<int>> get stdout => const Stream<List<int>>.empty();
}

void main() {
  group('TtsService on Linux', () {
    test(
      'tries spd-say first with flags and -- separator, then resets on exit',
      () async {
        final calls = <(String, List<String>)>[];
        final proc = _FakeProcess();

        final tts = TtsService(
          isLinuxOverride: true,
          linuxProcessStarter: (exe, args) async {
            calls.add((exe, args));
            return proc;
          },
        );
        addTearDown(tts.dispose);

        await tts.toggleSpeak(
          key: 'post-1',
          text: '-Leading dash alt text',
          languageName: 'Spanish',
          speechRate: 0.75,
        );

        expect(calls, hasLength(1));
        expect(calls.single.$1, 'spd-say');
        expect(
          calls.single.$2,
          [
            '--wait',
            '--rate',
            '40',
            '--language',
            'es',
            '--',
            '-Leading dash alt text',
          ],
        );
        expect(tts.isSpeaking, isTrue);
        expect(tts.isSpeakingKey('post-1'), isTrue);

        proc.finish(0);
        await pumpEventQueue();

        expect(tts.isSpeaking, isFalse);
        expect(tts.isSpeakingKey('post-1'), isFalse);
      },
    );

    test(
      'falls back from spd-say to espeak-ng and espeak, and handles missing binaries',
      () async {
        final attempted = <String>[];
        final espeakArgs = <List<String>>[];
        final proc = _FakeProcess();

        final ttsFallback = TtsService(
          isLinuxOverride: true,
          linuxProcessStarter: (exe, args) async {
            attempted.add(exe);
            if (exe == 'spd-say') {
              throw const ProcessException('spd-say', [], 'No such file');
            }
            if (exe == 'espeak-ng') {
              espeakArgs.add(args);
              return proc;
            }
            fail('Unexpected executable $exe');
          },
        );
        addTearDown(ttsFallback.dispose);

        await ttsFallback.toggleSpeak(
          key: 'alt-1',
          text: 'Hello Linux',
          languageName: 'French',
          speechRate: 0.5,
        );

        expect(attempted, ['spd-say', 'espeak-ng']);
        expect(espeakArgs.single, ['-s', '175', '-v', 'fr', '--', 'Hello Linux']);
        expect(ttsFallback.isSpeakingKey('alt-1'), isTrue);

        // Now verify espeak-ng -> espeak fallback.
        final attemptedSecond = <String>[];
        final proc2 = _FakeProcess();
        final ttsEspeak = TtsService(
          isLinuxOverride: true,
          linuxProcessStarter: (exe, args) async {
            attemptedSecond.add(exe);
            if (exe == 'spd-say' || exe == 'espeak-ng') {
              throw ProcessException(exe, args, 'Not found');
            }
            return proc2;
          },
        );
        addTearDown(ttsEspeak.dispose);

        await ttsEspeak.toggleSpeak(key: 'alt-2', text: 'Fallback test');
        expect(attemptedSecond, ['spd-say', 'espeak-ng', 'espeak']);
        expect(ttsEspeak.isSpeakingKey('alt-2'), isTrue);

        // When none exist, no exception is thrown and speaking remains false.
        final ttsNone = TtsService(
          isLinuxOverride: true,
          linuxProcessStarter: (exe, args) async {
            throw ProcessException(exe, args, 'Not found');
          },
        );
        addTearDown(ttsNone.dispose);

        await ttsNone.toggleSpeak(key: 'alt-3', text: 'Silent');
        expect(ttsNone.isSpeaking, isFalse);
        expect(ttsNone.activeKey, isNull);
      },
    );

    test('stop() and toggling the active key kill the process and clear state',
        () async {
      final procs = <_FakeProcess>[];
      final tts = TtsService(
        isLinuxOverride: true,
        linuxProcessStarter: (exe, args) async {
          final p = _FakeProcess();
          procs.add(p);
          return p;
        },
      );
      addTearDown(tts.dispose);

      await tts.toggleSpeak(key: 'k1', text: 'First');
      expect(tts.isSpeakingKey('k1'), isTrue);

      // Toggling the same key stops playback and kills the active process.
      await tts.toggleSpeak(key: 'k1', text: 'First');
      expect(procs[0].killed, isTrue);
      expect(procs[0].killSignals, [ProcessSignal.sigterm]);
      expect(tts.isSpeaking, isFalse);
      expect(tts.activeKey, isNull);

      await tts.toggleSpeak(key: 'k2', text: 'Second');
      expect(tts.isSpeakingKey('k2'), isTrue);

      await tts.stop();
      expect(procs[1].killed, isTrue);
      expect(tts.isSpeaking, isFalse);
      expect(tts.activeKey, isNull);
    });
  });
}
