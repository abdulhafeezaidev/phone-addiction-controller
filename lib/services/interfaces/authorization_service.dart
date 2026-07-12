abstract class AuthorizationService {
  /// Whether the user can create a new focus session. (Always true/ frictionless)
  Future<bool> canCreateSession();

  /// Whether the user can edit or configure future schedules. (Always true/ frictionless)
  Future<bool> canEditFutureSchedule();

  /// Whether the user can modify the current running session's snapshot. (Requires auth)
  Future<bool> canModifyRunningSession();

  /// Whether the user can stop or exit the current focus session early. (Requires auth)
  Future<bool> canStopFocus();

  /// Whether the user can edit allowed apps. Frictionless when inactive, protected when active.
  Future<bool> canEditAllowedApps({required bool isFocusActive});

  /// Whether the user can change or delete the administrator password. (Requires auth)
  Future<bool> canChangePassword();

  /// Whether the user can perform a factory reset / data wipe. (Requires auth)
  Future<bool> canFactoryReset();
}
