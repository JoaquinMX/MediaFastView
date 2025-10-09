enum LogLevel {
  debug,
  info,
  warning,
  error,
}

class LogRecord {
  const LogRecord({
    required this.timestamp,
    required this.level,
    required this.message,
    this.context,
  });

  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final Map<String, dynamic>? context;
}

abstract class LogOutput {
  void write(LogLevel level, String message, Map<String, dynamic>? context);
}

class ConsoleLogOutput implements LogOutput {
  @override
  void write(LogLevel level, String message, Map<String, dynamic>? context) {
    final timestamp = DateTime.now().toIso8601String();
    final levelStr = level.name.toUpperCase();
    final contextStr = context != null ? ' ${context.toString()}' : '';
    print('[$timestamp] $levelStr: $message$contextStr');
  }
}

abstract class Logger {
  void log(LogLevel level, String message, [Map<String, dynamic>? context]);
  void debug(String message, [Map<String, dynamic>? context]);
  void info(String message, [Map<String, dynamic>? context]);
  void warning(String message, [Map<String, dynamic>? context]);
  void error(String message, [Map<String, dynamic>? context]);
}

class LoggingService implements Logger {
  static final LoggingService instance = LoggingService._();

  final List<LogOutput> _outputs;
  final LogLevel _minLevel;
  final int _maxHistory;
  final List<LogRecord> _history = [];

  LoggingService._({
    List<LogOutput>? outputs,
    LogLevel minLevel = LogLevel.debug,
    int maxHistory = 2000,
  })  : _outputs = outputs ?? [ConsoleLogOutput()],
        _minLevel = minLevel,
        _maxHistory = maxHistory;

  factory LoggingService({
    List<LogOutput>? outputs,
    LogLevel minLevel = LogLevel.debug,
    int maxHistory = 2000,
  }) {
    return LoggingService._(
      outputs: outputs,
      minLevel: minLevel,
      maxHistory: maxHistory,
    );
  }

  List<LogRecord> get history => List.unmodifiable(_history);

  Iterable<LogRecord> getHistory({LogLevel? minLevel, DateTime? since}) {
    return _history.where((record) {
      final levelMatches =
          minLevel == null || record.level.index >= minLevel.index;
      final timestampMatches = since == null ||
          record.timestamp.isAfter(since) ||
          record.timestamp.isAtSameMomentAs(since);
      return levelMatches && timestampMatches;
    });
  }

  void clearHistory() => _history.clear();

  @override
  void log(LogLevel level, String message, [Map<String, dynamic>? context]) {
    final record = LogRecord(
      timestamp: DateTime.now(),
      level: level,
      message: message,
      context: context == null ? null : Map.unmodifiable(context),
    );

    _history.add(record);
    if (_history.length > _maxHistory) {
      _history.removeRange(0, _history.length - _maxHistory);
    }

    if (level.index >= _minLevel.index) {
      for (final output in _outputs) {
        output.write(level, message, context);
      }
    }
  }

  @override
  void debug(String message, [Map<String, dynamic>? context]) {
    log(LogLevel.debug, message, context);
  }

  @override
  void info(String message, [Map<String, dynamic>? context]) {
    log(LogLevel.info, message, context);
  }

  @override
  void warning(String message, [Map<String, dynamic>? context]) {
    log(LogLevel.warning, message, context);
  }

  @override
  void error(String message, [Map<String, dynamic>? context]) {
    log(LogLevel.error, message, context);
  }

  void addOutput(LogOutput output) {
    _outputs.add(output);
  }

  void removeOutput(LogOutput output) {
    _outputs.remove(output);
  }
}
