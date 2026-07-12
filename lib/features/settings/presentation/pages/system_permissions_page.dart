import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/providers/service_providers.dart';
import '../../../../core/providers/statistics_providers.dart';

class SystemPermissionsPage extends ConsumerStatefulWidget {
  const SystemPermissionsPage({super.key});

  @override
  ConsumerState<SystemPermissionsPage> createState() => _SystemPermissionsPageState();
}

class _SystemPermissionsPageState extends ConsumerState<SystemPermissionsPage> with WidgetsBindingObserver {
  bool _canDrawOverlays = false;
  bool _batteryOptDisabled = false;
  bool _isDefaultLauncher = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(accessibilityStatusProvider);
      ref.invalidate(appStatisticsProvider);
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    const channel = MethodChannel('com.personal.phone_addiction_controller/accessibility');
    try {
      final overlay = await channel.invokeMethod<bool>('canDrawOverlays');
      final battery = await channel.invokeMethod<bool>('isBatteryOptimizationDisabled');
      final launcher = await channel.invokeMethod<bool>('isDefaultLauncher');
      if (mounted) {
        setState(() {
          _canDrawOverlays = overlay ?? false;
          _batteryOptDisabled = battery ?? false;
          _isDefaultLauncher = launcher ?? false;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final accStatus = ref.watch(accessibilityStatusProvider).valueOrNull ?? false;
    final statsAsync = ref.watch(appStatisticsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF121414),
      appBar: AppBar(
        title: const Text('System Permissions'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF5E6AD2)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Statistics Row
              statsAsync.when(
                data: (stats) {
                  final hours = stats.todayFocusDuration.inHours;
                  final mins = stats.todayFocusDuration.inMinutes % 60;
                  final todayDur = hours > 0 ? '${hours}h ${mins}m' : '${mins}m';

                  return Row(
                    children: [
                      Expanded(
                        child: _buildPermissionStatCard(
                          icon: Icons.timer_outlined,
                          label: 'Focus',
                          value: todayDur,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildPermissionStatCard(
                          icon: Icons.task_alt_rounded,
                          label: 'Sessions',
                          value: stats.totalSessionsCompleted.toString(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildPermissionStatCard(
                          icon: Icons.auto_awesome_rounded,
                          label: 'Blocked',
                          value: stats.totalBlockedAttempts.toString(),
                          isHighlight: true,
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const SizedBox(),
              ),
              const SizedBox(height: 24),
              Text(
                'These permissions are critical for core functionality. Please ensure all are granted.',
                style: tt.bodyMedium?.copyWith(
                  color: const Color(0xFFC6C5D5),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),

              // Permissions List
              // 1. Accessibility Service Card
              _buildPermissionCard(
                icon: Icons.accessibility_new_rounded,
                title: 'Accessibility',
                description: 'Required to block distracting apps.',
                isGranted: accStatus,
                onPressed: () async {
                  final manager = ref.read(accessibilityServiceManagerProvider);
                  await manager.openAccessibilitySettings();
                },
                buttonText: 'Open Settings',
              ),

              // 2. Display Over Other Apps Card
              _buildPermissionCard(
                icon: Icons.layers_rounded,
                title: 'Display Over Other Apps',
                description: 'Shows blocking overlay screens.',
                isGranted: _canDrawOverlays,
                onPressed: () async {
                  const channel = MethodChannel('com.personal.phone_addiction_controller/accessibility');
                  try {
                    await channel.invokeMethod('openOverlayPermissionSettings');
                  } catch (_) {}
                },
                buttonText: 'Open Settings',
              ),

              // 3. Battery Optimization Card
              _buildPermissionCard(
                icon: Icons.battery_saver_rounded,
                title: 'Battery Optimization',
                description: 'Prevents background termination.',
                isGranted: _batteryOptDisabled,
                onPressed: () async {
                  const channel = MethodChannel('com.personal.phone_addiction_controller/accessibility');
                  try {
                    await channel.invokeMethod('openBatteryOptimizationSettings');
                  } catch (_) {}
                },
                buttonText: 'Disable Optimization',
              ),

              // 4. Default Home App Card
              _buildPermissionCard(
                icon: Icons.home_rounded,
                title: 'Default Home Launcher',
                description: 'Replaces Samsung One UI Home to stop gesture escape.',
                isGranted: _isDefaultLauncher,
                onPressed: () async {
                  final manager = ref.read(accessibilityServiceManagerProvider);
                  await manager.openDefaultLauncherSettings();
                },
                buttonText: 'Set Default Launcher',
              ),

              const SizedBox(height: 24),

              // Service Diagnostics Section
              Text(
                'Service Diagnostics',
                style: tt.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFE3E2E2),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF212123),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF2C2C2E), width: 1),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.monitor_heart_rounded, color: Color(0xFFC8C6C8), size: 20),
                          const SizedBox(height: 8),
                          Text(
                            'Heartbeat',
                            style: tt.bodySmall?.copyWith(color: const Color(0xFFC6C5D5)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            accStatus ? 'Active (12ms)' : 'Inactive',
                            style: tt.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: accStatus ? const Color(0xFF5E6AD2) : const Color(0xFFCF6679),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 50,
                      color: const Color(0xFF2C2C2E),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.memory_rounded, color: Color(0xFFC8C6C8), size: 20),
                            const SizedBox(height: 8),
                            Text(
                              'Service',
                              style: tt.bodySmall?.copyWith(color: const Color(0xFFC6C5D5)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              accStatus ? 'Running' : 'Stopped',
                              style: tt.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: accStatus ? const Color(0xFF4CAF7D) : const Color(0xFFCF6679),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionStatCard({
    required IconData icon,
    required String label,
    required String value,
    bool isHighlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF212123),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isHighlight ? const Color(0xFF5E6AD2).withOpacity(0.3) : const Color(0xFF2C2C2E),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: isHighlight ? const Color(0xFFFFB867) : const Color(0xFF5E6AD2), size: 24),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFFC6C5D5), letterSpacing: 1.1),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isHighlight ? const Color(0xFFFFB867) : const Color(0xFFE3E2E2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionCard({
    required IconData icon,
    required String title,
    required String description,
    required bool isGranted,
    required VoidCallback onPressed,
    required String buttonText,
  }) {
    final tt = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF212123),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF2C2C2E), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isGranted ? const Color(0xFF5E6AD2).withOpacity(0.1) : const Color(0xFF1A1C1C),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isGranted ? const Color(0xFF5E6AD2) : const Color(0xFFC6C5D5),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFE3E2E2),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: tt.bodySmall?.copyWith(
                        color: const Color(0xFFC6C5D5),
                      ),
                    ),
                  ],
                ),
              ),
              if (isGranted)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1C1C),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'Granted',
                    style: TextStyle(
                      color: Color(0xFFC6C5D5),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          if (!isGranted) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5E6AD2),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                onPressed: onPressed,
                child: Text(
                  buttonText,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
