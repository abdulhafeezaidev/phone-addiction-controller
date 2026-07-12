import '../interfaces/authorization_service.dart';
import '../interfaces/emergency_override_service.dart';

class AuthorizationServiceImpl implements AuthorizationService {
  final EmergencyOverrideService _emergencyOverrideService;

  AuthorizationServiceImpl(this._emergencyOverrideService);

  Future<bool> _isOverrideActive() async {
    final state = await _emergencyOverrideService.getOverrideState();
    return state.isOverrideActive;
  }

  @override
  Future<bool> canCreateSession() async => true;

  @override
  Future<bool> canEditFutureSchedule() async => true;

  @override
  Future<bool> canModifyRunningSession() async {
    if (await _isOverrideActive()) return true;
    return false;
  }

  @override
  Future<bool> canStopFocus() async {
    if (await _isOverrideActive()) return true;
    return false;
  }

  @override
  Future<bool> canEditAllowedApps({required bool isFocusActive}) async {
    if (await _isOverrideActive()) return true;
    return !isFocusActive;
  }

  @override
  Future<bool> canChangePassword() async {
    // Changing the password still requires admin password verification
    // even if emergency override is active, to keep them completely separate.
    return false;
  }

  @override
  Future<bool> canFactoryReset() async {
    if (await _isOverrideActive()) return true;
    return false;
  }
}
