import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/route_names.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/services/soundscape_service.dart';
import '../../../../core/theme/focus_tokens.dart';
import '../../../../domain/models/routine.dart';
import '../../../../services/native_bridge_service.dart';
import '../../../../widgets/admin_password_dialog.dart';
import '../widgets/lumi_mascot.dart';
import '../widgets/soundscape_sheet.dart';

class BloomlyHomePage extends ConsumerStatefulWidget {
  const BloomlyHomePage({super.key});

  @override
  ConsumerState<BloomlyHomePage> createState() => _BloomlyHomePageState();
}

class _BloomlyHomePageState extends ConsumerState<BloomlyHomePage>
    with WidgetsBindingObserver {
  static const _focusGoalMinutes = 120;
  static const _seedKey = 'bloomly_seeds';
  static const _pointsKey = 'bloomly_mindful_points';
  static const _focusMinutesKey = 'bloomly_focus_minutes';
  static const _progressDayKey = 'bloomly_progress_day';
  static const _shieldsKey = 'bloomly_shields';
  static const _shieldWeekKey = 'bloomly_shield_week';
  static const List<int> _quickDurations = [15, 25, 30, 45, 60, 90, 120];

  int _tab = 0;
  int _seeds = 0;
  int _mindfulPoints = 0;
  int _focusMinutes = 0;
  int _shields = 2;
  int _breathSeconds = 5;
  int _selectedFocusMinutes = 25;
  bool? _wasSessionActive;
  DateTime? _expectedSessionEnd;
  int _expectedSessionMinutes = 25;
  Timer? _breathTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadProgress();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _breathTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(accessibilityEnabledProvider);
      ref.invalidate(focusSessionProvider);
      ref.invalidate(protectionStateProvider);
      ref.invalidate(routinesProvider);
    }
  }

  Future<void> _loadProgress() async {
    final storage = ref.read(storageServiceProvider);
    final week = _currentWeek();
    final savedWeek =
        storage.get<String>(AppConstants.settingsBox, _shieldWeekKey);
    final isSameDay =
        storage.get<String>(AppConstants.settingsBox, _progressDayKey) ==
            _currentDay();
    final savedShields = savedWeek == week
        ? storage.get<int>(AppConstants.settingsBox, _shieldsKey,
                defaultValue: 2) ??
            2
        : 2;
    if (!mounted) return;
    setState(() {
      _seeds = storage.get<int>(AppConstants.settingsBox, _seedKey,
              defaultValue: 0) ??
          0;
      _mindfulPoints = isSameDay
          ? storage.get<int>(AppConstants.settingsBox, _pointsKey,
                  defaultValue: 0) ??
              0
          : 0;
      _focusMinutes = isSameDay
          ? storage.get<int>(AppConstants.settingsBox, _focusMinutesKey,
                  defaultValue: 0) ??
              0
          : 0;
      _shields = savedShields.clamp(0, 2).toInt();
    });
    if (!isSameDay) {
      await storage.put(AppConstants.settingsBox, _pointsKey, 0);
      await storage.put(AppConstants.settingsBox, _focusMinutesKey, 0);
      await storage.put(
          AppConstants.settingsBox, _progressDayKey, _currentDay());
    }
    if (savedWeek != week) {
      await storage.put(AppConstants.settingsBox, _shieldWeekKey, week);
      await storage.put(AppConstants.settingsBox, _shieldsKey, 2);
    }
  }

  String _currentWeek() {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, 1, 1);
    final week =
        ((now.difference(firstDay).inDays + firstDay.weekday - 1) ~/ 7) + 1;
    return '${now.year}-$week';
  }

  String _currentDay() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _saveProgress() async {
    final storage = ref.read(storageServiceProvider);
    await Future.wait([
      storage.put(AppConstants.settingsBox, _seedKey, _seeds),
      storage.put(AppConstants.settingsBox, _pointsKey, _mindfulPoints),
      storage.put(AppConstants.settingsBox, _focusMinutesKey, _focusMinutes),
      storage.put(AppConstants.settingsBox, _progressDayKey, _currentDay()),
      storage.put(AppConstants.settingsBox, _shieldsKey, _shields),
      storage.put(AppConstants.settingsBox, _shieldWeekKey, _currentWeek()),
    ]);
  }

  void _selectTab(int tab) {
    _breathTimer?.cancel();
    setState(() {
      _tab = tab;
      _breathSeconds = 5;
    });
    if (tab == 1) _startBreathingPause();
    _narrateTab(tab);
  }

  void _startBreathingPause() {
    _breathTimer?.cancel();
    _breathTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _tab != 1) {
        timer.cancel();
      } else if (_breathSeconds > 0) {
        setState(() => _breathSeconds--);
        if (_breathSeconds == 0) {
          HapticFeedback.selectionClick();
          ref.read(soundscapeProvider.notifier).playDewdrop();
        }
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _putPhoneDown() async {
    setState(() => _mindfulPoints += 5);
    await _saveProgress();
    HapticFeedback.lightImpact();
    ref.read(soundscapeProvider.notifier).playDewdrop();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('A kind choice for yourself. +5 mindful points'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _startFocus(int minutes) async {
    await context
        .push('${RouteNames.appSelection}?mode=quick&duration=$minutes');
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
          content: Text('Focus session ended with partner authorization.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _toggleRoutine(Routine routine, bool enable) async {
    if (!enable) {
      final authorized = await AdminPasswordDialog.show(
        context,
        actionDescription:
            'disable the scheduled routine "${routine.label.isNotEmpty ? routine.label : 'Routine'}"',
      );
      if (!authorized) return;
    }

    await ref.read(routinesProvider.notifier).toggleRoutine(routine.id, enable);
  }

  Future<void> _deleteRoutine(Routine routine) async {
    final authorized = await AdminPasswordDialog.show(
      context,
      actionDescription:
          'delete the routine "${routine.label.isNotEmpty ? routine.label : 'Routine'}"',
    );
    if (!authorized) return;

    await ref.read(routinesProvider.notifier).deleteRoutine(routine.id);
  }

  void _observeSession(FocusSessionInfo session) {
    if (_wasSessionActive == null) {
      _wasSessionActive = session.isActive;
      if (session.isActive) _recordSession(session);
      return;
    }

    if (session.isActive) {
      _recordSession(session);
    } else if (_wasSessionActive == true) {
      final expectedEnd = _expectedSessionEnd;
      if (expectedEnd != null &&
          DateTime.now()
              .isAfter(expectedEnd.subtract(const Duration(seconds: 2)))) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _celebrateFocus());
      }
      _expectedSessionEnd = null;
    }
    _wasSessionActive = session.isActive;
  }

  void _recordSession(FocusSessionInfo session) {
    _expectedSessionEnd = session.endTime;
    final start = session.startTime;
    final end = session.endTime;
    if (start != null && end != null) {
      _expectedSessionMinutes = end.difference(start).inMinutes.clamp(1, 240);
    }
  }

  Future<void> _celebrateFocus() async {
    if (!mounted) return;
    setState(() {
      _focusMinutes += _expectedSessionMinutes;
      _seeds += 20;
      _tab = 4;
    });
    await _saveProgress();
    HapticFeedback.mediumImpact();
    ref.read(soundscapeProvider.notifier).playCelebrationBell();
    ref.read(soundscapeProvider.notifier).speakLumi(
        'You did it! A beautiful pocket of presence, made by you.');
  }

  Future<void> _useShield() async {
    if (_shields == 0) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: FocusTokens.surface,
        title: const Text('Take a gentle day?'),
        content: const Text(
          'Use one Seedling Shield as a reminder that rest and busy days are welcome here.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Use a shield'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    setState(() => _shields--);
    await _saveProgress();
    ref.read(soundscapeProvider.notifier).playSingingBowl();
    ref.read(soundscapeProvider.notifier).speakLumi(
        'Life happens, and that is 100% okay! We are learning our rhythm. No guilt here.');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Your shield is here when life gets full. No streak to lose.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(focusSessionProvider).valueOrNull;
    final soundState = ref.watch(soundscapeProvider);
    if (session != null) _observeSession(session);

    return Scaffold(
      backgroundColor: FocusTokens.canvas,
      appBar: AppBar(
        backgroundColor: FocusTokens.canvas,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 22,
        title: Row(
          children: [
            const Icon(Icons.spa_rounded, color: FocusTokens.primary, size: 25),
            const SizedBox(width: 8),
            Text(
              'Detox',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: FocusTokens.ink,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Emergency Override',
            onPressed: () => context.push(RouteNames.emergencyOverride),
            icon: const Icon(
              Icons.emergency_outlined,
              color: FocusTokens.warning,
            ),
          ),
          IconButton(
            tooltip: 'Sanctuary Audio & Voices',
            onPressed: () => SoundscapeSheet.show(context),
            icon: Icon(
              soundState.isVoiceEnabled || soundState.isSoundscapeEnabled
                  ? Icons.graphic_eq_rounded
                  : Icons.volume_off_rounded,
              color: FocusTokens.primary,
            ),
          ),
          IconButton(
            tooltip: 'Protection and settings',
            onPressed: () => context.push(RouteNames.adminSettings),
            icon: const Icon(Icons.tune_rounded, color: FocusTokens.primary),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _tab == 4
            ? _celebration()
            : IndexedStack(
                index: _tab,
                children: [
                  _oasis(session),
                  _mindfulPause(),
                  _focus(session),
                  _garden(),
                ],
              ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab == 4 ? 0 : _tab,
        onDestinationSelected: _selectTab,
        backgroundColor: FocusTokens.surface,
        indicatorColor: FocusTokens.primarySoft,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.local_florist_outlined),
            selectedIcon: Icon(Icons.local_florist_rounded),
            label: 'Oasis',
          ),
          NavigationDestination(icon: Icon(Icons.air_rounded), label: 'Pause'),
          NavigationDestination(
            icon: Icon(Icons.self_improvement_outlined),
            selectedIcon: Icon(Icons.self_improvement_rounded),
            label: 'Focus',
          ),
          NavigationDestination(
            icon: Icon(Icons.yard_outlined),
            selectedIcon: Icon(Icons.yard_rounded),
            label: 'Garden',
          ),
        ],
      ),
    );
  }

  Widget _oasis(FocusSessionInfo? session) {
    final progress = (_focusMinutes / _focusGoalMinutes).clamp(0.0, 1.0);
    final isAccessibilityEnabled =
        ref.watch(accessibilityEnabledProvider).valueOrNull ?? true;
    final active = session?.isActive == true;

    return _page(
      children: [
        if (!isAccessibilityEnabled) ...[
          _buildAccessibilityWarningCard(),
          const SizedBox(height: 14),
        ],
        const _Eyebrow('A LITTLE ROOM TO BREATHE'),
        const SizedBox(height: 8),
        Text('Good ${_greeting()},', style: _headingStyle(31)),
        Text('you’re growing at your own pace.', style: _bodyStyle()),
        const SizedBox(height: 14),
        _lumiHero(
          mood: active
              ? 'zen_focus'
              : (_isNightTime() ? 'sleeping' : 'idle_happy'),
          message: active
              ? 'You’re showing up for this moment. I’m right here.'
              : (_isNightTime()
                  ? 'Shh... stars are out. It’s time to let your eyes rest and recharge.'
                  : 'Hello! I’m Lumi, your pocket guide to calmer tech habits. How can I support you today?'),
          subtext: active
              ? 'Lumi is keeping you company · Focus mode active'
              : (_isNightTime()
                  ? 'Night wind down active · Sleep and rest are part of growing'
                  : 'Tap Lumi to hear them speak · Pet for affection'),
          size: LumiSize.hero,
        ),
        const SizedBox(height: 16),
        _card(
          child: Row(
            children: [
              SizedBox(
                width: 104,
                height: 104,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 10,
                        strokeCap: StrokeCap.round,
                        backgroundColor: const Color(0xFFDCFCE7),
                        valueColor:
                            const AlwaysStoppedAnimation(FocusTokens.primary),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$_focusMinutes',
                          style: const TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w800,
                            color: FocusTokens.ink,
                          ),
                        ),
                        const Text(
                          'minutes',
                          style: TextStyle(
                              fontSize: 11, color: FocusTokens.inkMuted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Your mindful time',
                        style: FocusTokens.sectionTitle),
                    const SizedBox(height: 5),
                    Text(
                        '$_focusMinutes of $_focusGoalMinutes focus minutes today',
                        style: FocusTokens.bodyMedium),
                    const SizedBox(height: 8),
                    const Text('Every small moment counts.',
                        style: FocusTokens.caption),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _primaryButton(
          icon: Icons.spa_rounded,
          label: active
              ? 'Focus session in progress'
              : 'Start 25m Calmer Focus',
          onPressed: active ? null : () => _startFocus(25),
        ),
        if (active) ...[
          const SizedBox(height: 10),
          _buildActiveSessionControls(),
        ],
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
                child: _statCard(
                    Icons.auto_awesome_rounded, '$_seeds', 'sprout seeds')),
            const SizedBox(width: 10),
            Expanded(
                child: _statCard(Icons.favorite_rounded, '$_mindfulPoints',
                    'mindful points')),
          ],
        ),
        const SizedBox(height: 20),
        _card(
          color: const Color(0xFFFFF1E3),
          child: const Row(
            children: [
              Icon(Icons.spa_rounded, color: Color(0xFFB45309)),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Your choices are yours. Rest is part of growing.',
                  style: TextStyle(
                      color: FocusTokens.ink, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAccessibilityWarningCard() {
    return _card(
      color: const Color(0xFFFEF2F2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: FocusTokens.danger, size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Accessibility Service is off',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: FocusTokens.danger,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Enable Detox in Android Accessibility Settings so selected apps can be gently paused during focus sessions.',
            style: TextStyle(
              fontSize: 12.5,
              color: FocusTokens.ink,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: FilledButton.icon(
              onPressed: () {
                ref.read(nativeBridgeServiceProvider).openAccessibilitySettings();
              },
              icon: const Icon(Icons.accessibility_new_rounded, size: 16),
              label: const Text('Enable in Accessibility Settings'),
              style: FilledButton.styleFrom(
                backgroundColor: FocusTokens.danger,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSessionControls() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _endSessionEarly,
            icon: const Icon(Icons.lock_open_rounded, size: 16),
            label: const Text(
              'End Early (PIN)',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: FocusTokens.ink,
              side: const BorderSide(color: Color(0xFFE7DFD5)),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => context.push(RouteNames.emergencyOverride),
            icon: const Icon(Icons.emergency_outlined, size: 16),
            label: const Text(
              'Emergency Access',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: FocusTokens.warning,
              side: BorderSide(color: FocusTokens.warning.withValues(alpha: 0.45)),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _mindfulPause() => _page(
        children: [
          const _Eyebrow('A MINDFUL MOMENT'),
          const SizedBox(height: 8),
          Text('Before you open an app…', style: _headingStyle(29)),
          Text(
            'There’s no wrong choice. Notice what you need, with kindness.',
            style: _bodyStyle(),
          ),
          const SizedBox(height: 12),
          _lumiHero(
            mood: 'gentle_nudge',
            message: 'What is your heart hoping to find right now?',
            subtext: 'Mindful 5-second breath pause · Zero shame, 100% autonomy',
            size: LumiSize.md,
          ),
          const SizedBox(height: 16),
          Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 800),
              width: 188,
              height: 188,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFDCFCE7),
                border: Border.all(color: const Color(0xFF86EFAC), width: 4),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x2286EFAC),
                      blurRadius: 28,
                      spreadRadius: 5),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _breathSeconds == 0 ? '♡' : '$_breathSeconds',
                    style: const TextStyle(
                      fontSize: 48,
                      color: FocusTokens.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    _breathSeconds == 0 ? 'you’re here' : 'breathe gently',
                    style: const TextStyle(
                        color: FocusTokens.primary, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              _breathSeconds == 0
                  ? 'A breath made room for a choice.'
                  : _breathSeconds > 2
                      ? 'Breathe in softly'
                      : 'And slowly breathe out',
              style: FocusTokens.bodyStrong,
            ),
          ),
          const SizedBox(height: 22),
          _primaryButton(
            icon: Icons.check_rounded,
            label: 'Put Down Phone  ·  +5 mindful points',
            onPressed: _putPhoneDown,
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: OutlinedButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Use your phone mindfully. You’re in control, without guilt.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: FocusTokens.primary,
                side: const BorderSide(color: Color(0xFF86EFAC)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
              ),
              child: const Text('I really need to use it  ·  Zero guilt'),
            ),
          ),
          const SizedBox(height: 15),
          const _Note(
            'This is a voluntary mindful pause. App-launch detection, when enabled, is a separate best-effort Android feature.',
          ),
        ],
      );

  Widget _focus(FocusSessionInfo? session) {
    final active = session?.isActive == true;
    final isOverride = session?.emergencyActive == true;
    final isScheduled = session?.isScheduled == true;
    final remaining = session?.remaining;
    final minutes = remaining?.inMinutes ?? 0;
    final seconds = remaining?.inSeconds.remainder(60) ?? 0;
    final routinesAsync = ref.watch(routinesProvider);

    String timerReadout;
    String timerEyebrow;
    if (!active) {
      timerReadout = '4  ·  4';
      timerEyebrow = 'INHALE 4  ·  EXHALE 4';
    } else if (isOverride) {
      timerReadout = 'PAUSED';
      timerEyebrow = 'EMERGENCY OVERRIDE ACTIVE';
    } else if (remaining != null) {
      timerReadout =
          '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
      timerEyebrow = 'FOCUSING GENTLY';
    } else if (isScheduled) {
      final elapsed = session?.startTime != null
          ? DateTime.now().difference(session!.startTime!)
          : null;
      if (elapsed != null && !elapsed.isNegative) {
        final eMins = elapsed.inMinutes.toString().padLeft(2, '0');
        final eSecs = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
        timerReadout = '$eMins:$eSecs';
      } else {
        timerReadout = 'ROUTINE';
      }
      timerEyebrow = 'SCHEDULED ROUTINE ACTIVE';
    } else {
      timerReadout =
          '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
      timerEyebrow = 'FOCUSING GENTLY';
    }

    return _page(
      children: [
        const _Eyebrow('YOUR QUIET CORNER'),
        const SizedBox(height: 8),
        Text(active ? 'Rest your mind.' : 'A little time, just for you.',
            style: _headingStyle(29)),
        Text(
          active
              ? 'Lumi is breathing right alongside you.'
              : 'Choose a soft beginning. You can pause or stop whenever you need.',
          style: _bodyStyle(),
        ),
        const SizedBox(height: 14),
        _lumiHero(
          mood: active ? 'zen_focus' : 'idle_happy',
          message: active
              ? 'Breathe in slowly… breathe out softly.'
              : 'Let’s make room for what matters.',
          subtext: active
              ? 'Lumi is keeping you company · Focus mode active'
              : 'Choose a soft beginning for your focus',
          size: LumiSize.md,
        ),
        const SizedBox(height: 18),
        Center(
          child: Text(
            timerReadout,
            style: const TextStyle(
              fontSize: 48,
              letterSpacing: 3,
              fontWeight: FontWeight.w700,
              color: FocusTokens.primary,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        Center(child: Text(timerEyebrow, style: FocusTokens.eyebrow)),
        const SizedBox(height: 24),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('A calm place to begin',
                  style: FocusTokens.sectionTitle),
              const SizedBox(height: 7),
              Text(
                active
                    ? 'Your session is active (${session?.blockedPackages.length ?? 0} apps paused). Return to the oasis whenever you’re ready.'
                    : 'Choose your focus duration and select which apps to gently pause.',
                style: FocusTokens.bodyMedium,
              ),
              if (!active) ...[
                const SizedBox(height: 14),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _quickDurations.map((duration) {
                      final isSelected = _selectedFocusMinutes == duration;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text('${duration}m'),
                          selected: isSelected,
                          selectedColor: FocusTokens.primary,
                          backgroundColor: FocusTokens.canvas,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : FocusTokens.ink,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: isSelected
                                ? FocusTokens.primary
                                : const Color(0xFFE7DFD5),
                          ),
                          showCheckmark: false,
                          onSelected: (_) {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedFocusMinutes = duration);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        _primaryButton(
          icon: active ? Icons.spa_rounded : Icons.play_arrow_rounded,
          label: active
              ? 'Focus is in progress'
              : 'Begin $_selectedFocusMinutes minutes',
          onPressed: active ? null : () => _startFocus(_selectedFocusMinutes),
        ),
        if (active) ...[
          const SizedBox(height: 10),
          _buildActiveSessionControls(),
        ] else ...[
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => _startFocus(_selectedFocusMinutes),
              child: Text(
                'Choose apps to pause ($_selectedFocusMinutes min)',
              ),
            ),
          ),
        ],
        const SizedBox(height: 14),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.music_note_rounded,
                      color: FocusTokens.primary, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Ambient Sanctuary Sounds',
                        style: FocusTokens.sectionTitle),
                  ),
                  if (ref.watch(soundscapeProvider).activeAmbient != null)
                    TextButton(
                      onPressed: () =>
                          ref.read(soundscapeProvider.notifier).stopAmbient(),
                      child: const Text('Mute'),
                    ),
                ],
              ),
              const SizedBox(height: 5),
              const Text(
                'Continuous organic soundscapes to accompany deep focus',
                style: FocusTokens.caption,
              ),
              const SizedBox(height: 12),
              Row(
                children: kAmbientSoundscapes.map((ambient) {
                  final isPlaying =
                      ref.watch(soundscapeProvider).activeAmbient == ambient.id;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref
                            .read(soundscapeProvider.notifier)
                            .toggleAmbient(ambient.id);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 6),
                        decoration: BoxDecoration(
                          color: isPlaying
                              ? const Color(0xFFDCFCE7)
                              : FocusTokens.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isPlaying
                                ? FocusTokens.primary
                                : const Color(0xFFE7DFD5),
                            width: isPlaying ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(ambient.icon,
                                style: const TextStyle(fontSize: 22)),
                            const SizedBox(height: 4),
                            Text(
                              ambient.name,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isPlaying
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: isPlaying
                                    ? FocusTokens.primary
                                    : FocusTokens.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildRoutinesCard(routinesAsync),
      ],
    );
  }

  Widget _buildRoutinesCard(AsyncValue<List<Routine>> routinesAsync) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded,
                  color: FocusTokens.primary, size: 19),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Scheduled Routines',
                    style: FocusTokens.sectionTitle),
              ),
              TextButton.icon(
                onPressed: () {
                  context.push('${RouteNames.appSelection}?mode=routine');
                },
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('New'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Recurring daily or weekly focus windows',
            style: FocusTokens.caption,
          ),
          const SizedBox(height: 12),
          routinesAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (err, _) => Text(
              'Unable to load routines: $err',
              style: const TextStyle(color: FocusTokens.danger, fontSize: 12),
            ),
            data: (routines) {
              if (routines.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                  decoration: BoxDecoration(
                    color: FocusTokens.canvas,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'No routines scheduled yet. Tap "+ New" to create a recurring focus schedule.',
                    textAlign: TextAlign.center,
                    style: FocusTokens.caption,
                  ),
                );
              }

              return Column(
                children: routines.map((routine) {
                  final slotsSummary = routine.slots
                      .map((slot) => slot.format(context))
                      .join(', ');
                  final daysSummary = _formatWeekdays(routine.weekdays);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: FocusTokens.canvas,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: routine.enabled
                            ? FocusTokens.primary.withValues(alpha: 0.35)
                            : const Color(0xFFE7DFD5),
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        context.push(
                          '${RouteNames.appSelection}?mode=routine',
                          extra: routine,
                        );
                      },
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  routine.label.isNotEmpty
                                      ? routine.label
                                      : 'Scheduled Routine',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: FocusTokens.ink,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  slotsSummary,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: FocusTokens.primary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  daysSummary,
                                  style: FocusTokens.caption,
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: routine.enabled,
                            activeTrackColor: FocusTokens.primary,
                            onChanged: (val) => _toggleRoutine(routine, val),
                          ),
                          IconButton(
                            tooltip: 'Delete routine',
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 20,
                              color: FocusTokens.inkMuted,
                            ),
                            onPressed: () => _deleteRoutine(routine),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
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

  Widget _garden() => _page(
        children: [
          const _Eyebrow('YOUR SMALL, LOVELY STEPS'),
          const SizedBox(height: 8),
          Text('Look how we’re growing.', style: _headingStyle(29)),
          Text('There is no perfect streak. Your garden welcomes you back.',
              style: _bodyStyle()),
          const SizedBox(height: 12),
          _lumiHero(
            mood: 'watering_plant',
            message: 'Our garden grows one gentle step at a time.',
            subtext: '$_focusMinutes focus minutes · $_seeds sprout seeds earned',
            size: LumiSize.md,
          ),
          const SizedBox(height: 16),
          _card(
            color: const Color(0xFFDCFCE7),
            child: Column(
              children: [
                const Text('🌱', style: TextStyle(fontSize: 52)),
                const SizedBox(height: 5),
                const Text('A little garden, growing with you',
                    style: FocusTokens.sectionTitle),
                const SizedBox(height: 6),
                Text('$_focusMinutes focus minutes · $_seeds sprout seeds',
                    style: FocusTokens.bodyMedium),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: LinearProgressIndicator(
                    value: (_focusMinutes / _focusGoalMinutes).clamp(0.0, 1.0),
                    minHeight: 9,
                    backgroundColor: Colors.white,
                    valueColor:
                        const AlwaysStoppedAnimation(FocusTokens.primary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shield_moon_outlined,
                        color: FocusTokens.primary),
                    const SizedBox(width: 10),
                    const Expanded(
                        child: Text('Seedling Shields',
                            style: FocusTokens.sectionTitle)),
                    Text('$_shields left',
                        style: const TextStyle(
                            color: FocusTokens.primary,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 7),
                const Text(
                  'Two gentle reminders each week that busy days and rest are part of life.',
                  style: FocusTokens.bodyMedium,
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _shields == 0 ? null : _useShield,
                  child: Text(_shields == 0
                      ? 'All tucked in for this week'
                      : 'Use a shield'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('Little milestones', style: FocusTokens.sectionTitle),
          const SizedBox(height: 10),
          Row(
            children: [
              _badge('🌱', 'Seedling', true),
              const SizedBox(width: 8),
              _badge('🍃', 'Young Sprout', _seeds >= 50),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _badge('🌷', 'Flower Bud', _seeds >= 150),
              const SizedBox(width: 8),
              _badge('🌼', 'Golden Blossom', _seeds >= 400),
            ],
          ),
        ],
      );

  Widget _celebration() => _page(
        children: [
          const SizedBox(height: 20),
          const Center(
            child: Text('✦  🍃  ✧  🌼  ✦', style: TextStyle(fontSize: 28)),
          ),
          const SizedBox(height: 18),
          const Center(
            child:
                Text('A MOMENT WORTH CELEBRATING', style: FocusTokens.eyebrow),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'You made room to bloom.',
              textAlign: TextAlign.center,
              style: _headingStyle(30),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'A beautiful pocket of presence, made by you.',
              textAlign: TextAlign.center,
              style: _bodyStyle(),
            ),
          ),
          const SizedBox(height: 16),
          _lumiHero(
            mood: 'celebrating',
            message: 'You did it! Look at how bright our garden is blooming.',
            subtext: '+20 Sprout Seeds earned for mindful presence',
            size: LumiSize.hero,
          ),
          const SizedBox(height: 18),
          _card(
            color: const Color(0xFFFFF6D4),
            child: Row(
              children: [
                const Text('🌱', style: TextStyle(fontSize: 34)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('+20 sprout seeds',
                          style: FocusTokens.sectionTitle),
                      Text('$_focusMinutes mindful focus minutes',
                          style: FocusTokens.caption),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _primaryButton(
            icon: Icons.local_florist_rounded,
            label: 'Back to your oasis',
            onPressed: () => _selectTab(0),
          ),
          Center(
            child: TextButton(
              onPressed: () => _selectTab(3),
              child: const Text('See your growing garden'),
            ),
          ),
        ],
      );

  Widget _badge(String icon, String name, bool unlocked) => Expanded(
        child: _card(
          child: Opacity(
            opacity: unlocked ? 1 : 0.5,
            child: Column(
              children: [
                Text(icon, style: const TextStyle(fontSize: 30)),
                const SizedBox(height: 5),
                Text(name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 12)),
                Text(unlocked ? 'Blooming' : 'Growing',
                    style: FocusTokens.caption),
              ],
            ),
          ),
        ),
      );

  Widget _statCard(IconData icon, String value, String label) => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: FocusTokens.primary),
            const SizedBox(height: 9),
            Text(value,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            Text(label, style: FocusTokens.caption),
          ],
        ),
      );

  LumiMood _toLumiMood(String mood) {
    switch (mood) {
      case 'zen_focus':
        return LumiMood.zenFocus;
      case 'celebrating':
        return LumiMood.celebrating;
      case 'sleeping':
        return LumiMood.sleeping;
      case 'gentle_nudge':
        return LumiMood.gentleNudge;
      case 'comforting':
        return LumiMood.comforting;
      case 'watering_plant':
        return LumiMood.wateringPlant;
      default:
        return _isNightTime() ? LumiMood.sleeping : LumiMood.idleHappy;
    }
  }

  bool _isNightTime() {
    final hour = DateTime.now().hour;
    return hour >= 22 || hour < 6;
  }

  void _narrateTab(int tab) {
    final sound = ref.read(soundscapeProvider.notifier);
    switch (tab) {
      case 0:
        if (_isNightTime()) {
          sound.speakLumi(
              "Shh... stars are out. It's time to let your eyes rest and recharge your spirit.");
        } else {
          sound.speakLumi(
              "Hello friend. You have lived a little more of your real life today. Every step counts, and I am right here with you.");
        }
        break;
      case 1:
        sound.speakLumi(
            "Let us take a breath together. What is your heart hoping to find before opening your apps? You are in control.");
        break;
      case 2:
        sound.speakLumi(
            "We are resting our minds together. Breathe in slowly, and breathe out softly. There is no need to rush.");
        break;
      case 3:
        sound.speakLumi(
            "Look how we are growing. Every gentle step helps our garden bloom.");
        break;
      case 4:
        sound.speakLumi(
            "You did it! A beautiful pocket of presence, made by you. I am so proud of the room you made to bloom.");
        sound.playCelebrationBell();
        break;
    }
  }

  Widget _lumiHero({
    required String mood,
    required String message,
    String? subtext,
    LumiSize size = LumiSize.lg,
  }) {
    final lumiMood = _toLumiMood(mood);
    final sound = ref.read(soundscapeProvider.notifier);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Center(
        child: LumiMascot(
          mood: lumiMood,
          size: size,
          showSpeechBubble: true,
          speechText: message,
          subtext: subtext,
          isInteractive: true,
          onPet: () {
            sound.playDewdrop();
            sound.speakLumi(message);
          },
          onSpeechTap: () {
            HapticFeedback.lightImpact();
            sound.playDewdrop();
            sound.speakLumi(message);
          },
        ),
      ),
    );
  }

  Widget _page({required List<Widget> children}) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );

  Widget _card({required Widget child, Color color = FocusTokens.surface}) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE7DFD5)),
        ),
        child: child,
      );

  Widget _primaryButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) =>
      SizedBox(
        width: double.infinity,
        height: 56,
        child: FilledButton.icon(
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(label, textAlign: TextAlign.center),
          style: FilledButton.styleFrom(
            backgroundColor: FocusTokens.primary,
            disabledBackgroundColor:
                FocusTokens.primary.withValues(alpha: 0.45),
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
        ),
      );

  TextStyle _headingStyle(double size) => TextStyle(
        fontSize: size,
        height: 1.12,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
        color: FocusTokens.ink,
      );

  TextStyle _bodyStyle() => const TextStyle(
        fontSize: 15,
        height: 1.45,
        color: FocusTokens.inkMuted,
      );

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'evening';
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          color: FocusTokens.primary,
          fontSize: 11,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w800,
        ),
      );
}

class _Note extends StatelessWidget {
  const _Note(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 16, color: FocusTokens.inkMuted),
          const SizedBox(width: 7),
          Expanded(child: Text(text, style: FocusTokens.caption)),
        ],
      );
}
