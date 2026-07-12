import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/models/focus_session_snapshot.dart';
import '../../domain/models/app_settings.dart';
import '../interfaces/focus_session_manager.dart';
import '../interfaces/storage_service.dart';
import '../interfaces/allowed_apps_repository.dart';
import '../interfaces/accessibility_service_manager.dart';

class FocusSessionManagerImpl implements FocusSessionManager {
  final StorageService _storageService;
  final AllowedAppsRepository _allowedAppsRepository;
  final AccessibilityServiceManager _accessibilityServiceManager;
  final _uuid = const Uuid();

  FocusSessionManagerImpl({
    required StorageService storageService,
    required AllowedAppsRepository allowedAppsRepository,
    required AccessibilityServiceManager accessibilityServiceManager,
  })  : _storageService = storageService,
        _allowedAppsRepository = allowedAppsRepository,
        _accessibilityServiceManager = accessibilityServiceManager;

  /// Canonical list of system apps always allowed during Focus Mode.
  /// This mirrors CRITICAL_SYSTEM_PACKAGES in FocusPolicyEngine.kt — keep in sync.
  static const _alwaysAllowedSystemPackages = [
    // Phone / Dialer
    'com.android.phone', 'com.android.dialer', 'com.android.incallui',
    'com.samsung.android.incallui', 'com.samsung.android.dialer',
    'com.samsung.android.app.telephonyui', 'com.samsung.android.phone',
    'com.google.android.dialer',
    // Contacts
    'com.android.contacts', 'com.samsung.android.contacts', 'com.google.android.contacts',
    // Messages / SMS
    'com.android.mms', 'com.samsung.android.messaging', 'com.google.android.apps.messaging',
    // Camera
    'com.android.camera', 'com.android.camera2',
    'com.sec.android.app.camera', 'com.samsung.android.app.camera',
    'com.google.android.GoogleCamera', 'com.samsung.android.cameralite',
    // Calculator
    'com.android.calculator2', 'com.sec.android.app.popupcalculator',
    'com.samsung.android.calculator', 'com.google.android.calculator',
    // Clock / Alarms
    'com.android.deskclock', 'com.sec.android.app.clockpackage',
    'com.samsung.android.app.clockpackage', 'com.google.android.deskclock',
    // Google Core Services for Gemini & Assistant
    'com.google.android.googlequicksearchbox',
    'com.google.android.gms',
    'com.google.android.gsf',
    // Files / Downloads
    'com.android.documentsui', 'com.sec.android.app.myfiles',
    'com.google.android.apps.nbu.files', 'com.samsung.android.app.myfiles',
  ];

  @override
  Future<FocusSessionSnapshot?> getActiveSnapshot() async {
    return _storageService.get<FocusSessionSnapshot>(
      AppConstants.focusSessionSnapshotBox,
      'active_snapshot',
    );
  }

  @override
  Future<FocusSessionSnapshot> startSession({
    required Duration duration,
    String? scheduleId,
  }) async {
    final startTime = DateTime.now();
    final endTime = startTime.add(duration);

    // Get currently allowed apps
    final allowedApps = _allowedAppsRepository.getAllowedApps();
    final allowedPackages = allowedApps.map((a) => a.packageName).toList();

    // Get current settings
    final settings = _storageService.get<AppSettings>(
      AppConstants.appSettingsBox,
      'settings',
    ) ?? AppSettings();

    final snapshot = FocusSessionSnapshot(
      sessionId: _uuid.v4(),
      startTime: startTime,
      endTime: endTime,
      duration: duration,
      allowedApps: allowedPackages,
      alwaysAllowedApps: _alwaysAllowedSystemPackages,
      activeProfile: 'Default',
      blockingRules: {},
      focusSettings: {
        'strictMode': settings.strictMode.toString(),
      },
      scheduleId: scheduleId,
      creationTimestamp: DateTime.now(),
    );

    await _storageService.put(
      AppConstants.focusSessionSnapshotBox,
      'active_snapshot',
      snapshot,
    );

    // Sync state with native service
    await _syncWithNative(snapshot);

    return snapshot;
  }

  @override
  Future<void> endSession() async {
    await _storageService.delete(
      AppConstants.focusSessionSnapshotBox,
      'active_snapshot',
    );
    await _accessibilityServiceManager.sendCommand('stopFocusMode');
  }

  @override
  Future<void> updateActiveSnapshot(FocusSessionSnapshot snapshot) async {
    await _storageService.put(
      AppConstants.focusSessionSnapshotBox,
      'active_snapshot',
      snapshot,
    );
    await _syncWithNative(snapshot);
  }

  @override
  Future<void> restoreSessionState() async {
    final snapshot = await getActiveSnapshot();
    if (snapshot != null) {
      await _syncWithNative(snapshot);
    }
  }

  Future<void> _syncWithNative(FocusSessionSnapshot snapshot) async {
    // 1. Sync allowed apps
    await _accessibilityServiceManager.sendCommand(
      'updateAllowedApps',
      args: {
        'apps': snapshot.allowedApps,
        'alwaysAllowedApps': snapshot.alwaysAllowedApps,
      },
    );

    // 2. Sync strict mode
    final isStrict = snapshot.focusSettings['strictMode'] == 'true';
    await _accessibilityServiceManager.sendCommand(
      'updateStrictMode',
      args: {'isStrict': isStrict},
    );

    // 3. Start focus mode in native layer
    await _accessibilityServiceManager.sendCommand('startFocusMode');
  }
}
