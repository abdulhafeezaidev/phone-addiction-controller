import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/interfaces/password_service.dart';
import 'service_providers.dart';
import '../../widgets/password_auth_dialog.dart';

class AdminAuthState {
  final bool isUnlocked;
  final DateTime? unlockedUntil;
  final Duration remainingLockout;

  AdminAuthState({
    this.isUnlocked = false,
    this.unlockedUntil,
    this.remainingLockout = Duration.zero,
  });

  AdminAuthState copyWith({
    bool? isUnlocked,
    DateTime? unlockedUntil,
    Duration? remainingLockout,
  }) {
    return AdminAuthState(
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedUntil: unlockedUntil ?? this.unlockedUntil,
      remainingLockout: remainingLockout ?? this.remainingLockout,
    );
  }
}

class AdminAuthController extends StateNotifier<AdminAuthState> {
  final PasswordService _passwordService;
  Timer? _lockTimer;
  Timer? _lockoutCheckTimer;
  bool _disposed = false;

  AdminAuthController(this._passwordService) : super(AdminAuthState());

  /// Start lockout countdown. Only call when the user is actually locked out.
  void _startLockoutChecks() {
    _lockoutCheckTimer?.cancel();
    _lockoutCheckTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_disposed) {
        timer.cancel();
        return;
      }
      final remaining = await _passwordService.getRemainingLockoutDuration();
      if (_disposed) return;
      state = state.copyWith(remainingLockout: remaining);
      if (remaining == Duration.zero) {
        timer.cancel();
      }
    });
  }

  /// Attempts to authenticate with the password.
  Future<bool> authenticate(String password) async {
    final settings = await _passwordService.getAdminSettings();
    if (settings == null) {
      // If no password is set, we auto-approve or direct to configuration
      return true;
    }

    if (await _passwordService.isLockedOut()) {
      return false;
    }

    final success = _passwordService.verifyPassword(password, settings.passwordHash);

    if (success) {
      await _passwordService.resetFailedAttempts();
      return true;
    } else {
      await _passwordService.recordFailedAttempt();
      final remaining = await _passwordService.getRemainingLockoutDuration();
      if (!_disposed) {
        state = state.copyWith(remainingLockout: remaining);
        if (remaining > Duration.zero) {
          _startLockoutChecks();
        }
      }
      return false;
    }
  }

  /// Unlocks the session for 2 minutes (configurable window)
  void unlockSession({Duration duration = const Duration(minutes: 2)}) {
    _lockTimer?.cancel();
    final expireAt = DateTime.now().add(duration);
    state = state.copyWith(
      isUnlocked: true,
      unlockedUntil: expireAt,
    );

    _lockTimer = Timer(duration, () {
      lockSession();
    });
  }

  /// Instantly locks the session
  void lockSession() {
    _lockTimer?.cancel();
    state = state.copyWith(
      isUnlocked: false,
      unlockedUntil: null,
    );
  }

  /// Checks if the session is currently validly unlocked.
  bool get hasActiveSession {
    if (!state.isUnlocked) return false;
    final until = state.unlockedUntil;
    if (until == null) return false;
    return DateTime.now().isBefore(until);
  }

  /// Helper to run a protected action.
  /// Prompts for password if not currently unlocked.
  Future<void> runProtectedAction(
    BuildContext context,
    FutureOr<void> Function() action,
  ) async {
    final isConfigured = (await _passwordService.getAdminSettings()) != null;
    if (!isConfigured) {
      // If no admin password is set yet, run action immediately
      await action();
      return;
    }

    if (hasActiveSession) {
      await action();
      return;
    }

    // Otherwise, show authentication dialog
    if (context.mounted) {
      final success = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const PasswordAuthDialog(),
      );

      if (success == true && context.mounted) {
        await action();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _lockTimer?.cancel();
    _lockoutCheckTimer?.cancel();
    super.dispose();
  }
}

// ── Admin Auth Provider ───────────────────────────────────────────────────
final adminAuthProvider = StateNotifierProvider<AdminAuthController, AdminAuthState>((ref) {
  final service = ref.watch(passwordServiceProvider);
  return AdminAuthController(service);
});
