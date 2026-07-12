import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/allowed_app.dart';
import '../../domain/models/focus_session_snapshot.dart';
import '../../domain/models/focus_session.dart';
import '../../services/interfaces/accessibility_service_manager.dart';
import 'settings_providers.dart';
import 'service_providers.dart';

import '../../core/utils/app_logger.dart';

final activeSessionSnapshotProvider = StateProvider<FocusSessionSnapshot?>((ref) => null);

final focusModeProvider =
    StateNotifierProvider<FocusModeStateNotifier, bool>((ref) {
  return FocusModeStateNotifier(ref);
});

class FocusModeStateNotifier extends StateNotifier<bool> {
  FocusModeStateNotifier(this.ref) : super(false) {
    _checkInitialState();
  }

  final Ref ref;

  Future<void> _checkInitialState() async {
    final sessionManager = ref.read(focusSessionManagerProvider);
    var activeSnapshot = await sessionManager.getActiveSnapshot();

    final accessibility = ref.read(accessibilityServiceManagerProvider);
    final isNativeActive = await accessibility.isBlockingActive();

    if (activeSnapshot != null || isNativeActive) {
      if (activeSnapshot == null && isNativeActive) {
        // Native state is active, but Hive database lost the snapshot.
        // Self-heal: reconstruct the snapshot from SharedPreferences in the native layer!
        AppLogger.warning('Hive snapshot lost on boot while focus mode is active. Reconstructing from native prefs...');
        activeSnapshot = await _reconstructSnapshotFromNative(accessibility);
        if (activeSnapshot != null) {
          await sessionManager.updateActiveSnapshot(activeSnapshot);
        }
      }
      await sessionManager.restoreSessionState();
      ref.read(activeSessionSnapshotProvider.notifier).state = activeSnapshot;
      state = true;
    }
  }

  Future<FocusSessionSnapshot?> _reconstructSnapshotFromNative(
      AccessibilityServiceManager accessibility) async {
    try {
      final details = await accessibility.getNativeSessionDetails();
      if (details == null || details['isActive'] != true) return null;

      final startMs = details['sessionStartTime'] as int? ?? DateTime.now().millisecondsSinceEpoch;
      final endMs = details['scheduledEndTime'] as int? ?? 0;
      final allowedApps = List<String>.from(details['allowedApps'] as List? ?? []);
      final alwaysAllowedApps = List<String>.from(details['alwaysAllowedApps'] as List? ?? []);
      final strictMode = details['strictMode'] as bool? ?? false;
      final activeRoutineId = details['activeRoutineId'] as String?;

      final startTime = DateTime.fromMillisecondsSinceEpoch(startMs);
      final endTime = endMs > 0
          ? DateTime.fromMillisecondsSinceEpoch(endMs)
          : startTime.add(const Duration(hours: 1));
      final duration = endTime.difference(startTime);

      return FocusSessionSnapshot(
        sessionId: 'reconstructed_${DateTime.now().millisecondsSinceEpoch}',
        startTime: startTime,
        endTime: endTime,
        duration: duration,
        allowedApps: allowedApps,
        alwaysAllowedApps: alwaysAllowedApps,
        activeProfile: 'Default',
        blockingRules: {},
        focusSettings: {
          'strictMode': strictMode.toString(),
        },
        scheduleId: activeRoutineId,
        creationTimestamp: startTime,
      );
    } catch (e, st) {
      AppLogger.error('Failed to reconstruct snapshot from native settings',
          error: e, stackTrace: st);
      return null;
    }
  }

  Future<void> startFocus(Duration duration, {String? scheduleId}) async {
    final sessionManager = ref.read(focusSessionManagerProvider);
    final snapshot = await sessionManager.startSession(duration: duration, scheduleId: scheduleId);
    ref.read(activeSessionSnapshotProvider.notifier).state = snapshot;

    final sessionTrackingService = ref.read(sessionTrackingServiceProvider);
    await sessionTrackingService.startSession(
      triggerType: scheduleId != null ? SessionTriggerType.scheduled : SessionTriggerType.manual,
      routineId: scheduleId,
    );

    state = true;
  }

  Future<void> stopFocus() async {
    final sessionManager = ref.read(focusSessionManagerProvider);
    await sessionManager.endSession();
    ref.read(activeSessionSnapshotProvider.notifier).state = null;

    final sessionTrackingService = ref.read(sessionTrackingServiceProvider);
    await sessionTrackingService.endSession();

    state = false;
  }
}
// End of focus providers.

final allowedAppsProvider = StreamProvider<List<AllowedApp>>((ref) {
  final repository = ref.watch(allowedAppsRepositoryProvider);
  return repository.watchAllowedApps();
});

final allowedAppsControllerProvider = Provider<AllowedAppsController>((ref) {
  return AllowedAppsController(ref);
});

class AllowedAppsController {
  AllowedAppsController(this.ref);

  final Ref ref;

  Future<void> toggleAllowedApp(AllowedApp app, bool isAllowed) async {
    final repository = ref.read(allowedAppsRepositoryProvider);
    if (isAllowed) {
      await repository.upsertAllowedApp(app);
    } else {
      await repository.removeAllowedApp(app.packageName);
    }

    final focusActive = ref.read(focusModeProvider);
    if (focusActive) {
      final sessionManager = ref.read(focusSessionManagerProvider);
      final activeSnapshot = await sessionManager.getActiveSnapshot();
      if (activeSnapshot != null) {
        final updatedAllowedApps = List<String>.from(activeSnapshot.allowedApps);
        if (isAllowed) {
          if (!updatedAllowedApps.contains(app.packageName)) {
            updatedAllowedApps.add(app.packageName);
          }
        } else {
          updatedAllowedApps.remove(app.packageName);
        }
        final newSnapshot = activeSnapshot.copyWith(allowedApps: updatedAllowedApps);
        await sessionManager.updateActiveSnapshot(newSnapshot);
        ref.read(activeSessionSnapshotProvider.notifier).state = newSnapshot;
      }
    }
  }
}
