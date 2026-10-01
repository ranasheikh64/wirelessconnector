import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

/// ADB Service — wraps all adb command executions.
///
/// Path resolution is fully dynamic — no hardcoded usernames or machine-
/// specific values. Works for any user on macOS, Linux, or Windows.
class AdbService {
  static const _adbTimeout = Duration(seconds: 10);

  /// Cached resolved adb path (looked up once, reused after that)
  String? _adbPath;

  /// Cached resolved scrcpy path
  String? _scrcpyPath;

  // ─────────────────────────────────────────────
  // Path Resolution
  // ─────────────────────────────────────────────

  /// Builds candidate adb paths dynamically from the current OS environment.
  List<String> get _candidatePaths {
    final home = Platform.environment['HOME'] ?? '';
    final userProfile = Platform.environment['USERPROFILE'] ?? '';
    final s = Platform.isWindows ? r'\' : '/';
    return [
      '$home${s}Library${s}Android${s}sdk${s}platform-tools${s}adb',
      '/opt/homebrew/bin/adb',
      '/usr/local/bin/adb',
      '/usr/bin/adb',
      '$userProfile${s}AppData${s}Local${s}Android${s}Sdk${s}platform-tools${s}adb.exe',
      r'C:\Android\platform-tools\adb.exe',
    ];
  }

  List<String> get _scrcpyCandidates => [
    '/opt/homebrew/bin/scrcpy',
    '/usr/local/bin/scrcpy',
    '/usr/bin/scrcpy',
  ];

  Future<String> _resolveAdb() async {
    if (_adbPath != null) return _adbPath!;

    // ① Login shell
    try {
      final shell = Platform.isWindows ? 'cmd' : '/bin/bash';
      final args = Platform.isWindows ? ['/c', 'where adb'] : ['-l', '-c', 'which adb'];
      final result = await Process.run(shell, args).timeout(const Duration(seconds: 5));
      if (result.exitCode == 0) {
        final found = (result.stdout as String).trim().split('\n').first.trim();
        if (found.isNotEmpty && await File(found).exists()) {
          _adbPath = found;
          return _adbPath!;
        }
      }
    } catch (_) {}

    // ② ANDROID_HOME env var
    final sdkRoot = Platform.environment['ANDROID_HOME'] ?? Platform.environment['ANDROID_SDK_ROOT'];
    if (sdkRoot != null && sdkRoot.isNotEmpty) {
      final s = Platform.isWindows ? r'\' : '/';
      final ext = Platform.isWindows ? '.exe' : '';
      final candidate = '$sdkRoot${s}platform-tools${s}adb$ext';
      if (await File(candidate).exists()) {
        _adbPath = candidate;
        return _adbPath!;
      }
    }

    // ③ Common paths
    for (final path in _candidatePaths) {
      if (path.isEmpty) continue;
      if (await File(path).exists()) {
        _adbPath = path;
        return _adbPath!;
      }
    }

    return 'adb';
  }

  /// Resolves scrcpy executable path
  Future<String?> resolveScrcpy() async {
    if (_scrcpyPath != null) return _scrcpyPath;

    try {
      final shell = Platform.isWindows ? 'cmd' : '/bin/bash';
      final args = Platform.isWindows ? ['/c', 'where scrcpy'] : ['-l', '-c', 'which scrcpy'];
      final result = await Process.run(shell, args).timeout(const Duration(seconds: 5));
      if (result.exitCode == 0) {
        final found = (result.stdout as String).trim().split('\n').first.trim();
        if (found.isNotEmpty && await File(found).exists()) {
          _scrcpyPath = found;
          return _scrcpyPath;
        }
      }
    } catch (_) {}

    for (final path in _scrcpyCandidates) {
      if (await File(path).exists()) {
        _scrcpyPath = path;
        return _scrcpyPath;
      }
    }
    return null;
  }

  /// Runs adb with the auto-resolved executable path.
  Future<ProcessResult> _run(List<String> args, {bool binaryOutput = false}) async {
    final exe = await _resolveAdb();
    return Process.run(
      exe,
      args,
      stdoutEncoding: binaryOutput ? null : systemEncoding,
    ).timeout(_adbTimeout);
  }

  // ─────────────────────────────────────────────
  // ADB Health
  // ─────────────────────────────────────────────

  Future<bool> isAdbInstalled() async {
    try {
      final result = await _run(['version']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<void> startServer() async {
    await _run(['start-server']);
  }

  // ─────────────────────────────────────────────
  // Scrcpy — Best method for live screen
  // ─────────────────────────────────────────────

  /// Launches scrcpy for true real-time live screen mirroring.
  Future<bool> launchScrcpy(String deviceId) async {
    final scrcpy = await resolveScrcpy();
    if (scrcpy == null) return false;

    try {
      // Run scrcpy normally (NOT detached) so it gets a proper window.
      // CRITICAL: macOS GUI apps don't have ADB in PATH, so scrcpy will crash
      // unless we explicitly tell it where ADB is via the ADB environment var.
      final exe = await _resolveAdb();
      final process = await Process.start(
        scrcpy, 
        [
          '-s', deviceId,
          '--stay-awake',
          '--no-audio',
          '--video-bit-rate=1M',   // 1M for absolute speed (from Mac tip)
          '--max-size=960',        // 960px max size for Mac
          '--max-fps=60',          // 60fps
          '--video-codec=h265',    // H.265 (Uses Metal GPU natively)
          '--video-buffer=0',      // Zero video buffering
          '--audio-buffer=0',      // Zero audio buffering
          '--window-title=Wireless Connect Mirror', // Custom window title
        ],
        environment: {
          'ADB': exe,
        },
      );

      // Log stderr for debugging, but don't block
      process.stderr.transform(const SystemEncoding().decoder).listen(
        (data) => debugPrint('scrcpy: $data'),
      );

      // Don't await - let it run in background
      process.exitCode.then(
        (code) => debugPrint('scrcpy exited: $code'),
      );

      return true;
    } catch (e) {
      debugPrint('Failed to launch scrcpy: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────
  // Device Management
  // ─────────────────────────────────────────────

  Future<List<String>> listDeviceIds() async {
    try {
      final result = await _run(['devices']);
      final lines = (result.stdout as String).split('\n');
      final ids = <String>[];
      for (final line in lines.skip(1)) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('*')) continue;
        final parts = trimmed.split(RegExp(r'\s+'));
        if (parts.length >= 2 && parts[1] == 'device') ids.add(parts[0]);
      }
      return ids;
    } catch (_) {
      return [];
    }
  }

  Future<PairResult> pairDevice(String ip, String port, String code) async {
    try {
      final exe = await _resolveAdb();
      final result = await Process.run(exe, ['pair', '$ip:$port', code])
          .timeout(const Duration(seconds: 20));
      final stdout = result.stdout as String;
      final stderr = result.stderr as String;
      if (stdout.contains('Successfully paired') || stdout.contains('paired to')) {
        return PairResult.success;
      } else if (stdout.contains('Failed') || stderr.isNotEmpty) {
        return PairResult.failed;
      }
      return PairResult.failed;
    } catch (_) {
      return PairResult.timeout;
    }
  }

  Future<ConnectResult> connectDevice(String ip, String port) async {
    try {
      final exe = await _resolveAdb();
      final result = await Process.run(exe, ['connect', '$ip:$port'])
          .timeout(const Duration(seconds: 15));
      final stdout = result.stdout as String;
      if (stdout.contains('connected to') || stdout.contains('already connected')) {
        return ConnectResult.success;
      } else if (stdout.contains('failed') || stdout.contains('refused')) {
        return ConnectResult.refused;
      }
      return ConnectResult.failed;
    } catch (_) {
      return ConnectResult.timeout;
    }
  }

  Future<void> disconnectDevice(String deviceId) async {
    await _run(['disconnect', deviceId]);
  }

  // ─────────────────────────────────────────────
  // Device Info
  // ─────────────────────────────────────────────

  Future<String> _shellProp(String deviceId, String prop) async {
    try {
      final result = await _run(['-s', deviceId, 'shell', 'getprop', prop]);
      return (result.stdout as String).trim();
    } catch (_) {
      return '';
    }
  }

  Future<String> getModel(String deviceId) => _shellProp(deviceId, 'ro.product.model');
  Future<String> getAndroidVersion(String deviceId) => _shellProp(deviceId, 'ro.build.version.release');

  Future<int> getBatteryLevel(String deviceId) async {
    try {
      final result = await _run(['-s', deviceId, 'shell', 'dumpsys', 'battery']);
      final output = result.stdout as String;
      final match = RegExp(r'level:\s*(\d+)').firstMatch(output);
      if (match != null) return int.tryParse(match.group(1)!) ?? 0;
    } catch (_) {}
    return 0;
  }

  Future<(int width, int height)> getScreenResolution(String deviceId) async {
    try {
      final result = await _run(['-s', deviceId, 'shell', 'wm', 'size']);
      final output = result.stdout as String;
      final match = RegExp(r'(\d+)x(\d+)').firstMatch(output);
      if (match != null) {
        return (int.parse(match.group(1)!), int.parse(match.group(2)!));
      }
    } catch (_) {}
    return (1080, 2400);
  }

  // ─────────────────────────────────────────────
  // Screenshot — Streaming method (WiFi-safe)
  // ─────────────────────────────────────────────


  Future<Uint8List?> captureScreenshot(String deviceId) async {
    Process? process;
    try {
      final exe = await _resolveAdb();
      process = await Process.start(exe, [
        '-s', deviceId, 'exec-out', 'screencap', '-p',
      ]);

      final buffer = <int>[];
      final completer = Completer<void>();

      process.stdout.listen(
        buffer.addAll,
        onDone: completer.complete,
        onError: completer.completeError,
        cancelOnError: true,
      );

      // Increase timeout to 8 seconds. WiFi can be slow.
      await completer.future.timeout(const Duration(seconds: 8));

      final bytes = Uint8List.fromList(buffer);
      // Validate PNG header
      if (bytes.length > 4 &&
          bytes[0] == 0x89 && bytes[1] == 0x50 &&
          bytes[2] == 0x4E && bytes[3] == 0x47) {
        return bytes;
      }
      return null;
    } catch (e) {
      process?.kill();
      return null;
    }
  }


  // ─────────────────────────────────────────────
  // Input: Touch / Swipe / Keys / Text
  // ─────────────────────────────────────────────

  Future<void> sendTap(String deviceId, int x, int y) async {
    try {
      await _run(['-s', deviceId, 'shell', 'input', 'tap', '$x', '$y']);
    } catch (_) {}
  }

  Future<void> sendSwipe(String deviceId, int x1, int y1, int x2, int y2,
      {int durationMs = 300}) async {
    try {
      await _run([
        '-s', deviceId, 'shell', 'input', 'swipe',
        '$x1', '$y1', '$x2', '$y2', '$durationMs',
      ]);
    } catch (_) {}
  }

  Future<void> sendKey(String deviceId, int keyCode) async {
    try {
      await _run(['-s', deviceId, 'shell', 'input', 'keyevent', '$keyCode']);
    } catch (_) {}
  }

  Future<void> sendText(String deviceId, String text) async {
    try {
      final escaped = _escapeAdbText(text);
      await _run(['-s', deviceId, 'shell', 'input', 'text', escaped]);
    } catch (_) {}
  }

  String _escapeAdbText(String text) {
    return text
        .replaceAll('\\', '\\\\')
        .replaceAll(' ', '%s')
        .replaceAll('"', '\\"')
        .replaceAll("'", "\\'")
        .replaceAll('(', '\\(')
        .replaceAll(')', '\\)')
        .replaceAll('&', '\\&')
        .replaceAll('|', '\\|')
        .replaceAll('<', '\\<')
        .replaceAll('>', '\\>')
        .replaceAll(';', '\\;')
        .replaceAll('`', '\\`');
  }
}

enum PairResult { success, failed, timeout }
enum ConnectResult { success, refused, failed, timeout }

class AdbKeyCodes {
  static const int home = 3;
  static const int back = 4;
  static const int volumeUp = 24;
  static const int volumeDown = 25;
  static const int power = 26;
  static const int recents = 187;
  static const int enter = 66;
  static const int delete = 67;
  static const int screenshot = 120;
  static const int brightnessUp = 221;
  static const int brightnessDown = 220;
}
