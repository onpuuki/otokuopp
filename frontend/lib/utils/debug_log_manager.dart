import 'package:flutter/foundation.dart';

class DebugLogManager {
  static final ValueNotifier<List<String>> logsNotifier = ValueNotifier<List<String>>([]);

  static void addLog(String message) {
    final timestamp = DateTime.now().toIso8601String();
    final newLog = '[$timestamp] $message';
    // Update the value with a new list to notify listeners
    logsNotifier.value = List.from(logsNotifier.value)..add(newLog);
  }

  static void clearLogs() {
    logsNotifier.value = [];
  }
}
