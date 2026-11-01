import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/admin_settings.dart';
import '../../domain/models/routine.dart';
import '../../services/interfaces/storage_service.dart';
import '../../services/impl/storage_service_impl.dart';
import '../../services/interfaces/password_service.dart';
import '../../services/impl/password_service_impl.dart';
import '../../services/interfaces/schedule_service.dart';
import '../../services/impl/schedule_service_impl.dart';
import '../../services/interfaces/emergency_override_service.dart';
import '../../services/impl/emergency_override_service_impl.dart';
import '../../services/native_bridge_service.dart';

// ── Low-Level Services ────────────────────────────────────────────────────────

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageServiceImpl();
});

final nativeBridgeServiceProvider = Provider<NativeBridgeService>((ref) {
  return NativeBridgeService();
});

final passwordServiceProvider = Provider<PasswordService>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return PasswordServiceImpl(storage);
});

final scheduleServiceProvider = Provider<ScheduleService>((ref) {
  final storage = ref.watch(storageServiceProvider);
  final native = ref.watch(nativeBridgeServiceProvider);
  return ScheduleServiceImpl(
    storageService: storage,
    nativeBridgeService: native,
  );
});

final emergencyOverrideServiceProvider = Provider<EmergencyOverrideService>((ref) {
  final storage = ref.watch(storageServiceProvider);
  final password = ref.watch(passwordServiceProvider);
  final native = ref.watch(nativeBridgeServiceProvider);

  final service = EmergencyOverrideServiceImpl(
    storageService: storage,
    passwordService: password,
    nativeBridgeService: native,
  );
  ref.onDispose(() => service.dispose());
  return service;
});

// ── State Providers ──────────────────────────────────────────────────────────

/// Current session state polled periodically from the native layer.
final focusSessionProvider = StreamProvider.autoDispose<FocusSessionInfo>((ref) async* {
  final native = ref.watch(nativeBridgeServiceProvider);

  // Emit initial state immediately
  yield await native.getSession();

  // Poll every second to keep countdowns and session switches in sync
  final timer = Stream.periodic(const Duration(seconds: 1));
  await for (final _ in timer) {
    yield await native.getSession();
  }
});

/// Installed applications query.
final installedAppsProvider = FutureProvider.autoDispose<List<AppInfo>>((ref) async {
  final native = ref.watch(nativeBridgeServiceProvider);
  return await native.getInstalledApps();
});

/// Admin settings (accountability partner & password).
final adminSettingsProvider = FutureProvider<AdminSettings?>((ref) async {
  final service = ref.watch(passwordServiceProvider);
  return await service.getAdminSettings();
});

/// Protection state (anti-uninstall & accessibility guard).
final protectionStateProvider = FutureProvider<ProtectionState>((ref) async {
  final native = ref.watch(nativeBridgeServiceProvider);
  return await native.getProtectionState();
});

/// Accessibility Service active state.
final accessibilityEnabledProvider = FutureProvider.autoDispose<bool>((ref) async {
  final native = ref.watch(nativeBridgeServiceProvider);
  return await native.isServiceEnabled();
});

/// Routines list state notifier.
final routinesProvider = StateNotifierProvider<RoutinesNotifier, AsyncValue<List<Routine>>>((ref) {
  final schedule = ref.watch(scheduleServiceProvider);
  return RoutinesNotifier(schedule);
});

class RoutinesNotifier extends StateNotifier<AsyncValue<List<Routine>>> {
  RoutinesNotifier(this._scheduleService) : super(const AsyncValue.loading()) {
    loadRoutines();
  }

  final ScheduleService _scheduleService;

  Future<void> loadRoutines() async {
    try {
      state = const AsyncValue.loading();
      final list = await _scheduleService.getRoutines();
      list.sort((a, b) {
        final aTime = a.startTime.hour * 60 + a.startTime.minute;
        final bTime = b.startTime.hour * 60 + b.startTime.minute;
        return aTime.compareTo(bTime);
      });
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addRoutine(Routine routine) async {
    try {
      await _scheduleService.addRoutine(
        weekdays: routine.weekdays,
        startTime: routine.startTime,
        endTime: routine.endTime,
        label: routine.label,
        enabled: routine.enabled,
        slots: routine.slots,
      );
      await loadRoutines();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateRoutine(Routine routine) async {
    try {
      await _scheduleService.updateRoutine(routine);
      await loadRoutines();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> toggleRoutine(String id, bool enabled) async {
    try {
      await _scheduleService.toggleRoutine(id, enabled);
      await loadRoutines();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteRoutine(String id) async {
    try {
      await _scheduleService.deleteRoutine(id);
      await loadRoutines();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
