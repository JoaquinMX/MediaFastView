import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Generates a stable ID for a directory path using SHA-256.
///
/// The ID generation is centralized to guarantee that every layer
/// (data sources, repositories, and presentation) references directories
/// with the same identifier regardless of platform hash implementations.
String generateDirectoryId(String directoryPath) {
  final normalizedPath = directoryPath.trim();
  final bytes = utf8.encode(normalizedPath);
  return sha256.convert(bytes).toString();
}
