import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'core/app_theme.dart';
import 'core/device_provider.dart';
import 'core/logger.dart';
import 'features/home/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure window
  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      size: Size(1100, 750),
      minimumSize: Size(900, 600),
      center: true,
      title: 'WirelessConnect',
      backgroundColor: Color(0xFF1C1C1E),
      titleBarStyle: TitleBarStyle.hidden,
    ),
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );

  runApp(const WirelessConnectApp());
}

class WirelessConnectApp extends StatelessWidget {
  const WirelessConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DeviceProvider()),
        ChangeNotifierProvider.value(value: AppLogger.instance),
      ],
      child: MaterialApp(
        title: 'WirelessConnect',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const HomeScreen(),
        builder: (context, child) {
          // Global animate config
          return Animate.restartOnHotReload
              ? child!
              : child!;
        },
      ),
    );
  }
}
