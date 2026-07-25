import 'dart:convert';

import '../domain/entities/sidecar_backup.dart';
import '../domain/entities/sidecar_manifest.dart';

/// Converts sidecar manifests and portable backups to and from JSON.
///
/// Encoding is pretty-printed so backups stay human-readable and diff cleanly.
/// Decoding is tolerant: malformed or foreign JSON yields null.
class SidecarSerializer {
  const SidecarSerializer();

  static const JsonEncoder _encoder = JsonEncoder.withIndent('  ');

  String encode(SidecarManifest manifest) =>
      _encoder.convert(manifest.toJson());

  String encodeBackup(SidecarBackup backup) =>
      _encoder.convert(backup.toJson());

  SidecarManifest? decode(String contents) {
    dynamic decoded;
    try {
      decoded = jsonDecode(contents);
    } on FormatException {
      return null;
    }
    if (decoded is! Map) {
      return null;
    }
    return SidecarManifest.fromJson(Map<String, dynamic>.from(decoded));
  }

  SidecarBackup? decodeBackup(String contents) {
    dynamic decoded;
    try {
      decoded = jsonDecode(contents);
    } on FormatException {
      return null;
    }
    if (decoded is! Map) {
      return null;
    }
    return SidecarBackup.fromJson(Map<String, dynamic>.from(decoded));
  }
}
