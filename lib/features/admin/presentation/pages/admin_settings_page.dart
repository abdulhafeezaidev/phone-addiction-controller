import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/route_names.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/focus_tokens.dart';
import '../../../../domain/models/admin_settings.dart';
import '../../../../services/native_bridge_service.dart';
import '../../../../widgets/admin_password_dialog.dart';

class AdminSettingsPage extends ConsumerStatefulWidget {
  const AdminSettingsPage({super.key});

  @override
  ConsumerState<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends ConsumerState<AdminSettingsPage>
    with WidgetsBindingObserver {
  bool _isProcessing = false;

  // Live Permission & Protection State
  bool _isAccessibilityEnabled = false;
  bool _isDeviceAdminActive = false;
  bool _isBatteryOptDisabled = false;
  bool _areNotificationsEnabled = false;
  bool _isTamperProtectionEnabled = false;
  ProtectionState _protectionStatus = const ProtectionState();

  // Emergency Override Protocol State
  String _recoveryChallenge = 'Loading...';
  int _reflectionMinutes = 15;
  int _overrideHours = 24;
  int _cooldownHours = 24;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAllSettingsState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadAllSettingsState();
    }
  }

  Future<void> _loadAllSettingsState() async {
    final native = ref.read(nativeBridgeServiceProvider);
    final emergencyService = ref.read(emergencyOverrideServiceProvider);

    final a11y = await native.isServiceEnabled();
    final battery = await native.isBatteryOptimizationDisabled();
    final notifs = await native.areNotificationsEnabled();
    final protection = await native.getProtectionState();
    final challenge = await emergencyService.getRecoveryChallenge();

    if (mounted) {
      setState(() {
        _isAccessibilityEnabled = a11y;
        _isDeviceAdminActive = protection.deviceAdminActive;
        _isBatteryOptDisabled = battery;
        _areNotificationsEnabled = notifs;
        _isTamperProtectionEnabled = protection.guardEnabled;
        _protectionStatus = protection;
        _recoveryChallenge = challenge ?? 'Not Set';
        _reflectionMinutes = emergencyService.reflectionDuration.inMinutes;
        _overrideHours = emergencyService.overrideDuration.inHours;
        _cooldownHours = emergencyService.cooldownDuration.inHours;
      });
    }
    ref.invalidate(accessibilityEnabledProvider);
    ref.invalidate(protectionStateProvider);
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _editPartnerInfo(AdminSettings? current) async {
    final authorized = await AdminPasswordDialog.show(
      context,
      actionDescription: 'update accountability partner details',
    );
    if (!authorized || !mounted) return;

    final nameController =
        TextEditingController(text: current?.adminName ?? '');
    final contactController =
        TextEditingController(text: current?.adminContact ?? '');
    String? dialogError;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: FocusTokens.surface,
          title: const Text(
            'Update Accountability Partner',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Partner Name *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contactController,
                decoration: const InputDecoration(
                    labelText: 'Partner Reminder Note (Optional, local only)'),
              ),
              if (dialogError != null) ...[
                const SizedBox(height: 10),
                Text(
                  dialogError!,
                  style: const TextStyle(
                      color: FocusTokens.danger,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) {
                  setDialogState(
                      () => dialogError = 'Partner name cannot be empty.');
                  return;
                }
                Navigator.of(ctx).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: FocusTokens.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      final name = nameController.text.trim();
      final contact = contactController.text.trim();
      await ref.read(passwordServiceProvider).updateAdminProfile(
            adminName: name.isNotEmpty ? name : null,
            adminContact: contact.isNotEmpty ? contact : null,
          );
      ref.invalidate(adminSettingsProvider);
      if (mounted) {
        _showToast('Partner details updated successfully.');
      }
    }
  }

  Future<void> _changePassword() async {
    final authorized = await AdminPasswordDialog.show(
      context,
      actionDescription: 'change the admin master password',
    );
    if (!authorized || !mounted) return;

    final newController = TextEditingController();
    final confirmController = TextEditingController();
    bool obscureNew = true;
    bool obscureConfirm = true;
    String? dialogError;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: FocusTokens.surface,
          title: const Text(
            'Set New Admin Password',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: newController,
                  obscureText: obscureNew,
                  decoration: InputDecoration(
                    labelText: 'New Password (min 4 chars)',
                    suffixIcon: IconButton(
                      icon: Icon(obscureNew
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                      onPressed: () =>
                          setDialogState(() => obscureNew = !obscureNew),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmController,
                  obscureText: obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    suffixIcon: IconButton(
                      icon: Icon(obscureConfirm
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                      onPressed: () => setDialogState(
                          () => obscureConfirm = !obscureConfirm),
                    ),
                  ),
                ),
                if (dialogError != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    dialogError!,
                    style: const TextStyle(
                        color: FocusTokens.danger,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (newController.text.length < 4) {
                  setDialogState(() => dialogError =
                      'New password must be at least 4 characters.');
                  return;
                }
                if (newController.text != confirmController.text) {
                  setDialogState(
                      () => dialogError = 'New passwords do not match.');
                  return;
                }
                Navigator.of(ctx).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: FocusTokens.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Update Password'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      final passwordService = ref.read(passwordServiceProvider);
      await passwordService.setPassword(newController.text);
      ref.invalidate(adminSettingsProvider);
      if (mounted) {
        _showToast('Admin password changed successfully.');
      }
    }
  }

  Future<void> _updateEmergencyQuestion() async {
    final authorized = await AdminPasswordDialog.show(
      context,
      actionDescription: 'update the emergency security challenge',
    );
    if (!authorized || !mounted) return;

    final questionController = TextEditingController(text: _recoveryChallenge);
    final answerController = TextEditingController();
    String? dialogError;

    final emergencyService = ref.read(emergencyOverrideServiceProvider);

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: FocusTokens.surface,
          title: const Text(
            'Emergency Security Challenge',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Used to verify emergency override requests when your accountability partner cannot be reached.',
                  style: TextStyle(fontSize: 12, color: FocusTokens.inkMuted),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: questionController,
                  decoration:
                      const InputDecoration(labelText: 'Security Question'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: answerController,
                  decoration:
                      const InputDecoration(labelText: 'New Secret Answer'),
                ),
                if (dialogError != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    dialogError!,
                    style: const TextStyle(
                        color: FocusTokens.danger,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (questionController.text.trim().isEmpty) {
                  setDialogState(
                      () => dialogError = 'Please enter a security question.');
                  return;
                }
                if (answerController.text.trim().length < 2) {
                  setDialogState(() =>
                      dialogError = 'Answer must be at least 2 characters.');
                  return;
                }
                Navigator.of(ctx).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: FocusTokens.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Save Challenge'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      await emergencyService.setRecoveryChallenge(
        questionController.text.trim(),
        answerController.text.trim(),
      );
      await _loadAllSettingsState();
      if (mounted) {
        _showToast('Emergency security challenge updated.');
      }
    }
  }

  Future<void> _configureEmergencyProtocolDurations() async {
    final authorized = await AdminPasswordDialog.show(
      context,
      actionDescription: 'change emergency override protocol timers',
    );
    if (!authorized || !mounted) return;

    int tempReflection = _reflectionMinutes;
    int tempOverride = _overrideHours;
    int tempCooldown = _cooldownHours;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: FocusTokens.surface,
          title: const Text(
            'Emergency Override Protocol',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Configure timing buffers for emergency access requests:',
                  style: TextStyle(fontSize: 12, color: FocusTokens.inkMuted),
                ),
                const SizedBox(height: 16),

                // 1. Reflection Duration
                _buildDialogDropdown<int>(
                  label: 'Reflection Delay (Wait before unlock)',
                  value: tempReflection,
                  items: const [5, 10, 15, 30, 60],
                  itemLabelBuilder: (v) => '$v minutes',
                  onChanged: (v) {
                    if (v != null) setDialogState(() => tempReflection = v);
                  },
                ),
                const SizedBox(height: 14),

                // 2. Override Access Duration
                _buildDialogDropdown<int>(
                  label: 'Override Access Window',
                  value: tempOverride,
                  items: const [1, 3, 6, 12, 24],
                  itemLabelBuilder: (v) => '$v ${v == 1 ? "hour" : "hours"}',
                  onChanged: (v) {
                    if (v != null) setDialogState(() => tempOverride = v);
                  },
                ),
                const SizedBox(height: 14),

                // 3. Cooldown Duration
                _buildDialogDropdown<int>(
                  label: 'Cooldown Period Between Overrides',
                  value: tempCooldown,
                  items: const [6, 12, 24, 48, 72],
                  itemLabelBuilder: (v) => '$v hours',
                  onChanged: (v) {
                    if (v != null) setDialogState(() => tempCooldown = v);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: FocusTokens.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Save Protocol'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      final emergencyService = ref.read(emergencyOverrideServiceProvider);
      await emergencyService.updateProtocolSettings(
        reflectionMinutes: tempReflection,
        overrideHours: tempOverride,
        cooldownHours: tempCooldown,
      );
      await _loadAllSettingsState();
      _showToast('Emergency override protocol updated.');
    }
  }

  Widget _buildDialogDropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required String Function(T) itemLabelBuilder,
    required ValueChanged<T?> onChanged,
  }) {
    final effectiveValue = items.contains(value) ? value : items.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: FocusTokens.ink),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: FocusTokens.elevated,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              isExpanded: true,
              value: effectiveValue,
              items: items
                  .map((item) => DropdownMenuItem<T>(
                        value: item,
                        child: Text(itemLabelBuilder(item),
                            style: const TextStyle(fontSize: 13.5)),
                      ))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _toggleTamperGuard(bool enable) async {
    final native = ref.read(nativeBridgeServiceProvider);
    var changed = false;
    try {
      if (enable) {
        changed = await native.enableProtectionGuard();
      } else {
        changed = await runAuthenticatedProtectionAction(
          authenticate: () => AdminPasswordDialog.show(
            context,
            actionDescription: 'pause the best-effort screen guard',
          ),
          action: native.disableProtectionGuardAfterAuthentication,
        );
      }
    } catch (e) {
      if (mounted) _showToast('Could not update the screen guard: $e');
    }
    await _loadAllSettingsState();
    if (changed && mounted) {
      _showToast(enable
          ? 'Best-effort screen guard enabled.'
          : 'Best-effort screen guard paused.');
    }
  }

  Future<void> _deactivateDeviceAdmin() async {
    final native = ref.read(nativeBridgeServiceProvider);
    try {
      final changed = await runAuthenticatedProtectionAction(
        authenticate: () => AdminPasswordDialog.show(
          context,
          actionDescription: 'deactivate Android Device Admin',
        ),
        action: native.deactivateDeviceAdminAfterAuthentication,
      );
      await _loadAllSettingsState();
      if (changed && mounted) {
        _showToast(
            'Device Admin deactivated. Android uninstall deterrence is off.');
      }
    } catch (e) {
      if (mounted) _showToast('Could not deactivate Device Admin: $e');
    }
  }

  Future<void> _toggleOwnerUninstallBlock(bool blocked) async {
    final native = ref.read(nativeBridgeServiceProvider);
    try {
      final changed = blocked
          ? await native.setOwnerUninstallBlocked()
          : await runAuthenticatedProtectionAction(
              authenticate: () => AdminPasswordDialog.show(
                context,
                actionDescription: 'disable Android-managed uninstall blocking',
              ),
              action: native.disableOwnerUninstallBlockedAfterAuthentication,
            );
      await _loadAllSettingsState();
      if (changed && mounted) {
        _showToast(blocked
            ? 'Android-managed uninstall blocking enabled.'
            : 'Android-managed uninstall blocking disabled.');
      }
    } catch (e) {
      if (mounted) {
        _showToast('Could not update managed uninstall blocking: $e');
      }
    }
  }

  Future<void> _handleUninstallApp() async {
    // 1. Confirm intention with dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FocusTokens.surface,
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: FocusTokens.danger),
            SizedBox(width: 8),
            Text('Uninstall Detox?'),
          ],
        ),
        content: const Text(
          'Device Admin makes Android ask you to deactivate it before uninstalling. The optional screen guard is best-effort and can be bypassed by changing Android settings.\n\n'
          'Your accountability partner must authorize the in-app deactivation flow. Android still controls the final uninstall step.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: FocusTokens.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (!mounted) return;
    setState(() => _isProcessing = true);
    final native = ref.read(nativeBridgeServiceProvider);
    var authorized = false;

    try {
      final success = await runAuthenticatedProtectionAction(
        authenticate: () async {
          authorized = await AdminPasswordDialog.show(
            context,
            actionDescription:
                'deactivate Detox protection and continue to uninstall',
          );
          return authorized;
        },
        action: native.prepareUninstall,
      );
      if (authorized && !success && mounted) {
        _showToast('Android could not open the uninstall confirmation screen.');
      }
    } catch (e) {
      if (mounted) _showToast('Could not prepare uninstall: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final adminAsync = ref.watch(adminSettingsProvider);
    final native = ref.read(nativeBridgeServiceProvider);

    final admin = adminAsync.valueOrNull;
    final partnerName = admin?.adminName?.trim().isNotEmpty == true
        ? admin!.adminName!.trim()
        : 'Not Set';
    final partnerContact = admin?.adminContact?.trim().isNotEmpty == true
        ? admin!.adminContact!.trim()
        : 'Not Set';

    return Scaffold(
      backgroundColor: FocusTokens.canvas,
      appBar: AppBar(
        title: const Text(
          'Settings & Admin Control',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: FocusTokens.ink,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Status',
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: _loadAllSettingsState,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 1. Accountability Partner & Admin Password ─────────────────
            _buildSectionHeader('Accountability Partner & Admin Password'),
            Container(
              decoration: _cardDecoration(),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.person_rounded,
                        color: FocusTokens.primary),
                    title: const Text('Partner Name',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: Text(partnerName,
                        style: const TextStyle(
                            fontSize: 13, color: FocusTokens.inkMuted)),
                    trailing: const Icon(Icons.edit_outlined,
                        size: 18, color: FocusTokens.inkMuted),
                    onTap: () => _editPartnerInfo(admin),
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.sticky_note_2_outlined,
                        color: FocusTokens.primary),
                    title: const Text('Partner Reminder Note',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: Text(partnerContact,
                        style: const TextStyle(
                            fontSize: 13, color: FocusTokens.inkMuted)),
                    trailing: const Icon(Icons.edit_outlined,
                        size: 18, color: FocusTokens.inkMuted),
                    onTap: () => _editPartnerInfo(admin),
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.password_rounded,
                        color: FocusTokens.primary),
                    title: const Text('Change Admin Password',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: const Text(
                        'Update the master password held by your partner',
                        style: TextStyle(
                            fontSize: 12, color: FocusTokens.inkMuted)),
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: FocusTokens.inkMuted),
                    onTap: _changePassword,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── 2. Emergency Override Protocol ─────────────────────────────
            _buildSectionHeader('Emergency Override Protocol'),
            Container(
              decoration: _cardDecoration(),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.quiz_rounded,
                        color: FocusTokens.warning),
                    title: const Text('Security Challenge Question',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      _recoveryChallenge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: FocusTokens.inkMuted),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: FocusTokens.inkMuted),
                    onTap: _updateEmergencyQuestion,
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.timer_outlined,
                        color: FocusTokens.warning),
                    title: const Text('Override Protocol Timers',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      'Reflection: ${_reflectionMinutes}m • Access: ${_overrideHours}h • Cooldown: ${_cooldownHours}h',
                      style: const TextStyle(
                          fontSize: 12, color: FocusTokens.inkMuted),
                    ),
                    trailing: const Icon(Icons.tune_rounded,
                        size: 18, color: FocusTokens.inkMuted),
                    onTap: _configureEmergencyProtocolDurations,
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.emergency_outlined,
                        color: FocusTokens.warning),
                    title: const Text('Open Emergency Override',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: const Text(
                      'Request or manage emergency bypass access',
                      style: TextStyle(
                          fontSize: 12, color: FocusTokens.inkMuted),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: FocusTokens.inkMuted),
                    onTap: () => context.push(RouteNames.emergencyOverride),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── 3. System Implementation & Permissions ─────────────────────
            _buildSectionHeader('System Implementation & Permissions'),
            Container(
              decoration: _cardDecoration(),
              child: Column(
                children: [
                  _buildStatusTile(
                    icon: Icons.accessibility_new_rounded,
                    title: 'Accessibility Service',
                    subtitle: _isAccessibilityEnabled
                        ? 'Active — detecting & blocking restricted apps'
                        : 'Inactive — tap to turn on in Android Settings',
                    isActive: _isAccessibilityEnabled,
                    actionText: _isAccessibilityEnabled ? 'Manage' : 'Turn On',
                    onTap: () => native.openAccessibilitySettings(),
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildStatusTile(
                    icon: Icons.admin_panel_settings_rounded,
                    title: 'Device Administrator',
                    subtitle: !_protectionStatus.statusAvailable
                        ? 'Status unavailable — reopen the app to check Android policy state'
                        : !_protectionStatus.deviceAdminSupported
                            ? 'Not supported by this Android device.'
                            : _isDeviceAdminActive
                                ? 'Active — Android requires deactivation before uninstall; this is not an OS-enforced uninstall block'
                                : 'Inactive — Android may uninstall without a system confirmation. Enable to add the Device Admin step.',
                    isActive: _isDeviceAdminActive,
                    actionText: !_protectionStatus.deviceAdminSupported
                        ? 'Unsupported'
                        : _isDeviceAdminActive
                            ? 'Deactivate (PIN)'
                            : 'Enable',
                    onTap: () async {
                      if (!_protectionStatus.deviceAdminSupported) {
                        return;
                      }
                      if (!_isDeviceAdminActive) {
                        try {
                          final opened = await native.requestDeviceAdmin();
                          if (mounted) {
                            _showToast(
                              opened
                                  ? 'Android admin activation opened. Confirm there to enable protection.'
                                  : 'Android did not open the admin activation screen. Open Security settings and try again.',
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            _showToast(
                                'Could not open Android admin settings: $e');
                          }
                        }
                      } else {
                        await _deactivateDeviceAdmin();
                      }
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                  SwitchListTile(
                    secondary: Icon(
                      Icons.admin_panel_settings_outlined,
                      color: _protectionStatus.ownerUninstallBlocked
                          ? FocusTokens.secondary
                          : FocusTokens.inkMuted,
                    ),
                    title: const Text(
                      'Android-managed uninstall block',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      !_protectionStatus.statusAvailable
                          ? 'Unable to verify Device Owner status.'
                          : _protectionStatus.deviceOwner
                              ? 'Device Owner mode — enforced by Android for this device.'
                              : _protectionStatus.profileOwner
                                  ? 'Profile Owner mode — applies only within the managed profile.'
                                  : 'Unavailable in a standard install. Requires legitimate Device Owner or Profile Owner provisioning.',
                      style: const TextStyle(
                          fontSize: 12, color: FocusTokens.inkMuted),
                    ),
                    value: _protectionStatus.ownerUninstallBlocked,
                    activeTrackColor: FocusTokens.secondary,
                    onChanged: !_protectionStatus.statusAvailable ||
                            !_protectionStatus.ownerMode ||
                            _isProcessing
                        ? null
                        : _toggleOwnerUninstallBlock,
                  ),
                  const Divider(height: 1, indent: 56),
                  SwitchListTile(
                    secondary: Icon(
                      Icons.security_rounded,
                      color: _isTamperProtectionEnabled
                          ? FocusTokens.secondary
                          : FocusTokens.inkMuted,
                    ),
                    title: const Text('Tamper Guard Protection',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      !_protectionStatus.statusAvailable
                          ? 'Unable to verify guard status.'
                          : !_isTamperProtectionEnabled
                              ? 'Optional, best-effort detection of Detox removal screens.'
                              : _protectionStatus.accessibilityServiceEnabled
                                  ? 'Best-effort screen detection. Android settings and force-stop paths can bypass it.'
                                  : 'Saved, but inactive until the Accessibility service is enabled again.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: FocusTokens.inkMuted,
                      ),
                    ),
                    value: _isTamperProtectionEnabled,
                    activeTrackColor: FocusTokens.secondary,
                    onChanged: _isProcessing ? null : _toggleTamperGuard,
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildStatusTile(
                    icon: Icons.battery_charging_full_rounded,
                    title: 'Battery Optimization Exemption',
                    subtitle: _isBatteryOptDisabled
                        ? 'Unrestricted — service won\'t be killed in background'
                        : 'Optimized — tap to exempt from battery saver',
                    isActive: _isBatteryOptDisabled,
                    actionText: _isBatteryOptDisabled ? 'Exempt' : 'Fix',
                    onTap: () => native.openBatteryOptimizationSettings(),
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildStatusTile(
                    icon: Icons.notifications_active_rounded,
                    title: 'Notification Permission',
                    subtitle: _areNotificationsEnabled
                        ? 'Allowed — displays active focus timers'
                        : 'Blocked — tap to enable notifications',
                    isActive: _areNotificationsEnabled,
                    actionText: _areNotificationsEnabled ? 'Allowed' : 'Enable',
                    onTap: () => native.openNotificationSettings(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),

            // ── 4. Uninstall App Section ───────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: FocusTokens.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: FocusTokens.danger.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.delete_forever_rounded,
                          color: FocusTokens.danger, size: 24),
                      SizedBox(width: 10),
                      Text(
                        'Uninstall Detox',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: FocusTokens.danger,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'The in-app flow asks your partner to authorize deactivation. Android controls whether the app can be removed; Device Admin alone is not an uninstall lock.',
                    style: TextStyle(
                        fontSize: 12, color: FocusTokens.inkMuted, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _handleUninstallApp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FocusTokens.danger,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _isProcessing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'Continue to Android uninstall',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isActive,
    required String actionText,
    required VoidCallback onTap,
  }) {
    final badgeColor = isActive ? FocusTokens.secondary : FocusTokens.danger;
    final badgeBg = isActive
        ? FocusTokens.secondarySoft
        : FocusTokens.danger.withValues(alpha: 0.12);

    return ListTile(
      leading: Icon(icon, color: badgeColor),
      title: Text(title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 12, color: FocusTokens.inkMuted)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: badgeBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          actionText,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: badgeColor),
        ),
      ),
      onTap: onTap,
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: FocusTokens.ink,
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: FocusTokens.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: FocusTokens.divider),
    );
  }
}
