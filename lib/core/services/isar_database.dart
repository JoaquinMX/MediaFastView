import 'dart:io';

import 'package:isar/isar.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'logging_service.dart';

/// Signature for resolving the directory used to store Isar database files.
typedef IsarDirectoryResolver = Future<Directory> Function();

/// Signature for opening an [Isar] instance. The default implementation uses
/// [Isar.open], but tests can inject a fake to avoid touching the filesystem.
typedef IsarOpenCallback = Future<Isar> Function(
  List<CollectionSchema<dynamic>> schemas, {
  required String directory,
  String name,
});

/// Signature for work that must run against a freshly opened [Isar] before any
/// data source is allowed to touch it.
///
/// [backUp] snapshots the database file. The migration is expected to call it
/// immediately before it mutates anything, and not at all when it decides there
/// is nothing to do — otherwise every launch would leave a backup behind.
typedef IsarMigrationCallback = Future<void> Function(
  Isar isar,
  Future<void> Function() backUp,
);

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
    IsarMigrationCallback? migrate,
  })  : _schemas = schemas,
        _name = name,
        _resolveDirectory = directoryResolver ?? _defaultDirectoryResolver,
        _openIsar = openIsar ?? Isar.open,
        _migrate = migrate;

  final List<CollectionSchema<dynamic>> _schemas;
  final String _name;
  final IsarDirectoryResolver _resolveDirectory;
  final IsarOpenCallback _openIsar;
  final IsarMigrationCallback? _migrate;

  Isar? _isar;

  /// The in-flight open, so concurrent callers wait on one rather than racing.
  Future<Isar>? _opening;

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
  ///
  /// Concurrent callers share one open. The provider kicks off an unawaited
  /// `open()` while every data source also opens lazily, so without this the
  /// migration below could be started twice against the same database.
  Future<Isar> open({Directory? directory}) {
    final isar = _isar;
    if (isar != null && isar.isOpen) {
      return Future<Isar>.value(isar);
    }

    return _opening ??= _open(directory: directory).whenComplete(() {
      _opening = null;
    });
  }

  Future<Isar> _open({Directory? directory}) async {
    final resolvedDirectory = directory ?? await _resolveDirectory();
    final newIsar = await _openIsar(
      _schemas,
      directory: resolvedDirectory.path,
      name: _name,
    );

    await _runMigration(newIsar, resolvedDirectory);

    // Published only now. Data sources open lazily via `if (!isOpen) await
    // open()`, so leaving `_isar` unset until the migration has committed is
    // what stops one of them reading — or worse, writing — against a database
    // that is about to be cleared and re-put.
    _isar = newIsar;
    return newIsar;
  }

  Future<void> _runMigration(Isar isar, Directory directory) async {
    final migrate = _migrate;
    if (migrate == null) {
      return;
    }

    await migrate(isar, () => _backUp(directory));
  }

  /// Copies the database file alongside itself.
  ///
  /// Called by a migration just before it mutates. Tags, favorites and the macOS
  /// bookmarks that grant folder access exist nowhere else on disk, so a copy
  /// costs little next to what it protects.
  ///
  /// Best-effort: a failed backup must not stop the app from opening. The
  /// migration it guards is a single atomic transaction and cannot half-apply —
  /// this is insurance, not a correctness requirement.
  Future<void> _backUp(Directory directory) async {
    try {
      final source = File(p.join(directory.path, '$_name.isar'));
      if (!await source.exists()) {
        return; // A fresh database has nothing to lose.
      }

      final stamp = DateTime.now().toIso8601String().split('T').first;
      final backup = File(p.join(directory.path, '$_name.isar.$stamp.bak'));
      if (await backup.exists()) {
        return; // Already taken today; do not clobber it with newer state.
      }

      await source.copy(backup.path);
    } catch (error) {
      LoggingService.instance.warning(
        'Could not back up the Isar database before migrating: $error',
      );
    }
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
