import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/route_names.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/focus_tokens.dart';

class SetupPage extends ConsumerStatefulWidget {
  const SetupPage({super.key});

  @override
  ConsumerState<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends ConsumerState<SetupPage>
    with WidgetsBindingObserver {
  final _pageController = PageController();
  int _currentStep = 0;

  // Step 1: System Permissions State (Implement Phase)
  bool _isAccessibilityGranted = false;
  bool _isDeviceAdminActive = false;
  bool _isDeviceAdminSupported = false;
  bool _isBatteryOptimizationDisabled = false;
  bool _areNotificationsGranted = false;
  bool _isCheckingPermissions = false;

  // Step 2: Accountability Partner & Password
  final _partnerNameController = TextEditingController();
  final _partnerContactController = TextEditingController();
  final _adminPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  // Step 3: Emergency Override Protocol
  final _customQuestionController = TextEditingController();
  final _answerController = TextEditingController();
  String _selectedQuestion = 'What is the name of your childhood best friend?';
  int _reflectionMinutes = 15;
  int _overrideHours = 24;
  int _cooldownHours = 24;

  final List<String> _presetQuestions = [
    'What is the name of your childhood best friend?',
    'What was the name of your first school?',
    'What city were your parents born in?',
    'What was the make of your first car?',
    'Custom Question...',
  ];

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAllPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _partnerNameController.dispose();
    _partnerContactController.dispose();
    _adminPasswordController.dispose();
    _confirmPasswordController.dispose();
    _customQuestionController.dispose();
    _answerController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAllPermissions();
    }
  }

  Future<void> _checkAllPermissions() async {
    setState(() => _isCheckingPermissions = true);
    final native = ref.read(nativeBridgeServiceProvider);

    final accessibility = await native.isServiceEnabled();
    final protection = await native.getProtectionState();
    final battery = await native.isBatteryOptimizationDisabled();
    final notifications = await native.areNotificationsEnabled();

    if (mounted) {
      setState(() {
        _isAccessibilityGranted = accessibility;
        _isDeviceAdminActive = protection.deviceAdminActive;
        _isDeviceAdminSupported = protection.deviceAdminSupported;
        _isBatteryOptimizationDisabled = battery;
        _areNotificationsGranted = notifications;
        _isCheckingPermissions = false;
      });
    }
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (!_isAccessibilityGranted) {
        _showToast(
            'Please enable the Accessibility Service first so app blocking can work.');
        return;
      }
    } else if (_currentStep == 1) {
      final name = _partnerNameController.text.trim();
      final pass = _adminPasswordController.text;
      final confirm = _confirmPasswordController.text;

      if (name.isEmpty) {
        _showToast('Please enter your accountability partner\'s name');
        return;
      }
      if (pass.isEmpty || pass.length < 4) {
        _showToast('Password must be at least 4 characters');
        return;
      }
      if (pass != confirm) {
        _showToast('Passwords do not match');
        return;
      }
    }

    if (_currentStep < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
      );
      setState(() => _currentStep++);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
      );
      setState(() => _currentStep--);
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _completeSetup() async {
    final question = _selectedQuestion == 'Custom Question...'
        ? _customQuestionController.text.trim()
        : _selectedQuestion;
    final answer = _answerController.text.trim();

    if (question.isEmpty) {
      _showToast('Please provide an emergency question');
      return;
    }
    if (answer.isEmpty || answer.length < 2) {
      _showToast('Please provide an answer with at least 2 characters');
      return;
    }

    // Re-verify permissions one final time
    await _checkAllPermissions();
    if (!_isAccessibilityGranted) {
      _showToast('Accessibility Service is required to enforce app blocking.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final passwordService = ref.read(passwordServiceProvider);
      final emergencyService = ref.read(emergencyOverrideServiceProvider);
      final storage = ref.read(storageServiceProvider);

      final adminName = _partnerNameController.text.trim();
      final adminContact = _partnerContactController.text.trim();
      final adminPassword = _adminPasswordController.text;

      // 1. Save Admin Partner & Password
      await passwordService.saveAdminConfig(
        password: adminPassword,
        adminName: adminName,
        adminContact: adminContact.isNotEmpty ? adminContact : null,
        recoveryChallenge: question,
        recoveryAnswer: answer,
      );

      // 2. Save Emergency Override Question & Protocol Durations
      await emergencyService.setRecoveryChallenge(question, answer);
      await emergencyService.updateProtocolSettings(
        reflectionMinutes: _reflectionMinutes,
        overrideHours: _overrideHours,
        cooldownHours: _cooldownHours,
      );

      // Protection layers remain optional and are enabled explicitly in Settings.
      // 3. Mark onboarding complete.
      await storage.put(
        AppConstants.settingsBox,
        AppConstants.onboardingCompletedKey,
        true,
      );

      // 4. Invalidate providers so cache updates.
      ref.invalidate(adminSettingsProvider);
      ref.invalidate(protectionStateProvider);
      ref.invalidate(accessibilityEnabledProvider);

      if (mounted) {
        context.go(RouteNames.home);
      }
    } catch (e) {
      _showToast('Failed to save setup: $e');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FocusTokens.canvas,
      appBar: AppBar(
        title: const Text(
          'Detox Setup',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: FocusTokens.ink,
          ),
        ),
        centerTitle: true,
        leading: _currentStep > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: _prevStep,
              )
            : null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress Indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                children: List.generate(3, (index) {
                  final isActive = index <= _currentStep;
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: EdgeInsets.only(right: index < 2 ? 8 : 0),
                      decoration: BoxDecoration(
                        color: isActive
                            ? FocusTokens.primary
                            : FocusTokens.elevated,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // Step Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildPermissionsStep(),
                  _buildPartnerStep(),
                  _buildEmergencyQuestionStep(),
                ],
              ),
            ),

            // Bottom Navigation Controls
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting
                      ? null
                      : (_currentStep == 2 ? _completeSetup : _nextStep),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FocusTokens.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: FocusTokens.borderRadiusButton,
                    ),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _currentStep == 0
                              ? (_isAccessibilityGranted
                                  ? 'Continue to Admin Setup'
                                  : 'Enable Accessibility First')
                              : (_currentStep == 2
                                  ? 'Complete Setup'
                                  : 'Continue'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 1: Accountability Partner ──────────────────────────────────────────

  Widget _buildPartnerStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: FocusTokens.primarySoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.people_alt_rounded,
                    color: FocusTokens.primary, size: 28),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Accountability Partner Model',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: FocusTokens.ink,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'True willpower requires external commitment. Choose a partner (friend, spouse, mentor) who will set and hold the password so you cannot impulsively bypass your focus.',
                        style: TextStyle(
                          fontSize: 13,
                          color: FocusTokens.inkMuted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Partner Name
          const Text(
            'Partner Name *',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: FocusTokens.ink),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _partnerNameController,
            textCapitalization: TextCapitalization.words,
            decoration: _inputDecoration(
                'e.g. Sarah, Alex, Mom', Icons.person_outline_rounded),
          ),
          const SizedBox(height: 16),

          // Partner Note (local-only, no PII collection)
          const Text(
            'Partner Reminder Note (Optional)',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: FocusTokens.ink),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _partnerContactController,
            keyboardType: TextInputType.text,
            decoration: _inputDecoration(
                'Optional local note (stored on this device only)',
                Icons.sticky_note_2_outlined),
          ),
          const SizedBox(height: 20),

          // Admin Password
          const Text(
            'Admin Master Password *',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: FocusTokens.ink),
          ),
          const SizedBox(height: 4),
          const Text(
            'Ask your partner to enter a secret password only they know.',
            style: TextStyle(fontSize: 12, color: FocusTokens.inkMuted),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _adminPasswordController,
            obscureText: _obscurePassword,
            decoration: _inputDecoration(
                    'Enter secure password', Icons.lock_outline_rounded)
                .copyWith(
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Confirm Password
          const Text(
            'Confirm Password *',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: FocusTokens.ink),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirm,
            decoration: _inputDecoration(
                    'Confirm secure password', Icons.lock_clock_outlined)
                .copyWith(
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirm
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined),
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 2: Emergency Security Question ─────────────────────────────────────

  Widget _buildEmergencyQuestionStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: FocusTokens.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.emergency_rounded,
                    color: FocusTokens.warning, size: 28),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Emergency Override Protection',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: FocusTokens.ink,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'If your accountability partner is unavailable and an urgent real-world emergency happens, you can answer this question to activate a 15-minute reflection override.',
                        style: TextStyle(
                          fontSize: 13,
                          color: FocusTokens.inkMuted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            'Security Question',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: FocusTokens.ink),
          ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: FocusTokens.elevated,
              borderRadius: BorderRadius.circular(14),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _selectedQuestion,
                icon: const Icon(Icons.arrow_drop_down_rounded,
                    color: FocusTokens.inkMuted),
                items: _presetQuestions.map((q) {
                  return DropdownMenuItem(
                    value: q,
                    child: Text(
                      q,
                      style:
                          const TextStyle(fontSize: 13, color: FocusTokens.ink),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedQuestion = val);
                },
              ),
            ),
          ),

          if (_selectedQuestion == 'Custom Question...') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _customQuestionController,
              decoration: _inputDecoration(
                  'Type your custom question', Icons.help_outline_rounded),
            ),
          ],

          const SizedBox(height: 20),
          const Text(
            'Your Secret Answer *',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: FocusTokens.ink),
          ),
          const SizedBox(height: 4),
          const Text(
            'Answers are stored securely as a one-way cryptographic hash.',
            style: TextStyle(fontSize: 12, color: FocusTokens.inkMuted),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _answerController,
            decoration:
                _inputDecoration('Enter your answer', Icons.key_rounded),
          ),
          const SizedBox(height: 24),

          // Protocol Durations Configuration
          const Text(
            'Override Protocol Parameters',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: FocusTokens.ink),
          ),
          const SizedBox(height: 4),
          const Text(
            'Configure the reflection buffer, unlock window, and cooldown before another emergency request.',
            style: TextStyle(fontSize: 12, color: FocusTokens.inkMuted),
          ),
          const SizedBox(height: 12),

          _buildProtocolSelectorRow(
            label: 'Reflection Delay',
            subtitle: 'Wait time after answering before unlock',
            valueLabel: '$_reflectionMinutes mins',
            options: const [5, 10, 15, 30, 60],
            selectedValue: _reflectionMinutes,
            unitSuffix: 'm',
            onSelect: (val) => setState(() => _reflectionMinutes = val),
          ),
          const SizedBox(height: 10),
          _buildProtocolSelectorRow(
            label: 'Override Access Window',
            subtitle: 'Duration apps remain unlocked',
            valueLabel: '$_overrideHours hrs',
            options: const [1, 3, 6, 12, 24],
            selectedValue: _overrideHours,
            unitSuffix: 'h',
            onSelect: (val) => setState(() => _overrideHours = val),
          ),
          const SizedBox(height: 10),
          _buildProtocolSelectorRow(
            label: 'Cooldown Period',
            subtitle: 'Wait time before next emergency override',
            valueLabel: '$_cooldownHours hrs',
            options: const [6, 12, 24, 48, 72],
            selectedValue: _cooldownHours,
            unitSuffix: 'h',
            onSelect: (val) => setState(() => _cooldownHours = val),
          ),
        ],
      ),
    );
  }

  Widget _buildProtocolSelectorRow({
    required String label,
    required String subtitle,
    required String valueLabel,
    required List<int> options,
    required int selectedValue,
    required String unitSuffix,
    required ValueChanged<int> onSelect,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FocusTokens.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FocusTokens.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: FocusTokens.ink),
              ),
              Text(
                valueLabel,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: FocusTokens.primary),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: FocusTokens.inkMuted),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: options.map((opt) {
                final isSelected = opt == selectedValue;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text('$opt$unitSuffix'),
                    selected: isSelected,
                    selectedColor: FocusTokens.primary,
                    backgroundColor: FocusTokens.elevated,
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : FocusTokens.ink,
                    ),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    side: BorderSide.none,
                    showCheckmark: false,
                    onSelected: (_) => onSelect(opt),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 1: System Implementation & Permissions ─────────────────────────────

  Widget _buildPermissionsStep() {
    final native = ref.read(nativeBridgeServiceProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Guided Banner for Accessibility Implementation Phase
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isAccessibilityGranted
                  ? FocusTokens.secondarySoft
                  : FocusTokens.primarySoft,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isAccessibilityGranted
                    ? FocusTokens.secondary.withValues(alpha: 0.3)
                    : FocusTokens.primary.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _isAccessibilityGranted
                      ? Icons.verified_rounded
                      : Icons.settings_accessibility_rounded,
                  color: _isAccessibilityGranted
                      ? FocusTokens.secondary
                      : FocusTokens.primary,
                  size: 28,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isAccessibilityGranted
                            ? 'System Protection Ready'
                            : 'Step 1: System Implementation Phase',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: FocusTokens.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isAccessibilityGranted
                            ? 'Accessibility Service is active! App blocking will work automatically. You can also enable the recommended protections below.'
                            : 'For app blocking to work, Android requires you to turn on Detox in Accessibility Settings:\n1. Tap "Open Accessibility Settings" below\n2. Select "Installed apps" → "Detox"\n3. Toggle the switch ON and return here.',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: FocusTokens.inkMuted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'System Permissions',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: FocusTokens.ink,
                ),
              ),
              if (_isCheckingPermissions)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                TextButton.icon(
                  onPressed: _checkAllPermissions,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Refresh Status',
                      style: TextStyle(fontSize: 13)),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // 1. Accessibility Service
          _buildPermissionTile(
            title: 'Accessibility Service (Required)',
            subtitle:
                'Detects launched apps in real-time to enforce focus blocks and overlay shields.',
            icon: Icons.accessibility_new_rounded,
            isGranted: _isAccessibilityGranted,
            actionLabel: 'Open Accessibility Settings',
            onTap: () async {
              await native.openAccessibilitySettings();
            },
          ),
          const SizedBox(height: 12),

          // 2. Optional Device Admin uninstall deterrent
          _buildPermissionTile(
            title: 'Optional Device Admin',
            subtitle: !_isDeviceAdminSupported
                ? 'Device Admin is not supported on this Android device.'
                : 'Android requires deactivation before uninstall. This is a deterrent, not a lock; you can enable it later in Settings.',
            icon: Icons.shield_rounded,
            isGranted: _isDeviceAdminActive,
            actionLabel: !_isDeviceAdminSupported
                ? 'Not supported'
                : _isDeviceAdminActive
                    ? 'Active'
                    : 'Enable (Optional)',
            onTap: () async {
              if (!_isDeviceAdminActive && _isDeviceAdminSupported) {
                try {
                  await native.requestDeviceAdmin();
                } catch (e) {
                  if (mounted) {
                    _showToast('Could not open Android admin settings: $e');
                  }
                }
              }
            },
          ),
          const SizedBox(height: 12),

          // 3. Battery Optimization
          _buildPermissionTile(
            title: 'Battery Optimization Exemption',
            subtitle:
                'Ensures the focus background service is not killed by Android memory cleaner.',
            icon: Icons.battery_charging_full_rounded,
            isGranted: _isBatteryOptimizationDisabled,
            actionLabel: 'Disable Optimization',
            onTap: () async {
              await native.openBatteryOptimizationSettings();
            },
          ),
          const SizedBox(height: 12),

          // 4. Notifications
          _buildPermissionTile(
            title: 'Notification Access',
            subtitle:
                'Displays current focus session timer and routine statuses in the notification shade.',
            icon: Icons.notifications_active_rounded,
            isGranted: _areNotificationsGranted,
            actionLabel: 'Allow Notifications',
            onTap: () async {
              await native.openNotificationSettings();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isGranted,
    required String actionLabel,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FocusTokens.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGranted
              ? FocusTokens.secondary.withValues(alpha: 0.3)
              : FocusTokens.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isGranted
                      ? FocusTokens.secondarySoft
                      : FocusTokens.elevated,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color:
                      isGranted ? FocusTokens.secondary : FocusTokens.inkMuted,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: FocusTokens.ink,
                  ),
                ),
              ),
              Icon(
                isGranted
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: isGranted ? FocusTokens.secondary : FocusTokens.inkMuted,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: FocusTokens.inkMuted,
              height: 1.35,
            ),
          ),
          if (!isGranted) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onTap,
                style: TextButton.styleFrom(
                  backgroundColor: FocusTokens.elevated,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  actionLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: FocusTokens.primary,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData prefixIcon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: FocusTokens.inkMuted, fontSize: 13),
      filled: true,
      fillColor: FocusTokens.elevated,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      prefixIcon: Icon(prefixIcon, color: FocusTokens.inkMuted, size: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: FocusTokens.primary, width: 1.5),
      ),
    );
  }
}
