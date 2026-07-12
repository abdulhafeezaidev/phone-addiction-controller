import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/route_names.dart';
import '../../../../core/providers/service_providers.dart';

class SetupWizardPage extends ConsumerStatefulWidget {
  const SetupWizardPage({super.key});

  @override
  ConsumerState<SetupWizardPage> createState() => _SetupWizardPageState();
}

class _SetupWizardPageState extends ConsumerState<SetupWizardPage>
    with WidgetsBindingObserver {
  bool _notificationsEnabled = true;
  bool _usageTrackingEnabled = false;
  bool _isDefaultLauncher = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkLauncherStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkLauncherStatus();
    }
  }

  Future<void> _checkLauncherStatus() async {
    final manager = ref.read(accessibilityServiceManagerProvider);
    final isDefault = await manager.isDefaultLauncher();
    if (mounted) {
      setState(() => _isDefaultLauncher = isDefault);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: const Color(0xFF121414),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 60),
              // Top viewing area
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2020),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF343535), width: 1),
                ),
                child: const Icon(
                  Icons.shield_rounded,
                  size: 60,
                  color: Color(0xFF5E6AD2),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Welcome to Focus Vault',
                style: tt.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 28,
                  color: const Color(0xFF5E6AD2),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                "Let's set up your secure environment. We need a few permissions to ensure your focus sessions are uninterrupted and your data remains private.",
                style: tt.bodyMedium?.copyWith(
                  color: const Color(0xFFC6C5D5),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              // Interaction Area / Permissions Cards List
              Expanded(
                child: ListView(
                  children: [
                    // Permission Card 1: Notifications
                    _buildPermissionCard(
                      context,
                      icon: Icons.notifications_active_rounded,
                      title: 'Notifications',
                      description: 'Allow Focus Vault to manage alerts.',
                      reason: 'Why this is needed: To show session alerts',
                      trailing: Switch(
                        value: _notificationsEnabled,
                        onChanged: (val) {
                          setState(() => _notificationsEnabled = val);
                        },
                      ),
                    ),
                    // Permission Card 2: Usage Tracking
                    _buildPermissionCard(
                      context,
                      icon: Icons.data_usage_rounded,
                      title: 'Usage Tracking',
                      description: 'Required for detailed focus stats.',
                      reason: 'Why this is needed: To monitor focus sessions',
                      trailing: Switch(
                        value: _usageTrackingEnabled,
                        onChanged: (val) {
                          setState(() => _usageTrackingEnabled = val);
                        },
                      ),
                    ),
                    // Permission Card 3: Default Launcher
                    _buildPermissionCard(
                      context,
                      icon: Icons.home_rounded,
                      title: 'Set as Home Launcher',
                      description:
                          'Makes Focus Guard your default Home screen during focus sessions.',
                      reason:
                          'Why this is needed: Home button returns here — true bypass prevention',
                      borderColor: _isDefaultLauncher
                          ? const Color(0xFF4CAF7D).withOpacity(0.5)
                          : const Color(0xFFFFB867).withOpacity(0.4),
                      trailing: _isDefaultLauncher
                          ? Container(
                              width: 40,
                              height: 40,
                              decoration: const BoxDecoration(
                                color: Color(0xFF1E2820),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFF4CAF7D),
                                size: 24,
                              ),
                            )
                          : SizedBox(
                              height: 36,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFFFFB867),
                                  foregroundColor: const Color(0xFF1E1E1E),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () async {
                                  final manager = ref.read(
                                      accessibilityServiceManagerProvider);
                                  await manager.openDefaultLauncherSettings();
                                },
                                child: const Text(
                                  'Set Up',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              // Bottom Action button and indicators
              Padding(
                padding: const EdgeInsets.only(bottom: 24.0, top: 16.0),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5E6AD2),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () async {
                          // Complete onboarding, save flag
                          final storage = ref.read(storageServiceProvider);
                          await storage.put(
                            AppConstants.settingsBox,
                            'onboarding_completed',
                            true,
                          );
                          if (context.mounted) {
                            context.go(RouteNames.home);
                          }
                        },
                        child: Text(
                          'Continue',
                          style: tt.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF5E6AD2),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF343535),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF343535),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required String reason,
    required Widget trailing,
    Color borderColor = const Color(0xFF2C2C2E),
  }) {
    final tt = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF212123),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Color(0xFF1E2020),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: const Color(0xFFE3E2E2),
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
                const SizedBox(height: 4),
                Text(
                  reason,
                  style: tt.bodySmall?.copyWith(
                    color: const Color(0xFF5E6AD2),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}
