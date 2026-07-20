import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:media_fast_view/features/thumbnails/domain/thumbnail_request.dart';

typedef CacheDirectoryResolver = Future<Directory> Function();

/// A content-addressed, bounded cache for encoded thumbnail files.
class ThumbnailDiskCache {
  ThumbnailDiskCache({
    CacheDirectoryResolver? directoryResolver,
    this.maximumBytes = defaultMaximumBytes,
  }) : _directoryResolver =
           directoryResolver ?? _defaultApplicationCacheDirectory;

  static const int defaultMaximumBytes = 1024 * 1024 * 1024;
  static const int _algorithmVersion = 1;
  static const int _trimWriteInterval = 100;

  final CacheDirectoryResolver _directoryResolver;
  final int maximumBytes;
  int _writesSinceTrim = 0;
  Future<void>? _trimFuture;

  String keyFor(ThumbnailRequest request) {
    final fingerprint = <Object>[
      _algorithmVersion,
      p.normalize(request.path),
      request.mediaType.name,
      request.sourceSize,
      request.sourceLastModified.microsecondsSinceEpoch,
      request.thumbnailSize.maxPixelSize,
    ].join('\u0000');
    return sha256.convert(utf8.encode(fingerprint)).toString();
  }

  Future<File?> read(ThumbnailRequest request) async {
    final file = await _fileForKey(keyFor(request));
    try {
      final stat = await file.stat();
      if (stat.type != FileSystemEntityType.file || stat.size <= 0) {
        if (stat.type == FileSystemEntityType.file) {
          await file.delete();
        }
        return null;
      }

      final now = DateTime.now();
      if (now.difference(stat.modified) > const Duration(days: 1)) {
        await file.setLastModified(now);
      }
      return file;
    } on FileSystemException {
      return null;
    }
  }

  Future<File> write(ThumbnailRequest request, List<int> bytes) async {
    if (bytes.isEmpty) {
      throw const FileSystemException('Cannot cache an empty thumbnail');
    }

    final key = keyFor(request);
    final target = await _fileForKey(key);
    await target.parent.create(recursive: true);
    final temporary = File(
      p.join(
        target.parent.path,
        '.$key.${DateTime.now().microsecondsSinceEpoch}.tmp',
      ),
    );

    try {
      await temporary.writeAsBytes(bytes, flush: true);
      if (await target.exists()) {
        await temporary.delete();
      } else {
        await temporary.rename(target.path);
      }
    } catch (_) {
      if (await temporary.exists()) {
        await temporary.delete();
      }
      rethrow;
    }

    _writesSinceTrim += 1;
    if (_writesSinceTrim >= _trimWriteInterval) {
      _writesSinceTrim = 0;
      _trimFuture ??= _runScheduledTrim().whenComplete(
        () => _trimFuture = null,
      );
    }
    return target;
  }

  Future<void> invalidate(ThumbnailRequest request) async {
    final file = await _fileForKey(keyFor(request));
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<int> sizeInBytes() async {
    final directory = await _cacheDirectory();
    if (!await directory.exists()) {
      return 0;
    }

    var total = 0;
    await for (final entity in directory.list(recursive: true)) {
      if (entity is File && !entity.path.endsWith('.tmp')) {
        try {
          total += await entity.length();
        } on FileSystemException {
          // A concurrent clear or trim may remove a file between listing and
          // stat. It simply no longer contributes to the cache size.
        }
      }
    }
    return total;
  }

  Future<void> clear() async {
    final directory = await _cacheDirectory();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  Future<void> trim() async {
    final directory = await _cacheDirectory();
    if (!await directory.exists()) {
      return;
    }

    final entries = <({File file, int size, DateTime modified})>[];
    var total = 0;
    await for (final entity in directory.list(recursive: true)) {
      if (entity is! File) {
        continue;
      }
      if (entity.path.endsWith('.tmp')) {
        try {
          await entity.delete();
        } on FileSystemException {
          // Best-effort cleanup of abandoned temporary files.
        }
        continue;
      }
      try {
        final stat = await entity.stat();
        entries.add((file: entity, size: stat.size, modified: stat.modified));
        total += stat.size;
      } on FileSystemException {
        // Ignore entries that disappear during the scan.
      }
    }

    if (total <= maximumBytes) {
      return;
    }

    entries.sort((left, right) => left.modified.compareTo(right.modified));
    final targetBytes = (maximumBytes * 0.9).floor();
    for (final entry in entries) {
      if (total <= targetBytes) {
        break;
      }
      try {
        await entry.file.delete();
        total -= entry.size;
      } on FileSystemException {
        // Continue trimming other entries.
      }
    }
  }

  Future<File> _fileForKey(String key) async {
    final directory = await _cacheDirectory();
    return File(p.join(directory.path, key.substring(0, 2), '$key.jpg'));
  }

  Future<Directory> _cacheDirectory() async {
    final root = await _directoryResolver();
    return Directory(p.join(root.path, 'thumbnails', 'v$_algorithmVersion'));
  }

  static Future<Directory> _defaultApplicationCacheDirectory() {
    return getApplicationCacheDirectory();
  }

  Future<void> _runScheduledTrim() async {
    try {
      await trim();
    } catch (_) {
      // Cache eviction is best-effort; foreground generation must continue if
      // the cache directory is temporarily unavailable.
    }
  }
}
