// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

/// Lenient readers for loosely typed JSON (LLM output, quirky servers).
///
/// Unlike `as String?` / `as bool?` casts these never throw on an unexpected
/// type; they coerce what is reasonable and otherwise return the fallback.
library;

/// Returns [value] as a string; numbers/bools are stringified, other types
/// (maps, lists) yield `null`.
String? jsonString(Object? value) {
  if (value is String) return value;
  if (value is num || value is bool) return value.toString();
  return null;
}

/// Returns [value] as a bool, accepting `true`/`false`, `"true"`/`"yes"`/`"1"`
/// style strings and non-zero numbers.
bool jsonBool(Object? value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    switch (value.trim().toLowerCase()) {
      case 'true':
      case 'yes':
      case '1':
        return true;
      case 'false':
      case 'no':
      case '0':
        return false;
    }
  }
  return fallback;
}

/// Returns [value] as a list, or an empty list for any other type.
List<dynamic> jsonList(Object? value) =>
    value is List ? value : const <dynamic>[];
