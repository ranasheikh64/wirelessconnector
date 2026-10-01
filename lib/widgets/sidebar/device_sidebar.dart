import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:wirelessconnect/features/pairing/pairing_dialog.dart';

import '../../core/app_theme.dart';
import '../../core/device_model.dart';
import '../../core/device_provider.dart';

class DeviceSidebar extends StatefulWidget {
  const DeviceSidebar({super.key});

  @override
  State<DeviceSidebar> createState() => _DeviceSidebarState();
}

class _DeviceSidebarState extends State<DeviceSidebar> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 230,
      color: AppColors.sidebarBg,
      child: Column(
        children: [
          _buildHeader(),
          _buildSearch(),
          const Divider(height: 1),
          Expanded(child: _buildDeviceList()),
          const Divider(height: 1),
          _buildAddButton(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.accent, Color(0xFF5E5CE6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.wifi_tethering_rounded,
                color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          Text(
            'WirelessConnect',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 13,
                  letterSpacing: -0.3,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: Container(
        height: 30,
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
        ),
        child: TextField(
          controller: _searchController,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12,
          ),
          decoration: const InputDecoration(
            hintText: 'Search devices...',
            hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 12),
            prefixIcon: Icon(Icons.search, color: AppColors.textTertiary, size: 14),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 7),
          ),
          onChanged: (v) => setState(() => _query = v.toLowerCase()),
        ),
      ),
    );
  }

  Widget _buildDeviceList() {
    return Consumer<DeviceProvider>(
      builder: (context, provider, _) {
        final connected = provider.devices
            .where((d) =>
                d.isConnected &&
                (_query.isEmpty || d.displayName.toLowerCase().contains(_query)))
            .toList();
        final disconnected = provider.devices
            .where((d) =>
                !d.isConnected &&
                (_query.isEmpty || d.displayName.toLowerCase().contains(_query)))
            .toList();

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 4),
          children: [
            if (connected.isNotEmpty) ...[
              _sectionLabel('Connected'),
              ...connected.asMap().entries.map((e) => _DeviceCard(
                    device: e.value,
                    index: e.key,
                  )),
            ],
            if (disconnected.isNotEmpty) ...[
              _sectionLabel('Recent'),
              ...disconnected.asMap().entries.map((e) => _DeviceCard(
                    device: e.value,
                    index: e.key,
                  )),
            ],
            if (provider.devices.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(Icons.phonelink_off_rounded,
                        color: AppColors.textTertiary, size: 32),
                    const SizedBox(height: 8),
                    Text(
                      'No devices',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap + to connect your phone',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textTertiary,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _showPairingDialog(context),
          icon: const Icon(Icons.add_rounded, size: 16),
          label: const Text('Add Device'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.accent,
            padding: const EdgeInsets.symmetric(vertical: 10),
            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: AppColors.border),
            ),
            elevation: 0,
          ),
        ),
      ),
    );
  }

  void _showPairingDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const PairingDialog(),
    );
  }
}

class _DeviceCard extends StatefulWidget {
  final DeviceInfo device;
  final int index;

  const _DeviceCard({required this.device, required this.index});

  @override
  State<_DeviceCard> createState() => _DeviceCardState();
}

class _DeviceCardState extends State<_DeviceCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeviceProvider>();
    final isSelected = provider.selectedDevice?.id == widget.device.id;

    return Animate(
      effects: [
        FadeEffect(duration: 200.ms, delay: (widget.index * 50).ms),
        SlideEffect(
            begin: const Offset(-0.1, 0),
            duration: 200.ms,
            delay: (widget.index * 50).ms),
      ],
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: () {
            if (widget.device.isConnected) {
              provider.selectDevice(widget.device);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.accent.withOpacity(0.15)
                  : _hovered
                      ? AppColors.sidebarSelected
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border.all(color: AppColors.accent.withOpacity(0.4), width: 1)
                  : null,
            ),
            child: Row(
              children: [
                _batteryIcon(widget.device.batteryLevel),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.device.displayName,
                        style: TextStyle(
                          color: isSelected
                              ? AppColors.accent
                              : AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        widget.device.isConnected
                            ? widget.device.shortId
                            : 'Disconnected',
                        style: TextStyle(
                          color: widget.device.isConnected
                              ? AppColors.textSecondary
                              : AppColors.disconnected,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Status dot or Reconnect button
                if (widget.device.isConnected)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.connected,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.connected.withOpacity(0.5),
                          blurRadius: 4,
                        )
                      ],
                    ),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    color: AppColors.textTertiary,
                    hoverColor: AppColors.accent,
                    splashRadius: 16,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Reconnect',
                    onPressed: () {
                      provider.reconnectDevice(widget.device);
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _batteryIcon(int level) {
    final color = level > 20 ? AppColors.connected : AppColors.error;
    return Icon(
      level > 80
          ? Icons.battery_full_rounded
          : level > 50
              ? Icons.battery_5_bar_rounded
              : level > 20
                  ? Icons.battery_3_bar_rounded
                  : Icons.battery_1_bar_rounded,
      color: color,
      size: 18,
    );
  }
}
