// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'dart:convert';
import 'dart:typed_data';

import 'package:fedicaption_mobile/services/windows_tls_trust.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WindowsTlsTrust', () {
    test('derToPemBytes formats standard 64-column PEM certificate', () {
      final der = Uint8List.fromList(List<int>.generate(100, (i) => i % 256));
      final pem = ascii.decode(WindowsTlsTrust.derToPemBytes(der));
      final lines = pem.trim().split('\n');

      expect(lines.first, '-----BEGIN CERTIFICATE-----');
      expect(lines.last, '-----END CERTIFICATE-----');

      final bodyLines = lines.sublist(1, lines.length - 1);
      for (var i = 0; i < bodyLines.length - 1; i++) {
        expect(bodyLines[i].length, 64);
      }
      expect(bodyLines.last.length, inInclusiveRange(1, 64));

      final decoded = base64.decode(bodyLines.join());
      expect(decoded, orderedEquals(der));
    });

    test('initialize completes cleanly in test environment', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      await WindowsTlsTrust.initialize();
    });
  });
}
