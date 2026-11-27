// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

typedef _AllocNative = Pointer<Uint8> Function(Int32 size);
typedef _AllocDart = Pointer<Uint8> Function(int size);

typedef _FreeNative = Void Function(Pointer<Uint8> ptr);
typedef _FreeDart = void Function(Pointer<Uint8> ptr);

typedef _VerifyNative = Int32 Function(
  Pointer<Uint8> der,
  Int32 derLen,
  Pointer<Uint8> hostUtf8,
  Int32 hostLen,
);
typedef _VerifyDart = int Function(
  Pointer<Uint8> der,
  int derLen,
  Pointer<Uint8> hostUtf8,
  int hostLen,
);

/// Bridges Dart's `dart:io` BoringSSL client to the native Windows Certificate
/// Store (`crypt32.lib`) so Windows builds trust the exact same root CAs and
/// SSL chains as Windows, Edge, Chrome, and Firefox without disabling TLS checks.
class WindowsTlsTrust {
  WindowsTlsTrust._();

  static const MethodChannel _channel = MethodChannel(
    'io.github.brokengoose.fedicaption/windows_certs',
  );

  static bool _initialized = false;

  /// Loads Windows Trusted Root CAs into `SecurityContext.defaultContext` and
  /// registers a Windows CryptoAPI `CertVerifyCertificateChainPolicy(SSL)`
  /// fallback verifier on `HttpOverrides.global`.
  ///
  /// No-op on non-Windows platforms and web.
  static Future<void> initialize() async {
    if (_initialized || kIsWeb || !Platform.isWindows) return;
    _initialized = true;

    // Layer 1: Pre-load Windows ROOT store CAs into BoringSSL's default context.
    try {
      final rawCerts = await _channel.invokeMethod<List<Object?>>(
        'getTrustedRootCerts',
      );
      if (rawCerts != null) {
        final ctx = SecurityContext.defaultContext;
        for (final item in rawCerts) {
          if (item is Uint8List && item.isNotEmpty) {
            try {
              ctx.setTrustedCertificatesBytes(derToPemBytes(item));
            } catch (_) {
              // Skip certificates already present in BoringSSL or unsupported.
            }
          }
        }
      }
    } catch (_) {
      // Continue to Layer 2 CryptoAPI fallback even if channel fails.
    }

    // Layer 2: Synchronous CryptoAPI SSL chain verification fallback (handles
    // Windows Auto-Root Update, AIA intermediate fetches, and corporate/AV CAs).
    try {
      final lib = DynamicLibrary.executable();
      final alloc = lib.lookupFunction<_AllocNative, _AllocDart>(
        'fedicaption_alloc',
      );
      final free = lib.lookupFunction<_FreeNative, _FreeDart>(
        'fedicaption_free',
      );
      final verify = lib.lookupFunction<_VerifyNative, _VerifyDart>(
        'fedicaption_verify_windows_cert',
      );
      HttpOverrides.global = _WindowsCryptoApiHttpOverrides(
        alloc: alloc,
        free: free,
        verify: verify,
      );
    } catch (_) {
      // If FFI symbols aren't available (e.g. unit tests), leave default overrides.
    }
  }

  /// Encodes raw X.509 DER bytes into standard 64-column PEM bytes accepted by
  /// `SecurityContext.setTrustedCertificatesBytes`.
  static List<int> derToPemBytes(Uint8List der) {
    final encoded = base64.encode(der);
    final buffer = StringBuffer('-----BEGIN CERTIFICATE-----\n');
    for (var i = 0; i < encoded.length; i += 64) {
      final end = (i + 64 < encoded.length) ? i + 64 : encoded.length;
      buffer.writeln(encoded.substring(i, end));
    }
    buffer.writeln('-----END CERTIFICATE-----');
    return ascii.encode(buffer.toString());
  }
}

class _WindowsCryptoApiHttpOverrides extends HttpOverrides {
  _WindowsCryptoApiHttpOverrides({
    required this._alloc,
    required this._free,
    required this._verify,
  });

  final _AllocDart _alloc;
  final _FreeDart _free;
  final _VerifyDart _verify;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.badCertificateCallback =
        (X509Certificate cert, String host, int port) {
          return _verifyWithWindowsCryptoApi(cert.der, host);
        };
    return client;
  }

  bool _verifyWithWindowsCryptoApi(Uint8List der, String host) {
    if (der.isEmpty || host.trim().isEmpty) return false;
    final hostBytes = utf8.encode(host.trim());
    final derPtr = _alloc(der.length);
    final hostPtr = _alloc(hostBytes.length);
    if (derPtr == nullptr || hostPtr == nullptr) {
      if (derPtr != nullptr) _free(derPtr);
      if (hostPtr != nullptr) _free(hostPtr);
      return false;
    }
    try {
      derPtr.asTypedList(der.length).setAll(0, der);
      hostPtr.asTypedList(hostBytes.length).setAll(0, hostBytes);
      return _verify(derPtr, der.length, hostPtr, hostBytes.length) == 1;
    } catch (_) {
      return false;
    } finally {
      _free(derPtr);
      _free(hostPtr);
    }
  }
}
