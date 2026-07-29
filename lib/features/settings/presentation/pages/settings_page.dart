import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/route_names.dart';
import '../../../../core/providers/service_providers.dart';
import '../../../../core/providers/admin_auth_provider.dart';
import '../../../../core/providers/settings_providers.dart';
import '../../../../core/providers/statistics_providers.dart';
import '../../../../core/providers/focus_providers.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage>
    with WidgetsBindingObserver {
  int _versionTapCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(defaultLauncherStatusProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final isDefaultLauncher =
        ref.watch(defaultLauncherStatusProvider).valueOrNull ?? false;
    final isDeviceOwner =
        ref.watch(isDeviceOwnerProvider).valueOrNull ?? false;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(RouteNames.home);
      },
      child: Scaffold(
      backgroundColor: const Color(0xFF121414),
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF5E6AD2), Color(0xFF3B438B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF5E6AD2).withValues(alpha: 0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'FocusOS Preferences',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Configure security protocols, bypasses, and launcher controls below.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Card 1: General Settings
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF212123),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF2C2C2E), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: Text(
                      'General',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFC6C5D5),
                      ),
                    ),
                  ),
                  // Administrator Password
                  _buildSettingsRow(
                    icon: Icons.lock_rounded,
                    title: 'Administrator Password',
                    subtitle: 'Set a PIN to protect settings',
                    onTap: () => context.push(RouteNames.adminPassword),
                  ),
                  _buildDivider(),
                  // Focus Lock PIN
                  _buildSettingsRow(
                    icon: Icons.pin_rounded,
                    title: 'Focus Lock PIN',
                    subtitle: 'PIN for FocusOS lock screen',
                    onTap: () => context.push(RouteNames.focusLockPin),
                  ),
                  _buildDivider(),
                  // Emergency Override
                  _buildSettingsRow(
                    icon: Icons.gpp_maybe_rounded,
                    title: 'Emergency Override',
                    subtitle: 'Temporarily suspend focus protections',
                    onTap: () => context.push(RouteNames.emergencyOverride),
                  ),
                  _buildDivider(),
                  // Auto-Start on Boot Toggle
                  _buildSettingsToggle(
                    icon: Icons.restart_alt_rounded,
                    title: 'Auto-Start on Boot',
                    subtitle: 'Resume blocking after restart',
                    value: settings.autoStartOnBoot,
                    onChanged: (val) async {
                      final isFocusActive = ref.read(focusModeProvider);
                      void action() {
                        ref.read(appSettingsProvider.notifier).updateSettings(
                          settings.copyWith(autoStartOnBoot: val),
                        );
                      }

                      if (isFocusActive) {
                        await ref.read(adminAuthProvider.notifier).runProtectedAction(context, action);
                      } else {
                        action();
                      }
                    },
                  ),
                  _buildDivider(),
                  // Focus Reminders Toggle
                  _buildSettingsToggle(
                    icon: Icons.notifications_active_rounded,
                    title: 'Focus Reminders',
                    subtitle: 'Notify when scheduled session starts',
                    value: settings.notificationsEnabled,
                    onChanged: (val) {
                      ref.read(appSettingsProvider.notifier).updateSettings(
                        settings.copyWith(notificationsEnabled: val),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Card 2: Focus Behaviour
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF212123),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF2C2C2E), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: Text(
                      'Focus Behaviour',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFC6C5D5),
                      ),
                    ),
                  ),
                  // Strict Mode Toggle
                  _buildSettingsToggle(
                    icon: Icons.security_rounded,
                    title: 'Strict Mode',
                    subtitle: isDeviceOwner
                        ? 'Enforces unbreakable Lock Task Mode'
                        : 'Requires Device Owner setup via ADB',
                    value: settings.strictMode && isDeviceOwner,
                    enabled: isDeviceOwner,
                    onChanged: (val) async {
                      final isFocusActive = ref.read(focusModeProvider);
                      void action() {
                        ref.read(appSettingsProvider.notifier).updateSettings(
                          settings.copyWith(strictMode: val),
                        );
                      }

                      if (isFocusActive) {
                        await ref.read(adminAuthProvider.notifier).runProtectedAction(context, action);
                      } else {
                        action();
                      }
                    },
                  ),
                  _buildDivider(),
                  // Default Launcher
                  _buildSettingsRow(
                    icon: Icons.home_rounded,
                    title: 'Default Launcher',
                    subtitle: isDefaultLauncher
                        ? 'FocusOS is the default Home app'
                        : 'Set FocusOS as default Home app',
                    iconColor: isDefaultLauncher
                        ? const Color(0xFF4CAF7D)
                        : const Color(0xFFFFB867),
                    onTap: () async {
                      final manager =
                          ref.read(accessibilityServiceManagerProvider);
                      await manager.openDefaultLauncherSettings();
                    },
                  ),
                  _buildDivider(),
                  // System Permissions
                  _buildSettingsRow(
                    icon: Icons.accessibility_new_rounded,
                    title: 'System Permissions',
                    subtitle: 'Check system service permissions',
                    onTap: () => context.push(RouteNames.permissions),
                  ),
                  _buildDivider(),
                  // Backup Data
                  _buildSettingsRow(
                    icon: Icons.backup_rounded,
                    title: 'Backup Data',
                    subtitle: 'Export your routines and stats',
                    onTap: () async {
                      final service = ref.read(backupRestoreServiceProvider);
                      final success = await service.saveBackupToFile();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(success ? 'Backup saved successfully' : 'Backup cancelled')),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Card 3: Device Owner Management
            if (isDeviceOwner)
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF212123),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF2C2C2E), width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
                      child: Text(
                        'Device Owner',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFC6C5D5),
                        ),
                      ),
                    ),
                    _buildSettingsRow(
                      icon: Icons.shield_rounded,
                      title: 'Remove Device Owner',
                      subtitle: 'Removes all protections (requires PIN)',
                      iconColor: const Color(0xFFCF6679),
                      onTap: () => _handleRemoveDeviceOwner(),
                    ),
                  ],
                ),
              ),
            if (isDeviceOwner) const SizedBox(height: 16),

            // Card 4: About
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF212123),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF2C2C2E), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: Text(
                      'About',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFC6C5D5),
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: _handleVersionTap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFF5E6AD2).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.info_outline_rounded, color: Color(0xFF5E6AD2), size: 22),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'FocusOS',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFE3E2E2),
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Version 1.0.0',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFFC6C5D5),
                                  ),
                                ),
                              ],
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

  Widget _buildSettingsRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color iconColor = const Color(0xFF5E6AD2),
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFE3E2E2),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFC6C5D5),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFC6C5D5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsToggle({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    Color iconColor = const Color(0xFF5E6AD2),
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (enabled ? iconColor : Colors.grey).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: enabled ? iconColor : Colors.grey,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: enabled ? const Color(0xFFE3E2E2) : const Color(0xFFE3E2E2).withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: enabled ? const Color(0xFFC6C5D5) : const Color(0xFFC6C5D5).withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Switch(
              value: value,
              onChanged: enabled ? onChanged : null,
              thumbColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) return const Color(0xFF636363);
                if (states.contains(WidgetState.selected)) return Colors.white;
                return const Color(0xFF9E9E9E);
              }),
              trackColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) return const Color(0xFF1A1A1A);
                if (states.contains(WidgetState.selected)) return const Color(0xFF5E6AD2);
                return const Color(0xFF2C2C2E);
              }),
              trackOutlineColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return Colors.transparent;
                return const Color(0xFF4A4A4C);
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(
      color: Color(0xFF2C2C2E),
      height: 1,
      indent: 76,
    );
  }

  void _handleVersionTap() {
    _versionTapCount++;
    if (_versionTapCount >= 7) {
      _versionTapCount = 0;
      context.push(RouteNames.diagnostics);
    } else if (_versionTapCount >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${7 - _versionTapCount} more taps for diagnostics'),
          duration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  Future<void> _handleRemoveDeviceOwner() async {
    // Must authenticate first
    final isFocusActive = ref.read(focusModeProvider);
    if (isFocusActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot remove Device Owner while Focus Mode is active. End the session first.'),
        ),
      );
      return;
    }

    // Require admin password
    bool authenticated = false;
    await ref.read(adminAuthProvider.notifier).runProtectedAction(context, () {
      authenticated = true;
    });

    if (!authenticated || !mounted) return;

    // Confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF212123),
        title: const Text('Remove Device Owner?', style: TextStyle(color: Color(0xFFE3E2E2))),
        content: const Text(
          'This will:\n'
          '• Remove uninstall protection\n'
          '• Remove Lock Task Mode\n'
          '• Clear all device restrictions\n'
          '• Allow FocusOS to be uninstalled\n\n'
          'This action cannot be undone without re-provisioning via ADB.',
          style: TextStyle(color: Color(0xFFC6C5D5), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove', style: TextStyle(color: Color(0xFFCF6679))),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final manager = ref.read(accessibilityServiceManagerProvider);
      final result = await manager.sendCommand('removeDeviceOwner');
      if (mounted) {
        ref.invalidate(isDeviceOwnerProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result == true
                ? 'Device Owner removed successfully'
                : 'Device Owner was not active'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove Device Owner: $e')),
        );
      }
    }
  }
}
