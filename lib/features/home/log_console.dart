import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/logger.dart';

class LogConsole extends StatelessWidget {
  const LogConsole({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppLogger>(
      builder: (context, logger, child) {
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt.withOpacity(0.8),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  border: Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.3))),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.terminal, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    const Text('Terminal Log', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: logger.logs.join('\n')));
                      },
                      child: const Icon(Icons.copy, size: 14, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SelectionArea(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    reverse: true, // Show latest logs at bottom
                    itemCount: logger.logs.length,
                    itemBuilder: (context, index) {
                      // Reverse index to show latest at bottom
                      final log = logger.logs[logger.logs.length - 1 - index];
                      final isError = log.toLowerCase().contains('error') || log.toLowerCase().contains('failed');
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          log,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: isError ? AppColors.error : AppColors.textSecondary,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
