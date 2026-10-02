import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/device_provider.dart';
import '../../widgets/control_panel/control_panel.dart';
import '../../widgets/phone_frame/phone_frame_widget.dart';
import '../../widgets/sidebar/device_sidebar.dart';
import 'log_console.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize ADB after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeviceProvider>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Consumer<DeviceProvider>(
        builder: (context, provider, _) {
          // ADB check screen
          if (provider.isCheckingAdb) {
            return _loadingView('Starting ADB...');
          }

          if (!provider.isAdbAvailable) {
            return _adbNotFoundView();
          }

          return Column(
            children: [
              _buildTopBar(provider),
              Expanded(
                child: Row(
                  children: [
                    // Left: Device sidebar
                    const DeviceSidebar(),
                    const VerticalDivider(width: 1),
                    // Center: Phone preview
                    Expanded(
                      child: Container(
                        color: AppColors.bg,
                        child: const Center(
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: PhoneFrameWidget(),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    // Right: Control panel
                    const ControlPanel(),
                  ],
                ),
              ),
              // Terminal Log View
              const SizedBox(
                height: 150,
                child: LogConsole(),
              ),
              // Status bar at bottom
              _buildStatusBar(provider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTopBar(DeviceProvider provider) {
    return Container(
      height: 44,
      color: AppColors.sidebarBg,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // macOS traffic light placeholder spacing
          const SizedBox(width: 70),
          const Spacer(),
          Text(
            'WirelessConnect',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  letterSpacing: -0.3,
                  color: AppColors.textSecondary,
                ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () => provider.restartAdbServer(),
            icon: const Icon(Icons.refresh_rounded, size: 14, color: AppColors.accent),
            label: const Text('Fix ADB Conflict', style: TextStyle(fontSize: 12, color: AppColors.accent)),
          ),
          const SizedBox(width: 8),
          // Device count badge
          if (provider.devices.where((d) => d.isConnected).isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.connected.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.connected.withOpacity(0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.connected,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${provider.devices.where((d) => d.isConnected).length} connected',
                    style: const TextStyle(
                      color: AppColors.connected,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusBar(DeviceProvider provider) {
    final msg = provider.statusMessage ?? provider.errorMessage;
    final isError = provider.errorMessage != null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: msg != null ? 28 : 0,
      color: isError
          ? AppColors.error.withOpacity(0.15)
          : AppColors.accent.withOpacity(0.1),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: msg != null
          ? Row(
              children: [
                Icon(
                  isError ? Icons.error_outline_rounded : Icons.info_outline_rounded,
                  size: 13,
                  color: isError ? AppColors.error : AppColors.accent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    msg,
                    style: TextStyle(
                      color: isError ? AppColors.error : AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: provider.clearMessages,
                  child: const Icon(Icons.close_rounded,
                      size: 13, color: AppColors.textTertiary),
                ),
              ],
            )
          : null,
    );
  }

  Widget _loadingView(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppColors.accent),
          const SizedBox(height: 16),
          Text(message, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ).animate().fadeIn(duration: 300.ms),
    );
  }

  Widget _adbNotFoundView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.warning_amber_rounded,
                color: AppColors.error, size: 40),
          ),
          const SizedBox(height: 20),
          Text(
            'ADB Not Found',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'ADB (Android Debug Bridge) must be installed on your system.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Install Android SDK Platform Tools and add to PATH.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () =>
                context.read<DeviceProvider>().initialize(),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ).animate().fadeIn(duration: 400.ms),
    );
  }
}
