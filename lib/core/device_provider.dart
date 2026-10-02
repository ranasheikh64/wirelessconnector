import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pasteboard/pasteboard.dart';

import 'adb_service.dart';
import 'device_model.dart';
import 'logger.dart';

class DeviceProvider extends ChangeNotifier {
  final AdbService _adb = AdbService();

  // ── State ──────────────────────────────────────────────
  List<DeviceInfo> devices = [];
  DeviceInfo? selectedDevice;
  Uint8List? currentScreenshot;

  bool isAdbAvailable = false;
  bool isCheckingAdb = true;
  bool isScreenshotRefreshing = false;
  bool autoRefreshEnabled = false;
  int autoRefreshIntervalMs = 600; // 600ms = ~1.6 fps — best balance

  bool isScrcpyAvailable = false;
  bool isScrcpyRunning = false;

  String? statusMessage;
  String? errorMessage;

  // ── Timers ─────────────────────────────────────────────
  Timer? _devicePollTimer;
  Timer? _screenshotTimer;

  // Track in-flight screenshot to avoid stacking
  bool _screenshotInProgress = false;

  AdbService get adbService => _adb;

  // ─────────────────────────────────────────────────────────
  // Init
  // ─────────────────────────────────────────────────────────

  Future<void> initialize() async {
    isCheckingAdb = true;
    notifyListeners();

    isAdbAvailable = await _adb.isAdbInstalled();

    if (isAdbAvailable) {
      await _adb.startServer();
      _startDevicePolling();
      // Check if scrcpy is installed
      final scrcpy = await _adb.resolveScrcpy();
      isScrcpyAvailable = scrcpy != null;
      AppLogger.log('Scrcpy available: $isScrcpyAvailable (path: $scrcpy)');
    }

    isCheckingAdb = false;
    notifyListeners();
  }

  Future<void> restartAdbServer() async {
    AppLogger.log('Killing all ADB instances (Fix Conflict)...');
    try {
      await Process.run('killall', ['adb']);
    } catch (_) {}
    try {
      await _adb.startServer();
    } catch (_) {}
    AppLogger.log('ADB server restarted.');
    await _refreshDevices();
  }

  // ─────────────────────────────────────────────────────────
  // Device Polling
  // ─────────────────────────────────────────────────────────

  void _startDevicePolling() {
    _devicePollTimer?.cancel();
    _devicePollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _refreshDevices(),
    );
    _refreshDevices();
  }

  Future<void> _refreshDevices() async {
    final ids = await _adb.listDeviceIds();

    final updated = <DeviceInfo>[];
    for (final id in ids) {
      final existing = devices.firstWhere(
        (d) => d.id == id,
        orElse: () => DeviceInfo(
          id: id,
          model: '',
          androidVersion: '',
          ipAddress: id.contains(':') ? id.split(':').first : id,
          port: id.contains(':') ? id.split(':').last : '5555',
        ),
      );

      if (existing.model.isEmpty) {
        final model = await _adb.getModel(id);
        final android = await _adb.getAndroidVersion(id);
        final battery = await _adb.getBatteryLevel(id);
        updated.add(existing.copyWith(
          model: model,
          androidVersion: android,
          batteryLevel: battery,
          isConnected: true,
        ));
      } else {
        final battery = await _adb.getBatteryLevel(id);
        updated.add(existing.copyWith(batteryLevel: battery, isConnected: true));
      }
    }

    for (final old in devices) {
      if (!updated.any((d) => d.id == old.id)) {
        updated.add(old.copyWith(isConnected: false));
      }
    }

    devices = updated;

    if (selectedDevice != null) {
      final found = devices.firstWhere(
        (d) => d.id == selectedDevice!.id,
        orElse: () => selectedDevice!.copyWith(isConnected: false),
      );
      selectedDevice = found;
      if (!found.isConnected) {
        currentScreenshot = null;
        _stopScreenshotRefresh();
      }
    }

    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────
  // Connect / Pair / Disconnect
  // ─────────────────────────────────────────────────────────

  Future<(PairResult, String)> pairDevice(String ip, String port, String code) async {
    setStatus('Pairing $ip:$port...');
    AppLogger.log('Starting pairing process for $ip:$port with code $code...');
    final result = await _adb.pairDevice(ip, port, code);
    if (result.$1 == PairResult.success) {
      setStatus('Paired! Connecting...');
      AppLogger.log('Pairing successful for $ip:$port');
    } else {
      setError('Pairing failed. Check code and try again.');
      AppLogger.log('Pairing failed: ${result.$2}');
    }
    return result;
  }

  Future<ConnectResult> connectDevice(String ip, String port) async {
    setStatus('Connecting to $ip:$port...');
    AppLogger.log('Attempting to connect to $ip:$port...');
    final result = await _adb.connectDevice(ip, port);
    if (result == ConnectResult.success) {
      setStatus('Connected!');
      AppLogger.log('Successfully connected to $ip:$port');
      await _saveDeviceHistory('$ip:$port');
      await _refreshDevices();
    } else {
      setError('Connection failed. Ensure Wireless Debugging is ON.');
      AppLogger.log('Connection failed for $ip:$port (Result: $result)');
    }
    return result;
  }

  Future<void> reconnectDevice(DeviceInfo device) async {
    final parts = device.id.split(':');
    final ip = parts.first;
    final port = parts.length > 1 ? parts.last : '5555';
    await connectDevice(ip, port);
  }


  Future<void> disconnectDevice(DeviceInfo device) async {
    await _adb.disconnectDevice(device.id);
    if (selectedDevice?.id == device.id) {
      selectedDevice = null;
      currentScreenshot = null;
      _stopScreenshotRefresh();
    }
    await _refreshDevices();
  }

  void selectDevice(DeviceInfo device) {
    selectedDevice = device;
    currentScreenshot = null;
    notifyListeners();
    // Auto-start refresh when device is selected
    _startScreenshotRefresh();
    autoRefreshEnabled = true;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────
  // Scrcpy — Live Screen (Android Studio approach)
  // ─────────────────────────────────────────────────────────

  /// Launch scrcpy for true real-time live screen preview.
  /// This is the same technology Android Studio uses.
  Future<bool> launchLiveScreen() async {
    final device = selectedDevice;
    if (device == null || !device.isConnected) return false;

    // Stop screenshot auto-refresh so it doesn't interfere with scrcpy
    if (autoRefreshEnabled) {
      toggleAutoRefresh();
    }

    setStatus('Launching Live Screen...');
    isScrcpyRunning = true;
    notifyListeners();

    final success = await _adb.launchScrcpy(device.id);

    if (success) {
      setStatus('Live Screen launched in separate window!');
    } else {
      setError(
        'scrcpy not found. Install it with:\nbrew install scrcpy\n\n'
        'Falling back to screenshot preview.',
      );
    }

    isScrcpyRunning = false;
    notifyListeners();
    return success;
  }

  // ─────────────────────────────────────────────────────────
  // Screenshot — Fast Polling Preview
  // ─────────────────────────────────────────────────────────

  Future<void> captureScreenshot() async {
    final device = selectedDevice;
    if (device == null || !device.isConnected) return;

    // Skip if previous capture still in flight (avoid stacking)
    if (_screenshotInProgress) return;
    _screenshotInProgress = true;

    isScreenshotRefreshing = true;
    notifyListeners();

    final bytes = await _adb.captureScreenshot(device.id);
    if (bytes != null && bytes.isNotEmpty) {
      currentScreenshot = bytes;
    }

    isScreenshotRefreshing = false;
    _screenshotInProgress = false;
    notifyListeners();
  }

  Future<void> captureAndCopyScreenshot() async {
    final device = selectedDevice;
    if (device == null || !device.isConnected) return;

    setStatus('Capturing screenshot...');
    isScreenshotRefreshing = true;
    notifyListeners();

    final bytes = await _adb.captureScreenshot(device.id);
    if (bytes != null && bytes.isNotEmpty) {
      currentScreenshot = bytes;
      await Pasteboard.writeImage(bytes);
      setStatus('Screenshot copied to clipboard!');
    } else {
      setError('Failed to capture screenshot');
    }

    isScreenshotRefreshing = false;
    notifyListeners();
  }

  void toggleAutoRefresh() {
    autoRefreshEnabled = !autoRefreshEnabled;
    if (autoRefreshEnabled) {
      _startScreenshotRefresh();
    } else {
      _stopScreenshotRefresh();
    }
    notifyListeners();
  }

  void setRefreshInterval(int ms) {
    autoRefreshIntervalMs = ms;
    if (autoRefreshEnabled) {
      _startScreenshotRefresh();
    }
    notifyListeners();
  }

  void _startScreenshotRefresh() {
    _screenshotTimer?.cancel();
    _screenshotTimer = Timer.periodic(
      Duration(milliseconds: autoRefreshIntervalMs),
      (_) => captureScreenshot(),
    );
    // Immediate first capture
    captureScreenshot();
  }

  void _stopScreenshotRefresh() {
    _screenshotTimer?.cancel();
    _screenshotTimer = null;
  }

  // ─────────────────────────────────────────────────────────
  // Input
  // ─────────────────────────────────────────────────────────

  Future<void> sendTap(int x, int y) async {
    final id = selectedDevice?.id;
    if (id == null) return;
    await _adb.sendTap(id, x, y);
  }

  Future<void> sendSwipe(int x1, int y1, int x2, int y2) async {
    final id = selectedDevice?.id;
    if (id == null) return;
    await _adb.sendSwipe(id, x1, y1, x2, y2);
  }

  Future<void> sendKey(int keyCode) async {
    final id = selectedDevice?.id;
    if (id == null) return;
    await _adb.sendKey(id, keyCode);
  }

  Future<void> sendText(String text) async {
    final id = selectedDevice?.id;
    if (id == null) return;
    await _adb.sendText(id, text);
  }

  // ─────────────────────────────────────────────────────────
  // Device History
  // ─────────────────────────────────────────────────────────

  Future<List<String>> getDeviceHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('device_history') ?? [];
  }

  Future<void> _saveDeviceHistory(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList('device_history') ?? [];
    history.remove(deviceId);
    history.insert(0, deviceId);
    if (history.length > 10) history.removeLast();
    await prefs.setStringList('device_history', history);
  }

  // ─────────────────────────────────────────────────────────
  // Status helpers
  // ─────────────────────────────────────────────────────────

  void setStatus(String msg) {
    statusMessage = msg;
    errorMessage = null;
    notifyListeners();
  }

  void setError(String msg) {
    errorMessage = msg;
    statusMessage = null;
    notifyListeners();
  }

  void clearMessages() {
    statusMessage = null;
    errorMessage = null;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────
  // Dispose
  // ─────────────────────────────────────────────────────────

  @override
  void dispose() {
    _devicePollTimer?.cancel();
    _screenshotTimer?.cancel();
    super.dispose();
  }
}
