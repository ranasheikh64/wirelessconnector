import 'package:flutter/material.dart';

class AppLogger extends ChangeNotifier {
  static final AppLogger _instance = AppLogger._internal();
  factory AppLogger() => _instance;
  AppLogger._internal();

  static AppLogger get instance => _instance;

  final List<String> logs = [];

  static void log(String message) {
    final now = DateTime.now();
    final time = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    _instance.logs.add('[$time] $message');
    
    // Keep max 500 lines to avoid memory leak
    if (_instance.logs.length > 500) {
      _instance.logs.removeAt(0);
    }
    
    // Notify UI safely
    Future.microtask(() => _instance.notifyListeners());
    debugPrint(message);
  }
}
