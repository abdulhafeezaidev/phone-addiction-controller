import '../../core/constants/app_constants.dart';
import '../interfaces/focus_lock_pin_service.dart';
import '../interfaces/password_service.dart';
import '../interfaces/storage_service.dart';

class FocusLockPinServiceImpl implements FocusLockPinService {
  final StorageService _storageService;
  final PasswordService _passwordService;
  
  static const String _boxName = AppConstants.settingsBox;
  static const String _pinKey = 'focus_lock_pin_hash';

  FocusLockPinServiceImpl(this._storageService, this._passwordService);

  @override
  bool isPinSet() {
    return _storageService.containsKey(_boxName, _pinKey);
  }

  @override
  Future<void> setPin(String newPin) async {
    final hash = _passwordService.hashPassword(newPin);
    await _storageService.put(_boxName, _pinKey, hash);
  }

  @override
  Future<bool> verifyPin(String pin) async {
    if (!isPinSet()) {
      // If PIN is not set, we can either return true or false.
      // But we shouldn't get here because we should prompt the user to set a PIN.
      return false;
    }
    
    final storedHash = _storageService.get<String>(_boxName, _pinKey);
    if (storedHash == null) return false;
    
    return _passwordService.verifyPassword(pin, storedHash);
  }
}
