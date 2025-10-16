import 'dart:io';

import 'package:isar/isar.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Signature for resolving the directory used to store Isar database files.
typedef IsarDirectoryResolver = Future<Directory> Function();

/// Signature for opening an [Isar] instance. The default implementation uses
/// [Isar.open], but tests can inject a fake to avoid touching the filesystem.
typedef IsarOpenCallback = Future<Isar> Function(
  List<CollectionSchema<dynamic>> schemas, {
  required String directory,
  String name,
});

/// Handles lifecycle management for the shared [Isar] instance used across the
/// application. The service centralises configuration so repositories and data
/// sources can depend on a single entry point when interacting with the
/// database.
class IsarDatabase {
  IsarDatabase({
    required List<CollectionSchema<dynamic>> schemas,
    String name = 'media_fast_view',
    IsarDirectoryResolver? directoryResolver,
    IsarOpenCallback? openIsar,
  })  : _schemas = schemas,
        _name = name,
        _resolveDirectory = directoryResolver ?? _defaultDirectoryResolver,
        _openIsar = openIsar ?? Isar.open;

  final List<CollectionSchema<dynamic>> _schemas;
  final String _name;
  final IsarDirectoryResolver _resolveDirectory;
  final IsarOpenCallback _openIsar;

  Isar? _isar;

  /// Returns whether the Isar instance is currently open.
  bool get isOpen => _isar?.isOpen ?? false;

  /// Provides access to the lazily created [Isar] instance.
  ///
  /// Throws a [StateError] if the database has not been opened yet.
  Isar get instance {
    final isar = _isar;
    if (isar == null || !isar.isOpen) {
      throw StateError('Isar database has not been opened.');
    }
    return isar;
  }

  /// Opens (or retrieves) the Isar instance backed by the configured schemas.
  ///
  /// When [directory] is omitted the service resolves a default path under the
  /// application support directory. Subsequent calls reuse the cached instance
  /// to avoid repeated initialisation work.
  Future<Isar> open({Directory? directory}) async {
    final isar = _isar;
    if (isar != null && isar.isOpen) {
      return isar;
    }

    final resolvedDirectory = directory ?? await _resolveDirectory();
    final newIsar = await _openIsar(
      _schemas,
      directory: resolvedDirectory.path,
      name: _name,
    );
    _isar = newIsar;
    return newIsar;
  }

  /// Closes the shared Isar instance and releases resources. Safe to call even
  /// when the database has not been opened.
  Future<void> close() async {
    final isar = _isar;
    if (isar != null && isar.isOpen) {
      await isar.close();
    }
    _isar = null;
  }

  static Future<Directory> _defaultDirectoryResolver() async {
    final supportDir = await getApplicationSupportDirectory();
    final isarDir = Directory(p.join(supportDir.path, 'isar'));
    if (!await isarDir.exists()) {
      await isarDir.create(recursive: true);
    }
    return isarDir;
  }
}
