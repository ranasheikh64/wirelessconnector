import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

import 'logger.dart';

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
          AppLogger.log('[ADB] Found via shell: $_adbPath');
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
        AppLogger.log('[ADB] Found via ANDROID_HOME: $_adbPath');
        return _adbPath!;
      }
    }

    // ③ Common paths
    for (final path in _candidatePaths) {
      if (path.isEmpty) continue;
      if (await File(path).exists()) {
        _adbPath = path;
        AppLogger.log('[ADB] Found via fallback: $_adbPath');
        return _adbPath!;
      }
    }

    AppLogger.log('[ADB] Could not find absolute path, falling back to "adb"');
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
    
    // Hide 'devices' spam from terminal log
    if (args.first != 'devices') {
      AppLogger.log('\$ $exe ${args.join(' ')}');
    }

    final env = Map<String, String>.from(Platform.environment);
    env['ADB_MDNS_OPENSCREEN'] = '1';
    
    final result = await Process.run(
      exe,
      args,
      environment: env,
      stdoutEncoding: binaryOutput ? null : systemEncoding,
    ).timeout(_adbTimeout);
    
    if (result.exitCode != 0 && !binaryOutput) {
      AppLogger.log('[ERROR ${result.exitCode}] ${result.stderr}');
    }
    return result;
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
    if (scrcpy == null) {
      AppLogger.log('[Scrcpy] Executable not found!');
      return false;
    }

    AppLogger.log('[Scrcpy] Launching live screen for $deviceId using $scrcpy');
    try {
      // Run scrcpy normally (NOT detached) so it gets a proper window.
      // CRITICAL: macOS GUI apps don't have ADB in PATH, so scrcpy will crash
      // unless we explicitly tell it where ADB is via the ADB environment var.
      final exe = await _resolveAdb();
      
      final env = Map<String, String>.from(Platform.environment);
      env['ADB'] = exe;
      env['ADB_MDNS_OPENSCREEN'] = '1';

      final process = await Process.start(
        scrcpy, 
        [
          '-s', deviceId,
          '--stay-awake',
          '--no-audio',
          '--video-bit-rate=2M',   // 2M is better for H.264
          '--max-size=960',        // 960px max size for Mac
          '--max-fps=60',          // 60fps
          '--video-buffer=0',      // Zero video buffering
          '--audio-buffer=0',      // Zero audio buffering
          '--window-title=Wireless Connect Mirror', // Custom window title
        ],
        environment: env,
      );

      // Log stderr for debugging, but don't block
      process.stderr.transform(const SystemEncoding().decoder).listen(
        (data) {
          final msg = data.trim();
          if (msg.isNotEmpty) AppLogger.log('[Scrcpy] $msg');
        }
      );

      // Don't await - let it run in background
      process.exitCode.then(
        (code) => AppLogger.log('[Scrcpy] Exited with code $code'),
      );

      return true;
    } catch (e) {
      AppLogger.log('[Scrcpy] Failed to launch: $e');
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

  Future<List<MdnsDevice>> discoverMdnsDevices() async {
    try {
      final result = await _run(['mdns', 'services']);
      final lines = (result.stdout as String).split('\n');
      final devices = <MdnsDevice>[];
      
      for (var line in lines) {
        line = line.trim();
        if (line.isEmpty || line.startsWith('List of')) continue;
        
        final parts = line.split(RegExp(r'\s+'));
        if (parts.length >= 3) {
          String ipPort = parts.last;
          String type = parts[parts.length - 2];
          String name = parts.sublist(0, parts.length - 2).join(' ');
          
          if (!ipPort.contains(':')) continue;
          
          final ip = ipPort.split(':')[0];
          final port = ipPort.split(':')[1];
          
          devices.add(MdnsDevice(name: name, type: type, ip: ip, port: port));
        }
      }
      return devices;
    } catch (_) {
      return [];
    }
  }

  Future<(PairResult, String)> pairDevice(String ip, String port, String code) async {
    try {
      final exe = await _resolveAdb();
      final cleanCode = code.trim();
      AppLogger.log('\$ $exe pair $ip:$port <code>');
      
      final env = Map<String, String>.from(Platform.environment);
      env['ADB_MDNS_OPENSCREEN'] = '1';
      
      final result = await Process.run(
        exe, 
        ['pair', '$ip:$port', cleanCode],
        environment: env,
      ).timeout(const Duration(seconds: 20));
      
      final stdout = (result.stdout as String).toLowerCase();
      final stderr = (result.stderr as String).toLowerCase();
      
      AppLogger.log('[ADB] pair stdout: $stdout');
      if (stderr.isNotEmpty) AppLogger.log('[ADB] pair stderr: $stderr');
      if (result.exitCode != 0) AppLogger.log('[ADB] pair exitCode: ${result.exitCode}');
      
      // Success
      if (stdout.contains('successfully paired') || stdout.contains('paired to')) {
        return (PairResult.success, '');
      }
      // Explicit failure keywords in stdout
      if (stdout.contains('failed') || stdout.contains('error') || stdout.contains('refused')) {
        return (PairResult.failed, 'stdout: ${result.stdout.toString().trim()}');
      }
      // Only treat stderr as error if it has actual error keywords
      // (adb often writes version info / warnings to stderr on success)
      if (stderr.contains('error') || stderr.contains('failed') || stderr.contains('refused')) {
        return (PairResult.failed, 'stderr: ${result.stderr.toString().trim()}');
      }
      return (PairResult.failed, 'Unknown error. stdout: $stdout | stderr: $stderr');
    } on TimeoutException {
      AppLogger.log('[ADB] pair timeout!');
      return (PairResult.timeout, 'Timeout connecting to device');
    } catch (e) {
      AppLogger.log('[ADB] pair exception: $e');
      return (PairResult.timeout, 'Exception: $e');
    }
  }

  Future<ConnectResult> connectDevice(String ip, String port) async {
    try {
      final exe = await _resolveAdb();
      
      final env = Map<String, String>.from(Platform.environment);
      env['ADB_MDNS_OPENSCREEN'] = '1';
      
      final result = await Process.run(
        exe, 
        ['connect', '$ip:$port'],
        environment: env,
      ).timeout(const Duration(seconds: 15));
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

  // ─────────────────────────────────────────────
  // File Management (Transfer)
  // ─────────────────────────────────────────────

  Future<List<AdbFile>> listFiles(String deviceId, String path) async {
    try {
      // Use standard ls -lA to list files, format: "-rw-rw---- 1 u0_a163 ext_data_rw 45318 2023-10-10 12:00:00 filename"
      // Wait, let's use `stat` which is much easier to parse: stat -c "%F|%s|%Y|%n"
      // Some old versions of Android don't support `stat -c`, so we fallback to a simpler ls -1A
      
      final result = await _run(['-s', deviceId, 'shell', 'stat', '-c', '"%F|%s|%Y|%n"', '$path/*']);
      if (result.exitCode != 0) {
        // Fallback to ls -lA if stat fails or path is empty
        return await _fallbackListFiles(deviceId, path);
      }

      final lines = (result.stdout as String).split('\n');
      final files = <AdbFile>[];

      for (var line in lines) {
        line = line.trim().replaceAll('"', '');
        if (line.isEmpty || line.contains('No such file') || line.contains('stat:')) continue;

        final parts = line.split('|');
        if (parts.length >= 4) {
          final isDir = parts[0].toLowerCase().contains('directory');
          final size = int.tryParse(parts[1]) ?? 0;
          final time = int.tryParse(parts[2]) ?? 0;
          final fullPath = parts.sublist(3).join('|');
          final name = fullPath.split('/').last;

          if (name == '.' || name == '..') continue;

          files.add(AdbFile(
            name: name,
            path: fullPath,
            isDirectory: isDir,
            size: size,
            modifiedAt: DateTime.fromMillisecondsSinceEpoch(time * 1000),
          ));
        }
      }
      
      // Sort: Directories first, then alphabetical
      files.sort((a, b) {
        if (a.isDirectory && !b.isDirectory) return -1;
        if (!a.isDirectory && b.isDirectory) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      
      return files;
    } catch (_) {
      return [];
    }
  }

  Future<List<AdbFile>> _fallbackListFiles(String deviceId, String path) async {
    try {
      // Using ls -lA
      final result = await _run(['-s', deviceId, 'shell', 'ls', '-lA', path]);
      if (result.exitCode != 0) return [];
      
      final lines = (result.stdout as String).split('\n');
      final files = <AdbFile>[];

      for (var line in lines) {
        line = line.trim();
        if (line.isEmpty || line.startsWith('total ')) continue;
        
        // drwxrwx--- 2 root ext_data_rw 4096 2023-10-10 12:00 my folder
        // lrwxrwxrwx 1 root root 11 1970-01-01 00:00 sdcard -> /storage/emulated/0
        final parts = line.split(RegExp(r'\s+'));
        if (parts.length >= 7) {
          final isDir = parts[0].startsWith('d') || parts[0].startsWith('l');
          
          // Parse name (handle spaces)
          int nameIndex = 5;
          if (parts[5].contains(':')) {
            nameIndex = 6; // old format without year
          }
          if (parts.length > 7 && parts[6].contains(':')) {
            nameIndex = 7;
          }
          
          if (nameIndex >= parts.length) continue;
          
          String name = parts.sublist(nameIndex).join(' ');
          if (name.contains(' -> ')) {
            name = name.split(' -> ').first; // handle symlinks
          }
          
          if (name == '.' || name == '..') continue;

          files.add(AdbFile(
            name: name,
            path: '$path/$name'.replaceAll('//', '/'),
            isDirectory: isDir,
            size: int.tryParse(parts[4]) ?? 0,
            modifiedAt: DateTime.now(), // Fallback parsing date is tricky
          ));
        }
      }
      
      files.sort((a, b) {
        if (a.isDirectory && !b.isDirectory) return -1;
        if (!a.isDirectory && b.isDirectory) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      
      return files;
    } catch (_) {
      return [];
    }
  }

  Future<bool> pullFile(String deviceId, String remotePath, String localPath) async {
    try {
      AppLogger.log('[ADB] Pulling file: $remotePath -> $localPath');
      final result = await _run(['-s', deviceId, 'pull', remotePath, localPath]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<bool> pushFile(String deviceId, String localPath, String remotePath) async {
    try {
      AppLogger.log('[ADB] Pushing file: $localPath -> $remotePath');
      final result = await _run(['-s', deviceId, 'push', localPath, remotePath]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteFile(String deviceId, String remotePath) async {
    try {
      AppLogger.log('[ADB] Deleting file: $remotePath');
      final result = await _run(['-s', deviceId, 'shell', 'rm', '-rf', remotePath]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}

class AdbFile {
  final String name;
  final String path;
  final bool isDirectory;
  final int size;
  final DateTime modifiedAt;

  AdbFile({
    required this.name,
    required this.path,
    required this.isDirectory,
    required this.size,
    required this.modifiedAt,
  });
}

class MdnsDevice {
  final String name;
  final String type;
  final String ip;
  final String port;

  MdnsDevice({
    required this.name,
    required this.type,
    required this.ip,
    required this.port,
  });
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
