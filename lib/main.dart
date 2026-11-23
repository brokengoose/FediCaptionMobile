// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:material_ui/material_ui.dart';
import 'package:video_player_media_kit/video_player_media_kit.dart';

import 'app.dart';
import 'services/windows_tls_trust.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  VideoPlayerMediaKit.ensureInitialized(linux: true);
  await WindowsTlsTrust.initialize();
  runApp(const FediCaptionApp());
}
