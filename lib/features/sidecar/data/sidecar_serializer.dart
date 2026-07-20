import 'dart:convert';

import '../domain/entities/sidecar_manifest.dart';

/// Converts a [SidecarManifest] to and from the JSON text stored on disk.
///
/// Encoding is pretty-printed so a `.mediafastview.json` stays human-readable
/// and diffs cleanly. Decoding is tolerant: anything that is not valid JSON, not
/// a JSON object, or not a Media Fast View manifest yields null rather than
/// throwing, so a stray or corrupt file is simply ignored.
class SidecarSerializer {
  const SidecarSerializer();

  static const JsonEncoder _encoder = JsonEncoder.withIndent('  ');

  String encode(SidecarManifest manifest) => _encoder.convert(manifest.toJson());

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
}
