import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/adb_service.dart';
import '../../core/app_theme.dart';
import '../../core/device_provider.dart';

/// Shows the phone preview (screenshot) inside a phone frame.
/// Click/drag on the preview → sends touch events to device.
class PhoneFrameWidget extends StatefulWidget {
  const PhoneFrameWidget({super.key});

  @override
  State<PhoneFrameWidget> createState() => _PhoneFrameWidgetState();
}

class _PhoneFrameWidgetState extends State<PhoneFrameWidget> {
  // Track drag for swipe detection

  // Phone native resolution (fetched once on device select)
  // ignore: unused_field
  int _phoneW = 1080;
  // ignore: unused_field
  int _phoneH = 2400;
  bool _resolutionFetched = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<DeviceProvider>();
    final device = provider.selectedDevice;
    if (device != null && !_resolutionFetched) {
      _resolutionFetched = true;
      provider.adbService.getScreenResolution(device.id).then((res) {
        if (mounted) {
          setState(() {
            _phoneW = res.$1;
            _phoneH = res.$2;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DeviceProvider>(
      builder: (context, provider, _) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Phone outer frame
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2C),
                borderRadius: BorderRadius.circular(40),
                border: Border.all(color: AppColors.phoneBorder, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 40,
                    spreadRadius: 5,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(10),
              child: Container(
                width: 280,
                height: 580,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(30),
                ),
                clipBehavior: Clip.hardEdge,
                child: _buildScreenContent(provider),
              ),
            ),
            const SizedBox(height: 20),
            // Hardware buttons row
            _buildHardwareButtons(provider),
          ],
        );
      },
    );
  }

  Widget _buildScreenContent(DeviceProvider provider) {
    final device = provider.selectedDevice;

    if (device == null) {
      return _placeholder(
        icon: Icons.phone_android_rounded,
        label: 'Select a device',
        sublabel: 'Choose a connected device from the sidebar',
      );
    }

    if (!device.isConnected) {
      return _placeholder(
        icon: Icons.phonelink_off_rounded,
        label: 'Device disconnected',
        sublabel: device.displayName,
        color: AppColors.error,
        action: ElevatedButton.icon(
          onPressed: () => provider.reconnectDevice(device),
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Reconnect'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.surfaceAlt,
            foregroundColor: AppColors.textPrimary,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: AppColors.border),
            ),
          ),
        ),
      );
    }

    // Since the actual high-speed screen is shown via Scrcpy,
    // we don't need to show laggy screenshots here.
    return _placeholder(
      icon: Icons.connected_tv_rounded,
      label: 'Device Connected',
      sublabel: 'Click below to launch the ultra-fast live screen',
      action: ElevatedButton.icon(
        onPressed: provider.launchLiveScreen,
        icon: const Icon(Icons.play_arrow_rounded, size: 18),
        label: const Text('Open Live Screen'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }




  Widget _buildHardwareButtons(DeviceProvider provider) {
    final enabled = provider.selectedDevice?.isConnected == true;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _HwButton(
          icon: Icons.arrow_back_ios_new_rounded,
          label: 'Back',
          enabled: enabled,
          onTap: () => provider.sendKey(AdbKeyCodes.back),
        ),
        const SizedBox(width: 8),
        _HwButton(
          icon: Icons.circle_outlined,
          label: 'Home',
          enabled: enabled,
          large: true,
          onTap: () => provider.sendKey(AdbKeyCodes.home),
        ),
        const SizedBox(width: 8),
        _HwButton(
          icon: Icons.grid_view_rounded,
          label: 'Recents',
          enabled: enabled,
          onTap: () => provider.sendKey(AdbKeyCodes.recents),
        ),
      ],
    );
  }

  Widget _placeholder({
    required IconData icon,
    required String label,
    String? sublabel,
    Color? color,
    Widget? action,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color ?? AppColors.textTertiary, size: 48),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              color: color ?? AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          if (sublabel != null) ...[
            const SizedBox(height: 4),
            Text(
              sublabel,
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: 12),
            action,
          ],
        ],
      ),
    );
  }
}

class _HwButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final bool large;
  final VoidCallback onTap;

  const _HwButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
    this.large = false,
  });

  @override
  State<_HwButton> createState() => _HwButtonState();
}

class _HwButtonState extends State<_HwButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.label,
      child: MouseRegion(
        cursor: widget.enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.forbidden,
        child: GestureDetector(
          onTapDown: (_) {
            if (widget.enabled) setState(() => _pressed = true);
          },
          onTapUp: (_) {
            setState(() => _pressed = false);
            if (widget.enabled) widget.onTap();
          },
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: widget.large ? 52 : 44,
            height: widget.large ? 52 : 44,
            decoration: BoxDecoration(
              color: _pressed
                  ? AppColors.accent.withOpacity(0.2)
                  : AppColors.surfaceAlt,
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.enabled ? AppColors.border : AppColors.textTertiary,
              ),
            ),
            child: Icon(
              widget.icon,
              color: widget.enabled ? AppColors.textPrimary : AppColors.textTertiary,
              size: widget.large ? 22 : 18,
            ),
          ),
        ),
      ),
    );
  }
}
