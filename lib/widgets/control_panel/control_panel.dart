
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/device_provider.dart';

/// Right-side info & control panel
class ControlPanel extends StatefulWidget {
  const ControlPanel({super.key});

  @override
  State<ControlPanel> createState() => _ControlPanelState();
}

class _ControlPanelState extends State<ControlPanel> {
  final _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DeviceProvider>(
      builder: (context, provider, _) {
        final device = provider.selectedDevice;

        return Container(
          width: 240,
          color: AppColors.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPanelHeader(context),
              const Divider(height: 1),
              Expanded(
                child: device == null
                    ? _buildEmptyState(context)
                    : _buildDeviceDetail(context, provider),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Header ──────────────────────────────────────
  Widget _buildPanelHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Text(
        'Device Info',
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.info_outline_rounded,
              color: AppColors.textTertiary, size: 40),
          const SizedBox(height: 10),
          Text(
            'No device selected',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  // ─── Device detail ───────────────────────────────
  Widget _buildDeviceDetail(BuildContext context, DeviceProvider provider) {
    final device = provider.selectedDevice!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Device card
          _InfoCard(
            children: [
              _InfoRow(
                  icon: Icons.phone_android_rounded,
                  label: 'Model',
                  value: device.displayName),
              _InfoRow(
                  icon: Icons.android_rounded,
                  label: 'Android',
                  value: device.androidVersion.isEmpty
                      ? '—'
                      : device.androidVersion),
              _InfoRow(
                  icon: Icons.battery_5_bar_rounded,
                  label: 'Battery',
                  value: '${device.batteryLevel}%',
                  valueColor: device.batteryLevel < 20
                      ? AppColors.error
                      : AppColors.connected),
              _InfoRow(
                  icon: Icons.wifi_rounded,
                  label: 'IP',
                  value: device.shortId),
              _InfoRow(
                  icon: Icons.circle_rounded,
                  label: 'Status',
                  value: device.isConnected ? 'Connected' : 'Disconnected',
                  valueColor: device.isConnected
                      ? AppColors.connected
                      : AppColors.error),
            ],
          ).animate().fadeIn(duration: 300.ms),

          const SizedBox(height: 14),

          // ── Live Screen (Scrcpy) ─────────────────────────
          _sectionLabel(context, 'Live Screen'),
          const SizedBox(height: 8),
          _InfoCard(
            children: [
              Row(
                children: [
                  Icon(
                    Icons.cast_rounded,
                    color: provider.isScrcpyAvailable
                        ? AppColors.accent
                        : AppColors.textTertiary,
                    size: 15,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Scrcpy Mirror',
                          style: TextStyle(
                              color: AppColors.textPrimary, fontSize: 13),
                        ),
                        Text(
                          provider.isScrcpyAvailable
                              ? 'Real-time · 0 latency'
                              : 'Not installed',
                          style: TextStyle(
                            color: provider.isScrcpyAvailable
                                ? AppColors.connected
                                : AppColors.textTertiary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              provider.isScrcpyAvailable
                  ? _ActionButton(
                      icon: Icons.play_circle_fill_rounded,
                      label: 'Open Live Screen',
                      color: const Color(0xFF30D158),
                      loading: provider.isScrcpyRunning,
                      onTap: () async {
                        final ok = await provider.launchLiveScreen();
                        if (!ok && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Could not launch scrcpy'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                    )
                  : Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.bg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.terminal_rounded,
                                  size: 13,
                                  color: AppColors.textTertiary),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'brew install scrcpy',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                    color: AppColors.accent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Install scrcpy for 60fps live preview',
                          style: const TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
            ],
          ),


          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 8),

          // Disconnect
          _ActionButton(
            icon: Icons.link_off_rounded,
            label: 'Disconnect',
            color: AppColors.error,
            onTap: () => provider.disconnectDevice(device),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }





  Widget _sectionLabel(BuildContext context, String label) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: AppColors.textTertiary,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }
}

// ─── Reusable sub-widgets ──────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final List<Widget> children;

  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textTertiary, size: 13),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 12),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool enabled;
  final bool loading;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    // ignore: unused_element_parameter
    this.enabled = true,
    this.loading = false,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled && !widget.loading;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: active ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: active ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _hovered && active
                ? widget.color.withOpacity(0.15)
                : AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active
                  ? widget.color.withOpacity(0.4)
                  : AppColors.border.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              if (widget.loading)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: widget.color,
                  ),
                )
              else
                Icon(widget.icon,
                    color: active ? widget.color : AppColors.textTertiary,
                    size: 15),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  color: active ? AppColors.textPrimary : AppColors.textTertiary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  const _SmallButton({
    required this.icon,
    required this.label,
    required this.onTap,
    // ignore: unused_element_parameter
    this.enabled = true,
  });

  @override
  State<_SmallButton> createState() => _SmallButtonState();
}

class _SmallButtonState extends State<_SmallButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: _pressed ? AppColors.accent.withOpacity(0.2) : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.icon,
              color: widget.enabled ? AppColors.textPrimary : AppColors.textTertiary,
              size: 14,
            ),
            const SizedBox(width: 5),
            Text(
              widget.label,
              style: TextStyle(
                color:
                    widget.enabled ? AppColors.textPrimary : AppColors.textTertiary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
