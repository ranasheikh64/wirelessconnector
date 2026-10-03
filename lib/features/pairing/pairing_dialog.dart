import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/app_theme.dart';
import '../../core/adb_service.dart';
import '../../core/device_provider.dart';

/// Dialog for pairing a new Android device via Wireless Debugging
class PairingDialog extends StatefulWidget {
  const PairingDialog({super.key});

  @override
  State<PairingDialog> createState() => _PairingDialogState();
}

class _PairingDialogState extends State<PairingDialog> {
  int _step = 0; // 0=guide, 1=pairing inputs, 2=connecting, 3=done

  final _ipController = TextEditingController();
  final _pairPortController = TextEditingController();
  final _pairCodeController = TextEditingController();
  final _connectPortController = TextEditingController(text: '5555');

  String? _pairError;
  bool _isPairing = false;

  // mDNS Discovery
  List<MdnsDevice> _discoveredDevices = [];
  Timer? _mdnsTimer;
  bool _isScanning = false;

  // QR Pairing
  String? _qrServiceName;
  String? _qrPassword;
  Timer? _qrTimer;

  @override
  void dispose() {
    _mdnsTimer?.cancel();
    _qrTimer?.cancel();
    _ipController.dispose();
    _pairPortController.dispose();
    _pairCodeController.dispose();
    _connectPortController.dispose();
    super.dispose();
  }

  void _startMdnsScan() {
    _mdnsTimer?.cancel();
    _scanMdns();
    _mdnsTimer = Timer.periodic(const Duration(seconds: 3), (_) => _scanMdns());
  }

  void _startQrScan() {
    _generateQrData();
    _qrTimer?.cancel();
    _qrTimer = Timer.periodic(const Duration(seconds: 2), (_) => _checkQrMdns());
  }

  void _generateQrData() {
    final rand = Random();
    _qrServiceName = 'adb-cli-${rand.nextInt(900000) + 100000}';
    _qrPassword = '${rand.nextInt(900000) + 100000}';
  }

  Future<void> _checkQrMdns() async {
    if (!mounted || _isPairing) return;
    final provider = context.read<DeviceProvider>();
    final devices = await provider.adbService.discoverMdnsDevices();
    for (var d in devices) {
      if (d.name == _qrServiceName) {
        _qrTimer?.cancel();
        // Found it! Initiate pairing automatically
        setState(() {
          _ipController.text = d.ip;
          _pairPortController.text = d.port;
          _pairCodeController.text = _qrPassword!;
        });
        _doPair();
        break;
      }
    }
  }

  Future<void> _scanMdns() async {
    if (!mounted || _isScanning) return;
    _isScanning = true;
    final provider = context.read<DeviceProvider>();
    final devices = await provider.adbService.discoverMdnsDevices();
    if (mounted) {
      setState(() {
        _discoveredDevices = devices;
      });
    }
    _isScanning = false;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            const Divider(height: 1),
            _buildBody(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.wifi_tethering_rounded,
                color: AppColors.accent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add Device',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  'Wireless Debugging pairing',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded,
                color: AppColors.textSecondary, size: 18),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(maxWidth: 30, maxHeight: 30),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: switch (_step) {
        0 => _buildGuideStep(),
        1 => _buildPairingStep(),
        2 => _buildConnectingStep(),
        3 => _buildSuccessStep(),
        4 => _buildQrStep(),
        _ => const SizedBox.shrink(),
      },
    );
  }

  // ─── Step 0: Guide ─────────────────────────────────────────────────────
  Widget _buildGuideStep() {
    return Padding(
      key: const ValueKey(0),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepItem(
            number: 1,
            title: 'Enable Developer Options',
            subtitle:
                'Settings → About Phone → tap "Build number" 7 times',
          ),
          _StepItem(
            number: 2,
            title: 'Enable Wireless Debugging',
            subtitle: 'Settings → Developer Options → Wireless Debugging → ON',
          ),
          _StepItem(
            number: 3,
            title: 'Open Pair with pairing code',
            subtitle:
                'Inside Wireless Debugging → "Pair device with pairing code"',
          ),
          _StepItem(
            number: 4,
            title: 'Note the IP, Port, and Code',
            subtitle:
                'You will see IP address, port, and a 6-digit code',
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() => _step = 4);
                  _startQrScan();
                },
                icon: const Icon(Icons.qr_code, size: 16),
                label: const Text('QR Code'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.surfaceAlt,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  setState(() => _step = 1);
                  _startMdnsScan();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Pair Manually →'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Step 1: Pairing inputs ────────────────────────────────────────────
  Widget _buildPairingStep() {
    return Padding(
      key: const ValueKey(1),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Note
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.accent.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    color: AppColors.accent, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'From "Pair device with pairing code" screen on your phone:',
                    style:
                        TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Auto Discovery
          if (_discoveredDevices.isNotEmpty) ...[
            const Text(
              'Discovered Devices on Wi-Fi',
              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _discoveredDevices.length,
                itemBuilder: (context, index) {
                  final d = _discoveredDevices[index];
                  final isPairing = d.type.contains('pairing');
                  final icon = isPairing ? Icons.phonelink_setup : Icons.smartphone;
                  
                  // Hide ugly ADB mDNS hash names
                  String displayName = d.name;
                  if (displayName.startsWith('adb-')) {
                    displayName = isPairing ? 'Ready to Pair (${d.ip})' : 'Paired Device (${d.ip})';
                  }

                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ActionChip(
                      avatar: Icon(icon, size: 16, color: Colors.blueAccent),
                      label: Text(displayName, style: const TextStyle(fontSize: 12)),
                      backgroundColor: Colors.blueAccent.withOpacity(0.1),
                      side: BorderSide(color: Colors.blueAccent.withOpacity(0.4)),
                      onPressed: () {
                        setState(() {
                          _ipController.text = d.ip;
                          if (isPairing) {
                            _pairPortController.text = d.port;
                          } else {
                            _connectPortController.text = d.port;
                          }
                        });
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],

          Row(
            children: [
              Expanded(
                flex: 3,
                child: _buildField('IP Address', _ipController,
                    hint: '192.168.1.x'),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: _buildField('Pair Port', _pairPortController,
                    hint: '37xxx', keyboardType: TextInputType.number),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildField(
            'Pairing Code (6 digits)',
            _pairCodeController,
            hint: '123456',
            keyboardType: TextInputType.number,
            maxLength: 6,
          ),
          const SizedBox(height: 10),
          _buildField(
            'Debug Port (after pairing)',
            _connectPortController,
            hint: '5555',
            keyboardType: TextInputType.number,
            sublabel:
                'Found in Wireless Debugging main screen (e.g. port 5555)',
          ),

          if (_pairError != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: AppColors.error.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: AppColors.error, size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_pairError!,
                        style: const TextStyle(
                            color: AppColors.error, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => setState(() => _step = 0),
                child: const Text('← Back',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isPairing ? null : _doPair,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: _isPairing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Pair & Connect'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Step 4: QR Code ───────────────────────────────────────────────────
  Widget _buildQrStep() {
    if (_qrServiceName == null || _qrPassword == null) {
      return const SizedBox.shrink();
    }
    
    final payload = 'WIFI:T:ADB;S:$_qrServiceName;P:$_qrPassword;;';

    return Padding(
      key: const ValueKey(4),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Text(
            'Scan to Connect',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          const Text(
            'Open "Pair device with QR code" on your phone and scan this code.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: QrImageView(
              data: payload,
              version: QrVersions.auto,
              size: 200.0,
            ),
          ),
          
          const SizedBox(height: 24),
          
          if (_isPairing) ...[
            const CircularProgressIndicator(color: AppColors.accent),
            const SizedBox(height: 10),
            const Text('Pairing automatically...', style: TextStyle(color: AppColors.textSecondary)),
          ] else ...[
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                ),
                SizedBox(width: 10),
                Text('Waiting for scan...', style: TextStyle(color: AppColors.accent)),
              ],
            ),
          ],
          
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () {
                  _qrTimer?.cancel();
                  setState(() => _step = 0);
                },
                child: const Text('← Back', style: TextStyle(color: AppColors.textSecondary)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Step 2: Connecting ────────────────────────────────────────────────
  Widget _buildConnectingStep() {
    return Padding(
      key: const ValueKey(2),
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          const CircularProgressIndicator(color: AppColors.accent),
          const SizedBox(height: 20),
          Text(
            'Connecting to device...',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 6),
          Text(
            '${_ipController.text}:${_connectPortController.text}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  // ─── Step 3: Success ───────────────────────────────────────────────────
  Widget _buildSuccessStep() {
    return Padding(
      key: const ValueKey(3),
      padding: const EdgeInsets.all(30),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.connected.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded,
                color: AppColors.connected, size: 40),
          ).animate().scale(
              begin: const Offset(0.5, 0.5),
              end: const Offset(1, 1),
              duration: 400.ms,
              curve: Curves.elasticOut),
          const SizedBox(height: 16),
          Text(
            'Connected!',
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(color: AppColors.connected),
          ),
          const SizedBox(height: 6),
          Text(
            '${_ipController.text}:${_connectPortController.text}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.connected,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────
  Widget _buildField(
    String label,
    TextEditingController controller, {
    String? hint,
    TextInputType? keyboardType,
    int? maxLength,
    String? sublabel,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 5),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border.withOpacity(0.5)),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            maxLength: maxLength,
            style: const TextStyle(
                color: AppColors.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                  color: AppColors.textTertiary, fontSize: 12),
              border: InputBorder.none,
              counterText: '',
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ),
        if (sublabel != null) ...[
          const SizedBox(height: 3),
          Text(
            sublabel,
            style: const TextStyle(
                color: AppColors.textTertiary, fontSize: 10),
          ),
        ],
      ],
    );
  }

  Future<void> _doPair() async {
    final ip = _ipController.text.trim();
    final pairPort = _pairPortController.text.trim();
    final code = _pairCodeController.text.trim();
    final connectPort = _connectPortController.text.trim();

    // 1. Empty checks
    if (ip.isEmpty || pairPort.isEmpty || code.isEmpty) {
      setState(() => _pairError = 'IP, Pair Port, and Code are required.');
      return;
    }

    // 2. IP Validation
    final ipRegex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
    if (!ipRegex.hasMatch(ip)) {
      setState(() => _pairError = 'Invalid IP Address format (e.g. 192.168.1.x)');
      return;
    }

    // 3. Port Validations
    final pPort = int.tryParse(pairPort);
    if (pPort == null || pPort <= 0 || pPort > 65535) {
      setState(() => _pairError = 'Pair Port must be a valid number (1-65535)');
      return;
    }

    if (connectPort.isNotEmpty) {
      final cPort = int.tryParse(connectPort);
      if (cPort == null || cPort <= 0 || cPort > 65535) {
        setState(() => _pairError = 'Debug Port must be a valid number (1-65535)');
        return;
      }
    }

    // 4. Code Validation
    if (code.length != 6 || int.tryParse(code) == null) {
      setState(() => _pairError = 'Pairing code must be exactly 6 digits.');
      return;
    }

    setState(() {
      _isPairing = true;
      _pairError = null;
    });

    final provider = context.read<DeviceProvider>();
    
    // Attempt Pairing
    final pairResult = await provider.pairDevice(ip, pairPort, code);

    if (!mounted) return;

    if (pairResult.$1 == PairResult.success) {
      setState(() {
        _isPairing = false;
        _step = 2;
      });

      // Attempt Connection
      // 1. Wait a moment because ADB often auto-connects via mDNS after pairing
      await Future.delayed(const Duration(seconds: 2));
      
      // 2. Check if it's already connected automatically
      final currentDevices = await provider.adbService.listDeviceIds();
      final mdns = await provider.adbService.discoverMdnsDevices();
      
      bool isAutoConnected = false;
      for (final deviceId in currentDevices) {
        // Direct IP match
        if (deviceId.contains(ip)) {
           isAutoConnected = true;
           break;
        }
        // mDNS name match
        for (var d in mdns) {
           if (d.ip == ip && deviceId.contains(d.name)) {
             isAutoConnected = true;
             break;
           }
        }
        if (isAutoConnected) break;
      }

      if (isAutoConnected) {
         if (mounted) setState(() => _step = 3);
         return;
      }
      
      // 3. If not auto-connected, try to find the actual connect port via mDNS
      String? actualConnectPort;
      for (var d in mdns) {
        if (d.ip == ip && d.type.contains('connect')) {
          actualConnectPort = d.port;
          break;
        }
      }

      // 4. Fallback to user input or default 5555
      final cPort = actualConnectPort ?? (connectPort.isNotEmpty && connectPort != '5555' ? connectPort : '5555');
      final connectResult = await provider.connectDevice(ip, cPort);
      
      if (!mounted) return;

      if (connectResult == ConnectResult.success) {
        setState(() => _step = 3);
      } else {
        setState(() {
          _step = 1;
          _pairError =
              'Paired successfully! But connection failed. Could not find device connect port.';
        });
      }
    } else {
      setState(() {
        _isPairing = false;
        _pairError = pairResult.$1 == PairResult.timeout
            ? 'Timeout. Check IP and port, then try again.\nLog: ${pairResult.$2}'
            : 'Pairing failed. Check the 6-digit code.\nLog: ${pairResult.$2}';
      });
    }
  }
}

class _StepItem extends StatelessWidget {
  final int number;
  final String title;
  final String subtitle;

  const _StepItem({
    required this.number,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.accent.withOpacity(0.4)),
            ),
            child: Center(
              child: Text(
                '$number',
                style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
