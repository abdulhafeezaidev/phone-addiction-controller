import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/route_names.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/focus_tokens.dart';
import '../../../../domain/models/routine.dart';
import '../../../../services/native_bridge_service.dart';
import '../../../../widgets/admin_password_dialog.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> with WidgetsBindingObserver {
  int _selectedQuickDuration = 30; // default 30 minutes

  static const List<int> _quickDurations = [15, 25, 30, 45, 60, 90, 120];

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
      ref.invalidate(accessibilityEnabledProvider);
      ref.invalidate(focusSessionProvider);
    }
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  Future<void> _endSessionEarly() async {
    final authorized = await AdminPasswordDialog.show(
      context,
      actionDescription: 'end this focus session early',
    );
    if (!authorized) return;

    final native = ref.read(nativeBridgeServiceProvider);
    await native.stopSession();
    ref.invalidate(focusSessionProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Focus session ended by Admin.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openAdminSettings() async {
    final authorized = await AdminPasswordDialog.show(
      context,
      actionDescription: 'access Admin Settings & Uninstall Controls',
    );
    if (!authorized) return;

    if (mounted) {
      context.push(RouteNames.adminSettings);
    }
  }

  Future<void> _toggleRoutine(Routine routine, bool enable) async {
    // If disabling an active routine, require admin password to prevent bypass
    if (!enable) {
      final authorized = await AdminPasswordDialog.show(
        context,
        actionDescription: 'disable the scheduled routine "${routine.label}"',
      );
      if (!authorized) return;
    }

    await ref.read(routinesProvider.notifier).toggleRoutine(routine.id, enable);
  }

  Future<void> _deleteRoutine(Routine routine) async {
    final authorized = await AdminPasswordDialog.show(
      context,
      actionDescription: 'delete the routine "${routine.label}"',
    );
    if (!authorized) return;

    await ref.read(routinesProvider.notifier).deleteRoutine(routine.id);
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(focusSessionProvider);
    final adminSettingsAsync = ref.watch(adminSettingsProvider);
    final routinesAsync = ref.watch(routinesProvider);
    final accessibilityAsync = ref.watch(accessibilityEnabledProvider);

    final session = sessionAsync.valueOrNull ?? const FocusSessionInfo(isActive: false);
    final admin = adminSettingsAsync.valueOrNull;
    final isAccessibilityEnabled = accessibilityAsync.valueOrNull ?? true;
    final partnerName = admin?.adminName?.trim().isNotEmpty == true
        ? admin!.adminName!.trim()
        : 'Accountability Partner';

    return Scaffold(
      backgroundColor: FocusTokens.canvas,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: session.isActive ? FocusTokens.secondary : FocusTokens.primary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Detox',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: FocusTokens.ink,
              ),
            ),
          ],
        ),
        actions: [
          // Emergency Override icon
          IconButton(
            tooltip: 'Emergency Override',
            icon: const Icon(Icons.emergency_outlined, color: FocusTokens.warning),
            onPressed: () => context.push(RouteNames.emergencyOverride),
          ),
          // Settings & Admin Control (Password Protected)
          IconButton(
            tooltip: 'Settings & Admin Controls',
            icon: const Icon(Icons.settings_rounded, color: FocusTokens.ink),
            onPressed: _openAdminSettings,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(focusSessionProvider);
          ref.invalidate(routinesProvider);
          ref.invalidate(accessibilityEnabledProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Missing Accessibility Warning Banner ─────────────────────
              if (!isAccessibilityEnabled) ...[
                _buildAccessibilityAlertBanner(),
                const SizedBox(height: 16),
              ],

              // ── Active Session State Banner OR Inactive Hero ───────────────
              if (session.isActive)
                _buildActiveSessionView(session, partnerName)
              else
                _buildInactiveBeginFocusView(partnerName),

              const SizedBox(height: 28),

              // ── Routines List Section ─────────────────────────────────────
              _buildRoutinesSection(routinesAsync),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccessibilityAlertBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FocusTokens.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: FocusTokens.danger.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: FocusTokens.danger, size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Accessibility Service is Turned Off',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: FocusTokens.danger,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'App blocking cannot intercept distracting apps while Accessibility is off. Tap below to enable Detox in Android Settings.',
            style: TextStyle(fontSize: 12.5, color: FocusTokens.ink, height: 1.35),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ElevatedButton.icon(
              onPressed: () async {
                await ref.read(nativeBridgeServiceProvider).openAccessibilitySettings();
              },
              icon: const Icon(Icons.accessibility_new_rounded, size: 16),
              label: const Text(
                'Turn On Accessibility Now',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: FocusTokens.danger,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Active Focus Session Card ───────────────────────────────────────────────

  Widget _buildActiveSessionView(FocusSessionInfo session, String partnerName) {
    final remaining = session.remaining ?? Duration.zero;

    return Container(
      decoration: BoxDecoration(
        color: FocusTokens.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: FocusTokens.primary.withValues(alpha: 0.2)),
        boxShadow: FocusTokens.shadowLift,
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Status Pill Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: FocusTokens.secondarySoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_rounded, size: 14, color: FocusTokens.secondary),
                const SizedBox(width: 6),
                Text(
                  session.isScheduled ? 'Scheduled Routine Active' : 'Quick Focus Active',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: FocusTokens.secondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Live Timer Display
          Text(
            _formatDuration(remaining),
            style: const TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.0,
              fontFamily: FocusTokens.fontFamily,
              color: FocusTokens.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Remaining until ${session.endTime != null ? DateFormat.jm().format(session.endTime!) : "end"}',
            style: const TextStyle(fontSize: 13, color: FocusTokens.inkMuted),
          ),
          const SizedBox(height: 20),

          // Details row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildMetricChip(
                icon: Icons.block_rounded,
                label: '${session.blockedPackages.length} Blocked',
                color: FocusTokens.danger,
              ),
              _buildMetricChip(
                icon: Icons.verified_user_rounded,
                label: 'Guarded by $partnerName',
                color: FocusTokens.primary,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // End Early Button (Requires Admin Password)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _endSessionEarly,
              icon: const Icon(Icons.lock_open_rounded, size: 18, color: FocusTokens.danger),
              label: const Text(
                'End Focus Early (Admin Password)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: FocusTokens.danger,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: FocusTokens.danger),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: FocusTokens.elevated,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: FocusTokens.ink,
            ),
          ),
        ],
      ),
    );
  }

  // ── Inactive Focus View: Begin Focus Options ────────────────────────────────

  Widget _buildInactiveBeginFocusView(String partnerName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Headline
        const Text(
          'Begin Focus',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: FocusTokens.ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Select your focus mode to lock distracting apps under $partnerName\'s guard.',
          style: const TextStyle(
            fontSize: 14,
            color: FocusTokens.inkMuted,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),

        // Option 1: Quick Focus Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: FocusTokens.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: FocusTokens.divider),
            boxShadow: FocusTokens.shadowSoft,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: FocusTokens.primarySoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.bolt_rounded,
                      color: FocusTokens.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quick Focus',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: FocusTokens.ink,
                          ),
                        ),
                        Text(
                          'One-tap timed distraction lock',
                          style: TextStyle(fontSize: 12, color: FocusTokens.inkMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Duration selector pills
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _quickDurations.map((d) {
                    final isSelected = _selectedQuickDuration == d;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text('${d}m'),
                        selected: isSelected,
                        selectedColor: FocusTokens.primary,
                        backgroundColor: FocusTokens.elevated,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : FocusTokens.ink,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        side: BorderSide.none,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _selectedQuickDuration = d),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),

              // Button to proceed to app selection
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () {
                    context.push(
                      '${RouteNames.appSelection}?mode=quick&duration=$_selectedQuickDuration',
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FocusTokens.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Choose Apps & Lock ($_selectedQuickDuration min)',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Option 2: Routine Set Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: FocusTokens.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: FocusTokens.divider),
            boxShadow: FocusTokens.shadowSoft,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: FocusTokens.secondarySoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.calendar_today_rounded,
                      color: FocusTokens.secondary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Routine Set',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: FocusTokens.ink,
                          ),
                        ),
                        Text(
                          'Automated recurring focus schedule',
                          style: TextStyle(fontSize: 12, color: FocusTokens.inkMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Schedule recurring focus hours (e.g. Work 9 AM – 5 PM, or Sleep 11 PM – 7 AM).',
                style: TextStyle(fontSize: 13, color: FocusTokens.inkMuted, height: 1.35),
              ),
              const SizedBox(height: 16),

              // Button to proceed to app selection in routine mode
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: () {
                    context.push('${RouteNames.appSelection}?mode=routine');
                  },
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text(
                    'Configure New Routine',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: FocusTokens.secondary,
                    side: const BorderSide(color: FocusTokens.secondary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Routines Section ────────────────────────────────────────────────────────

  Widget _buildRoutinesSection(AsyncValue<List<Routine>> routinesAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Scheduled Routines',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: FocusTokens.ink,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded, color: FocusTokens.primary),
              onPressed: () {
                context.push('${RouteNames.appSelection}?mode=routine');
              },
            ),
          ],
        ),
        const SizedBox(height: 8),

        routinesAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (err, _) => Text(
            'Failed to load routines: $err',
            style: const TextStyle(color: FocusTokens.danger),
          ),
          data: (routines) {
            if (routines.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: FocusTokens.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: FocusTokens.divider),
                ),
                child: const Text(
                  'No routines scheduled yet.\nTap "Configure New Routine" above to create one.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: FocusTokens.inkMuted, fontSize: 13, height: 1.4),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: routines.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final routine = routines[index];
                return _buildRoutineCard(routine);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildRoutineCard(Routine routine) {
    final startStr = DateFormat.jm().format(routine.startTime);
    final endStr = DateFormat.jm().format(routine.endTime);
    final daysStr = _formatWeekdays(routine.weekdays);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FocusTokens.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: routine.enabled ? FocusTokens.secondary.withValues(alpha: 0.3) : FocusTokens.divider,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: routine.enabled ? FocusTokens.secondarySoft : FocusTokens.elevated,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.schedule_rounded,
              color: routine.enabled ? FocusTokens.secondary : FocusTokens.inkMuted,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  routine.label.isNotEmpty ? routine.label : 'Routine',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: FocusTokens.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$startStr – $endStr',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: FocusTokens.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  daysStr,
                  style: const TextStyle(
                    fontSize: 12,
                    color: FocusTokens.inkMuted,
                  ),
                ),
              ],
            ),
          ),

          // Routine Toggle Switch
          Switch(
            value: routine.enabled,
            activeTrackColor: FocusTokens.secondary,
            onChanged: (val) => _toggleRoutine(routine, val),
          ),

          // Delete routine
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 20, color: FocusTokens.inkMuted),
            onPressed: () => _deleteRoutine(routine),
          ),
        ],
      ),
    );
  }

  String _formatWeekdays(List<int> weekdays) {
    if (weekdays.length == 7) return 'Every day';
    if (weekdays.length == 5 &&
        weekdays.contains(0) &&
        weekdays.contains(1) &&
        weekdays.contains(2) &&
        weekdays.contains(3) &&
        weekdays.contains(4)) {
      return 'Weekdays (Mon–Fri)';
    }
    if (weekdays.length == 2 && weekdays.contains(5) && weekdays.contains(6)) {
      return 'Weekends (Sat–Sun)';
    }

    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final sorted = List<int>.from(weekdays)..sort();
    return sorted.map((d) => names[d]).join(', ');
  }
}
