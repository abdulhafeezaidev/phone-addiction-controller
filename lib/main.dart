import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/route_names.dart';
import 'core/constants/app_constants.dart';
import 'core/utils/app_logger.dart';
import 'core/providers/service_providers.dart';
import 'core/providers/focus_providers.dart';
import 'data/local/hive_boxes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive with error recovery
  try {
    await Hive.initFlutter();
    await HiveBoxes.openAllBoxes();
    AppLogger.info('Hive initialized successfully');
  } catch (e, stack) {
    AppLogger.error('Hive initialization failed, attempting recovery',
        error: e, stackTrace: stack);
    try {
      await Hive.deleteFromDisk();
      await Hive.initFlutter();
      await HiveBoxes.openAllBoxes();
      AppLogger.info('Hive recovered after deletion');
    } catch (e2) {
      AppLogger.error('Hive recovery failed', error: e2);
    }
  }

  runApp(
    const ProviderScope(
      child: PhoneAddictionControllerApp(),
    ),
  );
}

class PhoneAddictionControllerApp extends ConsumerStatefulWidget {
  const PhoneAddictionControllerApp({super.key});

  @override
  ConsumerState<PhoneAddictionControllerApp> createState() =>
      _PhoneAddictionControllerAppState();
}

class _PhoneAddictionControllerAppState
    extends ConsumerState<PhoneAddictionControllerApp> {
  static const _navChannel =
      MethodChannel('com.personal.phone_addiction_controller/navigation');
  static const _accessibilityChannel =
      MethodChannel('com.personal.phone_addiction_controller/accessibility');

  @override
  void initState() {
    super.initState();

    // Handle method calls from the native layer (MainActivity)
    _navChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'routineTriggered':
          // A scheduled alarm fired. Native state is already set.
          // We now need to create the FocusSessionSnapshot and navigate to Focus Home.
          await _handleRoutineTriggered(call.arguments);

        case 'bootRecovery':
          // Device rebooted while Focus Mode was active.
          // Restore FocusSessionSnapshot and navigate to Focus Home.
          await _handleBootRecovery();

        case 'focusRecover':
          // A blocked app was detected — bring Focus Home to front
          final router = ref.read(appRouterProvider);
          router.go(RouteNames.focusSession);

        case 'homeLaunch':
          // Home button pressed during focus — redirect to Focus Home
          _handleHomeLaunch();

        case 'showLockScreen':
          // Screen turned on during Focus Mode — show Focus Lock Screen
          _handleShowLockScreen();

        case 'showBlockScreen':
          final args = call.arguments as Map?;
          final appName = args?['appName'] as String? ?? 'App';
          final router = ref.read(appRouterProvider);
          router.push(RouteNames.blocked, extra: {'appName': appName});
      }
    });

    // Check for any pending blocked event from before the Flutter engine started
    _showPendingBlockedEvent();

    // Listen to blocked events for statistics tracking
    const blockedEventChannel =
        EventChannel('com.personal.phone_addiction_controller/blocked_events');
    blockedEventChannel.receiveBroadcastStream().listen((event) {
      final data = Map<String, dynamic>.from(event as Map);
      final packageName = data['packageName'] as String?;
      if (packageName != null) {
        ref
            .read(sessionTrackingServiceProvider)
            .recordBlockedAttempt(packageName);
      }
    });
  }

  // ── Routine Triggered Handler ─────────────────────────────────────────────

  /// Called when a scheduled alarm fires and the native layer has already set
  /// FocusModeManager.isActive = true in SharedPreferences.
  ///
  /// We must now:
  ///  1. Load the routine from Hive to get the allowed-apps configuration.
  ///  2. Call FocusModeStateNotifier.startFocus() to create the immutable snapshot.
  ///  3. Navigate to the Focus Home screen.
  Future<void> _handleRoutineTriggered(dynamic arguments) async {
    try {
      final args = arguments as Map?;
      final routineId = args?['routineId'] as String? ?? '';

      AppLogger.info('Routine triggered: $routineId — creating FocusSessionSnapshot');

      // Determine session duration from the routine's active slot.
      // We calculate from now until the slot's end time on this routine.
      final scheduleService = ref.read(scheduleServiceProvider);
      final routine = routineId.isNotEmpty ? await scheduleService.getRoutine(routineId) : null;

      Duration sessionDuration;
      if (routine != null) {
        final now = DateTime.now();
        // Find the active slot
        final activeSlot = routine.slots.firstWhere(
          (s) => s.isCurrentlyActive(now),
          orElse: () => routine.slots.first,
        );

        final endHour = activeSlot.endHour;
        final endMinute = activeSlot.endMinute;
        var endTime = DateTime(now.year, now.month, now.day, endHour, endMinute);

        // Handle overnight slot: if end is earlier in the day, it's tomorrow
        if (endTime.isBefore(now)) {
          endTime = endTime.add(const Duration(days: 1));
        }

        sessionDuration = endTime.difference(now);
        if (sessionDuration.isNegative || sessionDuration.inMinutes < 1) {
          sessionDuration = const Duration(hours: 1);
        }
      } else {
        // Fallback: 1 hour session if routine not found in Hive
        sessionDuration = const Duration(hours: 1);
      }

      // Start the full Flutter focus session (creates snapshot, syncs native, etc.)
      await ref.read(focusModeProvider.notifier).startFocus(
        sessionDuration,
        scheduleId: routineId.isNotEmpty ? routineId : null,
      );

      // Navigate to Focus Home
      if (mounted) {
        final router = ref.read(appRouterProvider);
        router.go(RouteNames.focusSession);
      }
    } catch (e, st) {
      AppLogger.error('Failed to handle routine trigger', error: e, stackTrace: st);
      // Even if something fails, navigate to focus session since native state is already active
      if (mounted) {
        final router = ref.read(appRouterProvider);
        router.go(RouteNames.focusSession);
      }
    }
  }

  // ── Boot Recovery Handler ──────────────────────────────────────────────────

  /// Called when the device rebooted while Focus Mode was active.
  /// Native state is already restored. We need to:
  ///  1. Check if a FocusSessionSnapshot exists or create one from native state.
  ///  2. Navigate to Focus Home.
  Future<void> _handleBootRecovery() async {
    try {
      AppLogger.info('Boot recovery: restoring Focus session');

      // Check native session details
      final nativeDetails = await _accessibilityChannel
          .invokeMethod<Map<dynamic, dynamic>>('getNativeSessionDetails');
      final isActive = nativeDetails?['isActive'] as bool? ?? false;

      if (!isActive) {
        AppLogger.info('Boot recovery: native session not active, skipping');
        return;
      }

      // Attempt to restore session from existing snapshot
      final isFocusActive = ref.read(focusModeProvider);
      if (!isFocusActive) {
        // Snapshot doesn't exist — create one from native state
        final isScheduled = nativeDetails?['isScheduled'] as bool? ?? false;
        final routineId = nativeDetails?['activeRoutineId'] as String?;
        final startTime = nativeDetails?['sessionStartTime'] as int? ?? 0;
        final endTime = nativeDetails?['scheduledEndTime'] as int? ?? 0;

        Duration sessionDuration;
        if (endTime > 0) {
          final remaining = endTime - DateTime.now().millisecondsSinceEpoch;
          sessionDuration = Duration(milliseconds: remaining > 0 ? remaining : 3600000);
        } else if (startTime > 0) {
          // Indefinite session — use a long duration
          sessionDuration = const Duration(hours: 24);
        } else {
          sessionDuration = const Duration(hours: 1);
        }

        await ref.read(focusModeProvider.notifier).startFocus(
          sessionDuration,
          scheduleId: routineId,
        );
      }

      // Navigate to Focus Home
      if (mounted) {
        final router = ref.read(appRouterProvider);
        router.go(RouteNames.focusSession);
      }
    } catch (e, st) {
      AppLogger.error('Boot recovery failed', error: e, stackTrace: st);
      // Even if recovery fails, try to navigate to focus home since native is active
      if (mounted) {
        final router = ref.read(appRouterProvider);
        router.go(RouteNames.focusSession);
      }
    }
  }

  // ── Home Launch Handler ───────────────────────────────────────────────────

  void _handleHomeLaunch() {
    final isFocusActive = ref.read(focusModeProvider);
    if (isFocusActive) {
      final router = ref.read(appRouterProvider);
      router.go(RouteNames.focusSession);
    }
  }

  // ── Lock Screen Handler ───────────────────────────────────────────────────

  void _handleShowLockScreen() {
    final isFocusActive = ref.read(focusModeProvider);
    if (isFocusActive && mounted) {
      final router = ref.read(appRouterProvider);
      router.go(RouteNames.lockScreen);
    }
  }

  // ── Pending Blocked Event ─────────────────────────────────────────────────

  Future<void> _showPendingBlockedEvent() async {
    try {
      final pending =
          await _accessibilityChannel.invokeMethod<Map<dynamic, dynamic>>(
        'getPendingBlockedEvent',
      );
      final appName = pending?['appName'] as String?;
      if (appName == null || appName.isEmpty) return;

      if (mounted) {
        final router = ref.read(appRouterProvider);
        router.push(RouteNames.blocked, extra: {'appName': appName});
      }
    } on PlatformException {
      // No pending native event; normal startup.
    } catch (e) {
      AppLogger.warning('Unexpected error checking pending blocked event: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'FocusOS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      routerConfig: router,
    );
  }
}
