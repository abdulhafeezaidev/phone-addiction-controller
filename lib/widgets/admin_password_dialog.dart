import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/app_providers.dart';
import '../core/theme/focus_tokens.dart';

/// Modal dialog that enforces Admin Authorization before executing protected actions.
/// Reminds the user to have their designated accountability partner enter the password.
class AdminPasswordDialog extends ConsumerStatefulWidget {
  const AdminPasswordDialog({
    super.key,
    this.actionDescription,
  });

  /// Optional phrase describing the protected action (e.g. "end focus session early", "uninstall app").
  final String? actionDescription;

  /// Shows the dialog and returns `true` if authorized, or `false`/`null` if cancelled/denied.
  static Future<bool> show(
    BuildContext context, {
    String? actionDescription,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AdminPasswordDialog(actionDescription: actionDescription),
    );
    return result ?? false;
  }

  @override
  ConsumerState<AdminPasswordDialog> createState() => _AdminPasswordDialogState();
}

class _AdminPasswordDialogState extends ConsumerState<AdminPasswordDialog> {
  final _passwordController = TextEditingController();
  bool _obscureText = true;
  bool _isLoading = false;
  String? _errorMessage;
  int _remainingLockoutSeconds = 0;
  Timer? _lockoutTimer;

  @override
  void initState() {
    super.initState();
    _checkLockout();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _lockoutTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkLockout() async {
    final passwordService = ref.read(passwordServiceProvider);
    final remaining = await passwordService.getRemainingLockoutDuration();
    if (remaining.inSeconds > 0) {
      setState(() {
        _remainingLockoutSeconds = remaining.inSeconds;
        _errorMessage = 'Locked out. Try again in $_remainingLockoutSeconds s.';
      });
      _startLockoutCountdown();
    }
  }

  void _startLockoutCountdown() {
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingLockoutSeconds <= 1) {
        timer.cancel();
        setState(() {
          _remainingLockoutSeconds = 0;
          _errorMessage = null;
        });
      } else {
        setState(() {
          _remainingLockoutSeconds--;
          _errorMessage = 'Locked out. Try again in $_remainingLockoutSeconds s.';
        });
      }
    });
  }

  Future<void> _verifyPassword() async {
    if (_remainingLockoutSeconds > 0) return;

    final input = _passwordController.text.trim();
    if (input.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter the admin password.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final passwordService = ref.read(passwordServiceProvider);

    try {
      final isLocked = await passwordService.isLockedOut();
      if (isLocked) {
        await _checkLockout();
        setState(() => _isLoading = false);
        return;
      }

      final adminSettings = await passwordService.getAdminSettings();
      if (adminSettings == null || adminSettings.passwordHash.isEmpty) {
        setState(() {
          _errorMessage = 'No admin password configured. Please complete setup first.';
          _isLoading = false;
        });
        return;
      }

      final isValid = passwordService.verifyPassword(input, adminSettings.passwordHash);
      if (isValid) {
        await passwordService.resetFailedAttempts();
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        final updated = await passwordService.recordFailedAttempt();
        final remainingAttempts = updated.maxFailedAttempts - updated.failedAttemptCount;

        if (remainingAttempts <= 0) {
          await _checkLockout();
        } else {
          setState(() {
            _errorMessage = 'Incorrect password. $remainingAttempts attempt${remainingAttempts == 1 ? '' : 's'} remaining.';
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Verification failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final adminAsync = ref.watch(adminSettingsProvider);
    final adminSettings = adminAsync.valueOrNull;

    final adminName = adminSettings?.adminName?.trim().isNotEmpty == true
        ? adminSettings!.adminName!.trim()
        : 'Accountability Partner';
    final adminContact = adminSettings?.adminContact?.trim().isNotEmpty == true
        ? ' (${adminSettings!.adminContact!.trim()})'
        : '';

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: FocusTokens.borderRadiusCard,
      ),
      backgroundColor: FocusTokens.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Icon Header
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: FocusTokens.primarySoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.security_rounded,
                    color: FocusTokens.primary,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              const Text(
                'Admin Authorization',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: FocusTokens.ink,
                ),
              ),
              const SizedBox(height: 8),

              // Description reminding user of accountability partner
              Text(
                widget.actionDescription != null
                    ? 'To ${widget.actionDescription}, please have your partner enter their password.'
                    : 'This action is locked. Please hand your phone to your accountability partner to enter their password.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: FocusTokens.inkMuted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),

              // Admin badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: FocusTokens.elevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: FocusTokens.divider),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.person_rounded,
                      size: 18,
                      color: FocusTokens.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Admin: $adminName$adminContact',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: FocusTokens.ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Password text field
              TextField(
                controller: _passwordController,
                obscureText: _obscureText,
                enabled: !_isLoading && _remainingLockoutSeconds == 0,
                autofocus: true,
                keyboardType: TextInputType.visiblePassword,
                onSubmitted: (_) => _verifyPassword(),
                decoration: InputDecoration(
                  hintText: 'Enter Admin Password',
                  hintStyle: const TextStyle(color: FocusTokens.inkMuted, fontSize: 14),
                  filled: true,
                  fillColor: FocusTokens.elevated,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: FocusTokens.primary, width: 1.5),
                  ),
                  prefixIcon: const Icon(Icons.lock_outline_rounded, color: FocusTokens.inkMuted),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: FocusTokens.inkMuted,
                    ),
                    onPressed: () => setState(() => _obscureText = !_obscureText),
                  ),
                ),
              ),

              // Error or lockout message
              if (_errorMessage != null) ...[
                const SizedBox(height: 10),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: FocusTokens.danger,
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        side: const BorderSide(color: FocusTokens.divider),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: FocusTokens.ink,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (_isLoading || _remainingLockoutSeconds > 0) ? null : _verifyPassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FocusTokens.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Authorize',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
