enum LogLevel {
  debug,
  info,
  warning,
  error,
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
  void healthCheck(
    String stage, {
    LogLevel level = LogLevel.info,
    Map<String, dynamic>? context,
  });
}

class LoggingService implements Logger {
  static final LoggingService instance = LoggingService._();

  final List<LogOutput> _outputs;
  final LogLevel _minLevel;

  LoggingService._({
    List<LogOutput>? outputs,
    LogLevel minLevel = LogLevel.debug,
  }) : _outputs = outputs ?? [ConsoleLogOutput()], _minLevel = minLevel;

  factory LoggingService({
    List<LogOutput>? outputs,
    LogLevel minLevel = LogLevel.debug,
  }) {
    return LoggingService._(outputs: outputs, minLevel: minLevel);
  }

  @override
  void log(LogLevel level, String message, [Map<String, dynamic>? context]) {
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

  @override
  void healthCheck(
    String stage, {
    LogLevel level = LogLevel.info,
    Map<String, dynamic>? context,
  }) {
    final healthContext = <String, dynamic>{
      'stage': stage,
      if (context != null) ...context,
    };
    log(level, 'library_health_check', healthContext);
  }

  void addOutput(LogOutput output) {
    _outputs.add(output);
  }

  void removeOutput(LogOutput output) {
    _outputs.remove(output);
  }
}