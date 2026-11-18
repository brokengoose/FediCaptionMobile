// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

/// Helper for announcing asynchronous events to iOS VoiceOver and Android TalkBack.
class AccessibilityAnnouncer {
  AccessibilityAnnouncer._();

  static void announce(
    String message, {
    TextDirection textDirection = TextDirection.ltr,
  }) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;
    SemanticsService.announce(trimmed, textDirection);
  }
}
