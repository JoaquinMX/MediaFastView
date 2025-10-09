import 'dart:async';
import 'dart:io';

import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'models/directory_record.dart';
import 'models/favorite_record.dart';
import 'models/media_record.dart';
import 'models/tag_record.dart';

/// Provides a lazily initialised singleton [Isar] instance for the app.
class IsarDatabase {
  IsarDatabase._(this.instance);

  /// Currently open Isar instance.
  final Isar instance;

  static Isar? _cachedInstance;

  /// Opens (or reuses) the application Isar database.
  static Future<Isar> open() async {
    final existing = _cachedInstance;
    if (existing != null && existing.isOpen) {
      return existing;
    }

    final dir = await _resolveDirectory();
    final isar = await Isar.open(
      [
        DirectoryRecordSchema,
        MediaRecordSchema,
        TagRecordSchema,
        FavoriteRecordSchema,
      ],
      directory: dir.path,
      inspector: false,
    );

    _cachedInstance = isar;
    return isar;
  }

  /// Closes the cached instance if it exists.
  static Future<void> close() async {
    final existing = _cachedInstance;
    if (existing != null && existing.isOpen) {
      await existing.close();
    }
    _cachedInstance = null;
  }

  static Future<Directory> _resolveDirectory() async {
    if (Platform.isIOS || Platform.isMacOS) {
      final dir = await getApplicationSupportDirectory();
      return Directory('${dir.path}/isar');
    }

    final dir = await getApplicationDocumentsDirectory();
    return Directory('${dir.path}/isar');
  }
}
