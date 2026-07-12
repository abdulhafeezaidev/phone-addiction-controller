import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

// Interfaces
import '../../services/interfaces/storage_service.dart';
import '../../services/interfaces/password_service.dart';
import '../../services/interfaces/installed_apps_service.dart';
import '../../services/interfaces/schedule_service.dart';
import '../../services/interfaces/accessibility_service_manager.dart';
import '../../services/interfaces/session_tracking_service.dart';
import '../../services/interfaces/statistics_service.dart';
import '../../services/interfaces/backup_restore_service.dart';
import '../../services/interfaces/notification_service.dart';
import '../../services/interfaces/allowed_apps_repository.dart';
import '../../services/interfaces/authorization_service.dart';
import '../../services/interfaces/focus_session_manager.dart';
import '../../services/interfaces/emergency_override_service.dart';

import '../../services/interfaces/user_apps_service.dart';
import '../../services/interfaces/system_package_service.dart';

// Implementations
import '../../services/impl/storage_service_impl.dart';
import '../../services/impl/password_service_impl.dart';
import '../../services/impl/installed_apps_service_impl.dart';
import '../../services/interfaces/focus_lock_pin_service.dart';
import '../../services/impl/focus_lock_pin_service_impl.dart';
import '../../services/impl/user_apps_service_impl.dart';
import '../../services/impl/system_package_service_impl.dart';
import '../../services/impl/schedule_service_impl.dart';
import '../../services/impl/accessibility_service_manager_impl.dart';
import '../../services/impl/session_tracking_service_impl.dart';
import '../../services/impl/statistics_service_impl.dart';
import '../../services/impl/backup_restore_service_impl.dart';
import '../../services/impl/notification_service_impl.dart';
import '../../services/impl/allowed_apps_repository_impl.dart';
import '../../services/impl/authorization_service_impl.dart';
import '../../services/impl/focus_session_manager_impl.dart';
import '../../services/impl/emergency_override_service_impl.dart';

import '../../domain/models/allowed_app.dart';

// ── Service Providers ───────────────────────────────────────────────────────

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageServiceImpl();
});

final passwordServiceProvider = Provider<PasswordService>((ref) {
  return PasswordServiceImpl(ref.watch(storageServiceProvider));
});

final userAppsServiceProvider = Provider<UserAppsService>((ref) {
  return UserAppsServiceImpl();
});

final systemPackageServiceProvider = Provider<SystemPackageService>((ref) {
  return SystemPackageServiceImpl();
});

final installedAppsServiceProvider = Provider<InstalledAppsService>((ref) {
  return InstalledAppsServiceImpl();
});

final scheduleServiceProvider = Provider<ScheduleService>((ref) {
  return ScheduleServiceImpl(storageService: ref.watch(storageServiceProvider));
});

final accessibilityServiceManagerProvider =
    Provider<AccessibilityServiceManager>((ref) {
  return AccessibilityServiceManagerImpl();
});

final sessionTrackingServiceProvider = Provider<SessionTrackingService>((ref) {
  return SessionTrackingServiceImpl(storageService: ref.watch(storageServiceProvider));
});

final focusLockPinServiceProvider = Provider<FocusLockPinService>((ref) {
  return FocusLockPinServiceImpl(
    ref.watch(storageServiceProvider),
    ref.watch(passwordServiceProvider),
  );
});

final statisticsServiceProvider = Provider<StatisticsService>((ref) {
  return StatisticsServiceImpl(
    sessionTrackingService: ref.watch(sessionTrackingServiceProvider),
  );
});

final backupRestoreServiceProvider = Provider<BackupRestoreService>((ref) {
  return BackupRestoreServiceImpl(
    storageService: ref.watch(storageServiceProvider),
  );
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationServiceImpl();
});

final allowedAppsRepositoryProvider = Provider<AllowedAppsRepository>((ref) {
  return AllowedAppsRepositoryImpl();
});

final emergencyOverrideServiceProvider = Provider<EmergencyOverrideService>((ref) {
  return EmergencyOverrideServiceImpl(
    storageService: ref.watch(storageServiceProvider),
    passwordService: ref.watch(passwordServiceProvider),
    scheduleService: ref.watch(scheduleServiceProvider),
    focusSessionManager: ref.watch(focusSessionManagerProvider),
  );
});

final authorizationServiceProvider = Provider<AuthorizationService>((ref) {
  return AuthorizationServiceImpl(ref.watch(emergencyOverrideServiceProvider));
});

final focusSessionManagerProvider = Provider<FocusSessionManager>((ref) {
  return FocusSessionManagerImpl(
    storageService: ref.watch(storageServiceProvider),
    allowedAppsRepository: ref.watch(allowedAppsRepositoryProvider),
    accessibilityServiceManager: ref.watch(accessibilityServiceManagerProvider),
  );
});

// ── Data Providers ──────────────────────────────────────────────────────────

final installedAppsProvider = FutureProvider.family<List<AllowedApp>, bool>((ref, includeSystem) async {
  final service = ref.watch(installedAppsServiceProvider);
  return await service.getInstalledApps(includeSystemApps: includeSystem);
});

final accessibilityStatusProvider = FutureProvider<bool>((ref) async {
  final manager = ref.watch(accessibilityServiceManagerProvider);
  return await manager.isServiceEnabled();
});

final foregroundAppStreamProvider = StreamProvider<Map<String, dynamic>>((ref) {
  const eventChannel = EventChannel('com.personal.phone_addiction_controller/foreground_app');
  return eventChannel.receiveBroadcastStream().map((event) {
    return Map<String, dynamic>.from(event as Map);
  });
});

final defaultLauncherStatusProvider = FutureProvider<bool>((ref) async {
  final manager = ref.watch(accessibilityServiceManagerProvider);
  return await manager.isDefaultLauncher();
});
