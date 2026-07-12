import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class FocusLockPinService {
  Future<void> setPin(String newPin);
  Future<bool> verifyPin(String pin);
  bool isPinSet();
}
