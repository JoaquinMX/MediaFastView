import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../features/media_library/domain/entities/media_entity.dart';

/// Result produced by [ThumbnailMetadataService] after processing a media file.
class ThumbnailMetadataResult {
  const ThumbnailMetadataResult({
    this.thumbnailPath,
    this.width,
    this.height,
    this.duration,
    this.metadata,
  });

  final String? thumbnailPath;
  final int? width;
  final int? height;
  final Duration? duration;
  final Map<String, dynamic>? metadata;
}

/// Generates thumbnails and extracts metadata for media files.
class ThumbnailMetadataService {
  Directory? _thumbnailDirectory;

  Future<ThumbnailMetadataResult> process(
    String filePath,
    MediaType type,
  ) async {
    switch (type) {
      case MediaType.image:
        return _processImage(filePath);
      case MediaType.video:
        return ThumbnailMetadataResult(metadata: <String, dynamic>{'source': 'video'});
      case MediaType.audio:
        return ThumbnailMetadataResult(metadata: <String, dynamic>{'source': 'audio'});
      case MediaType.document:
        return ThumbnailMetadataResult(metadata: <String, dynamic>{'source': 'document'});
      case MediaType.text:
      case MediaType.directory:
        return const ThumbnailMetadataResult();
    }
  }

  Future<void> clearOrphanedThumbnails(Iterable<String> activePaths) async {
    final directory = await _ensureThumbnailDirectory();
    if (!await directory.exists()) {
      return;
    }

    final activeSet = activePaths.toSet();
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is File && !activeSet.contains(entity.path)) {
        await entity.delete().catchError((_) {});
      }
    }
  }

  Future<ThumbnailMetadataResult> _processImage(String filePath) async {
    final directory = await _ensureThumbnailDirectory();
    final file = File(filePath);
    if (!await file.exists()) {
      return const ThumbnailMetadataResult();
    }

    final targetPath = p.join(
      directory.path,
      '${_sanitizeFileName(p.basename(filePath))}.jpg',
    );

    final filePathForIsolate = file.path;
    final targetPathForIsolate = targetPath;
    final result = await Isolate.run(() async {
      final file = File(filePathForIsolate);
      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        return _ImageMetadata();
      }

      final thumbnail = img.copyResize(decoded, width: 512);
      final encoded = img.encodeJpg(thumbnail, quality: 85);
      await File(targetPathForIsolate).writeAsBytes(encoded, flush: true);
      return _ImageMetadata(
        width: decoded.width,
        height: decoded.height,
        thumbnailPath: targetPathForIsolate,
      );
    });

    return ThumbnailMetadataResult(
      thumbnailPath: result.thumbnailPath,
      width: result.width,
      height: result.height,
      metadata: result.metadata,
    );
  }

  Future<Directory> _ensureThumbnailDirectory() async {
    final existing = _thumbnailDirectory;
    if (existing != null) {
      return existing;
    }

    final baseDir = await getTemporaryDirectory();
    final directory = Directory(p.join(baseDir.path, 'thumbnails'));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    _thumbnailDirectory = directory;
    return directory;
  }

  String _sanitizeFileName(String input) {
    return input.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
  }
}

class _ImageMetadata {
  _ImageMetadata({
    this.thumbnailPath,
    this.width,
    this.height,
    this.metadata,
  });

  final String? thumbnailPath;
  final int? width;
  final int? height;
  final Map<String, dynamic>? metadata;
}
