import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../core/providers/settings_providers.dart';
import '../../core/providers/service_providers.dart';

class BatteryOptimizationCard extends ConsumerStatefulWidget {
  const BatteryOptimizationCard({super.key});

  @override
  ConsumerState<BatteryOptimizationCard> createState() =>
      _BatteryOptimizationCardState();
}

class _BatteryOptimizationCardState extends ConsumerState<BatteryOptimizationCard> {
  bool _isOptimized = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkOptimizationStatus();
  }

  Future<void> _checkOptimizationStatus() async {
    final bridge = ref.read(accessibilityServiceManagerProvider);
    // Actually we need battery opt check from FlutterBridge. We can add a method to accessibility manager or create a system service provider.
    // For now, I'll invoke the channel directly to keep it self-contained.
    const channel =
        MethodChannel('com.personal.phone_addiction_controller/accessibility');
    try {
      final disabled =
          await channel.invokeMethod<bool>('isBatteryOptimizationDisabled');
      if (mounted) {
        setState(() {
          _isOptimized = !(disabled ?? false);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);

    if (_isLoading || !_isOptimized || settings.batteryOptDismissed) {
      return const SizedBox.shrink();
    }

    final cs = Theme.of(context).colorScheme;

    return Card(
      color: cs.errorContainer,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.battery_alert_rounded, color: cs.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Battery Optimization',
                    style: TextStyle(
                      color: cs.onErrorContainer,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: cs.onErrorContainer),
                  onPressed: () {
                    ref.read(appSettingsProvider.notifier).updateSettings(
                          settings.copyWith(batteryOptDismissed: true),
                        );
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Android may kill the Focus Guard background service to save battery. To ensure focus mode and schedules work reliably, please disable battery optimization for this app.',
              style: TextStyle(color: cs.onErrorContainer, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: cs.error,
                  foregroundColor: cs.onError,
                ),
                onPressed: () async {
                  const channel = MethodChannel(
                      'com.personal.phone_addiction_controller/accessibility');
                  try {
                    await channel.invokeMethod('openBatteryOptimizationSettings');
                  } catch (_) {}
                },
                child: const Text('Fix Now'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

