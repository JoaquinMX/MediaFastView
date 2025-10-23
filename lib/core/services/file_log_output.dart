import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'logging_service.dart';

class FileLogOutput implements LogOutput {
  FileLogOutput._(this._file);

  static const String _defaultFileName = 'media_fast_view.log';
  static const int _maxLogSizeBytes = 5 * 1024 * 1024; // 5 MB

  final File _file;

  String get filePath => _file.path;

  static Future<FileLogOutput> create({String? fileName}) async {
    final directory = await getApplicationSupportDirectory();
    final logDir = Directory(p.join(directory.path, 'logs'));
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }

    final resolvedFileName = fileName ?? _defaultFileName;
    var logFile = File(p.join(logDir.path, resolvedFileName));

    if (await logFile.exists()) {
      final currentSize = await logFile.length();
      if (currentSize >= _maxLogSizeBytes) {
        final timestamp = DateTime.now()
            .toIso8601String()
            .replaceAll(':', '-')
            .replaceAll('.', '-');
        final rotated = File(p.join(logDir.path, 'media_fast_view_$timestamp.log'));
        try {
          await logFile.rename(rotated.path);
        } catch (error) {
          debugPrint('Failed to rotate log file: $error');
        }
        logFile = File(p.join(logDir.path, resolvedFileName));
      }
    }

    return FileLogOutput._(logFile);
  }

  @override
  void write(LogLevel level, String message, Map<String, dynamic>? context) {
    final timestamp = DateTime.now().toIso8601String();
    final levelStr = level.name.toUpperCase();
    final contextStr = context != null && context.isNotEmpty
        ? ' ${context.toString()}'
        : '';
    final entry = '[$timestamp] $levelStr: $message$contextStr\n';

    try {
      _file.writeAsStringSync(entry, mode: FileMode.append, flush: true);
    } catch (error) {
      debugPrint('Failed to write log entry: $error');
    }
  }
}
