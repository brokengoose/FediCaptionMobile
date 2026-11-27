// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:fedicaption_mobile/models/ai_models.dart';
import 'package:fedicaption_mobile/models/app_settings.dart';
import 'package:fedicaption_mobile/services/ai_provider_service.dart';
import 'package:fedicaption_mobile/services/storage_service.dart';
import 'package:fedicaption_mobile/state/app_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryStorage extends StorageService {
  AppSettings saved = const AppSettings();

  @override
  Future<void> saveSettings(AppSettings settings) async => saved = settings;
}

/// Hands out one pending completer per fetch so tests control completion order.
class _ControlledAiProvider extends AiProviderService {
  final List<Completer<List<AiModelOption>>> pending = [];

  @override
  Future<List<AiModelOption>> fetchAvailableModels({
    required AiProviderType provider,
    required AppSettings settings,
    required AiCredentials credentials,
  }) {
    final c = Completer<List<AiModelOption>>();
    pending.add(c);
    return c.future;
  }
}

const _old = AiModelOption(id: 'old-endpoint-model', displayName: 'Old');
const _fresh = AiModelOption(id: 'fresh-model', displayName: 'Fresh');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppController.refreshModelsFor', () {
    test('a slow, stale fetch cannot overwrite a newer one', () async {
      final ai = _ControlledAiProvider();
      final storage = _MemoryStorage();
      final app = AppController(storageService: storage, aiProviderService: ai);
      addTearDown(app.dispose);
      const provider = AiProviderType.openai;

      final first = app.refreshModelsFor(provider); // e.g. old base URL
      final second = app.refreshModelsFor(provider); // after the user edited it

      ai.pending[1].complete([_fresh]);
      await second;
      expect(app.modelsFor(provider).map((m) => m.id), ['fresh-model']);
      expect(app.isLoadingModels(provider), isFalse);

      ai.pending[0].complete([_old]);
      await first;

      expect(app.modelsFor(provider).map((m) => m.id), ['fresh-model']);
      expect(app.settings.modelForProvider(provider), isNot(_old.id));
      expect(storage.saved.modelForProvider(provider), isNot(_old.id));
    });

    test('loading stays true until the latest request finishes', () async {
      final ai = _ControlledAiProvider();
      final app = AppController(
        storageService: _MemoryStorage(),
        aiProviderService: ai,
      );
      addTearDown(app.dispose);
      const provider = AiProviderType.openai;

      final first = app.refreshModelsFor(provider);
      final second = app.refreshModelsFor(provider);

      ai.pending[0].complete([_old]);
      await first;
      expect(app.isLoadingModels(provider), isTrue);

      ai.pending[1].complete([_fresh]);
      await second;
      expect(app.isLoadingModels(provider), isFalse);
    });
  });
}
