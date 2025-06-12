import 'dart:developer' as developer;

class TerminalColors {
  // ANSI color codes
  static const String _reset = '\x1B[0m';
  static const String _red = '\x1B[31m';
  static const String _green = '\x1B[32m';
  static const String _yellow = '\x1B[33m';
  static const String _blue = '\x1B[34m';
  static const String _magenta = '\x1B[35m';
  static const String _cyan = '\x1B[36m';
  static const String _bold = '\x1B[1m';

  // Error message in red
  static void error(String message) {
    developer.log(
      '$_bold$_red[ERROR] $message$_reset',
      name: 'TerminalColors',
      error: message,
      level: 900, // ERROR level
    );
  }

  // Success message in green
  static void success(String message) {
    developer.log(
      '$_bold$_green[SUCCESS] $message$_reset',
      name: 'TerminalColors',
      level: 800, // INFO level
    );
  }

  // Warning message in yellow
  static void warning(String message) {
    developer.log(
      '$_bold$_yellow[WARNING] $message$_reset',
      name: 'TerminalColors',
      level: 700, // WARNING level
    );
  }

  // Info message in blue
  static void info(String message) {
    developer.log(
      '$_bold$_blue[INFO] $message$_reset',
      name: 'TerminalColors',
      level: 600, // INFO level
    );
  }

  // Debug message in cyan
  static void debug(String message) {
    developer.log(
      '$_bold$_cyan[DEBUG] $message$_reset',
      name: 'TerminalColors',
      level: 500, // DEBUG level
    );
  }

  // Custom message with specified color
  static void custom(String message, String color) {
    developer.log(
      '$color$message$_reset',
      name: 'TerminalColors',
      level: 400, // FINE level
    );
  }

  // Progress message in magenta
  static void progress(String message) {
    developer.log(
      '$_bold$_magenta[PROGRESS] $message$_reset',
      name: 'TerminalColors',
      level: 300, // FINER level
    );
  }

  // Clear terminal
  static void clear() {
    developer.log(
      '\x1B[2J\x1B[0;0H',
      name: 'TerminalColors',
      level: 200, // FINEST level
    );
  }
}
