import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:isar/isar.dart';

/// Mimics the hashing logic used by Isar collection id getters.
Id isarIdForString(String value) {
  final hash = sha256.convert(utf8.encode(value)).bytes;
  return hash.fold<int>(0, (previousValue, element) => previousValue + element);
}
