import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/service_providers.dart';
import '../../../../core/providers/admin_auth_provider.dart';

class AdminPasswordPage extends ConsumerStatefulWidget {
  const AdminPasswordPage({super.key});

  @override
  ConsumerState<AdminPasswordPage> createState() => _AdminPasswordPageState();
}

class _AdminPasswordPageState extends ConsumerState<AdminPasswordPage> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _recoveryChallengeController = TextEditingController();
  final _recoveryAnswerController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _hasExistingPassword = false;
  bool _isLoading = true;
  bool _showForm = false;

  @override
  void initState() {
    super.initState();
    _checkPasswordStatus();
  }

  Future<void> _checkPasswordStatus() async {
    final passwordService = ref.read(passwordServiceProvider);
    final settings = await passwordService.getAdminSettings();
    if (mounted) {
      setState(() {
        _hasExistingPassword = settings != null;
        _isLoading = false;
        // Auto-show form if no password is set yet
        _showForm = settings == null;
      });
    }
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _recoveryChallengeController.dispose();
    _recoveryAnswerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF121414),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: const Color(0xFF121414),
      appBar: AppBar(
        title: const Text('Administrator'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF5E6AD2)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Password Status Card (Stitch design)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF212123),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFF2C2C2E), width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Password Status',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFE3E2E2),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _hasExistingPassword ? 'Currently protected' : 'Not protected',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFFC6C5D5),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFF5E6AD2).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.lock_rounded,
                              color: Color(0xFF5E6AD2),
                              size: 26,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Column(
                        children: [
                          if (_hasExistingPassword) ...[
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF5E6AD2),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _showForm = !_showForm;
                                  });
                                },
                                child: Text(
                                  _showForm ? 'Hide Password Form' : 'Change Password',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFCF6679),
                                  side: const BorderSide(color: Color(0xFF2C2C2E)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed: _removePassword,
                                child: const Text(
                                  'Remove Password',
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                                ),
                              ),
                            ),
                          ] else ...[
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF5E6AD2),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _showForm = true;
                                  });
                                },
                                child: const Text(
                                  'Set Administrator Password',
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Password Inputs Form Card (Animates visible)
                if (_showForm)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF212123),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFF2C2C2E), width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _hasExistingPassword ? 'Change Password' : 'Set New Password',
                          style: tt.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFE3E2E2),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Current Password (if already exists)
                        if (_hasExistingPassword) ...[
                          const Text('Current Password', style: TextStyle(color: Color(0xFFC6C5D5), fontSize: 12)),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _currentPasswordController,
                            obscureText: _obscureCurrent,
                            style: const TextStyle(color: Color(0xFFE3E2E2)),
                            decoration: InputDecoration(
                              hintText: 'Enter current password',
                              prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFFC6C5D5)),
                              suffixIcon: IconButton(
                                icon: Icon(_obscureCurrent ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: const Color(0xFFC6C5D5)),
                                onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                              ),
                            ),
                            validator: (val) {
                              if (_hasExistingPassword && (val == null || val.isEmpty)) {
                                return 'Please enter your current password';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                        ],

                        // New Password
                        const Text('New Password', style: TextStyle(color: Color(0xFFC6C5D5), fontSize: 12)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _newPasswordController,
                          obscureText: _obscureNew,
                          style: const TextStyle(color: Color(0xFFE3E2E2)),
                          decoration: InputDecoration(
                            hintText: 'Enter new password (min. 6 characters)',
                            prefixIcon: const Icon(Icons.lock_rounded, color: Color(0xFFC6C5D5)),
                            suffixIcon: IconButton(
                              icon: Icon(_obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: const Color(0xFFC6C5D5)),
                              onPressed: () => setState(() => _obscureNew = !_obscureNew),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Confirm Password
                        const Text('Confirm Password', style: TextStyle(color: Color(0xFFC6C5D5), fontSize: 12)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirm,
                          style: const TextStyle(color: Color(0xFFE3E2E2)),
                          decoration: InputDecoration(
                            hintText: 'Re-enter new password',
                            prefixIcon: const Icon(Icons.lock_reset_rounded, color: Color(0xFFC6C5D5)),
                            suffixIcon: IconButton(
                              icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: const Color(0xFFC6C5D5)),
                              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                            ),
                          ),
                          validator: (val) {
                            if (val != _newPasswordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Recovery Challenge
                        const Text('Recovery Challenge (Question)', style: TextStyle(color: Color(0xFFC6C5D5), fontSize: 12)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _recoveryChallengeController,
                          style: const TextStyle(color: Color(0xFFE3E2E2)),
                          decoration: const InputDecoration(
                            hintText: 'e.g. My mother\'s maiden name',
                            prefixIcon: Icon(Icons.help_outline_rounded, color: Color(0xFFC6C5D5)),
                          ),
                          validator: (val) {
                            if (val == null || val.isEmpty) {
                              return 'Recovery challenge is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Recovery Answer
                        const Text('Recovery Answer', style: TextStyle(color: Color(0xFFC6C5D5), fontSize: 12)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _recoveryAnswerController,
                          obscureText: true,
                          style: const TextStyle(color: Color(0xFFE3E2E2)),
                          decoration: const InputDecoration(
                            hintText: 'Enter answer for emergency override',
                            prefixIcon: Icon(Icons.question_answer_rounded, color: Color(0xFFC6C5D5)),
                          ),
                          validator: (val) {
                            if (val == null || val.isEmpty) {
                              return 'Recovery answer is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        // Save Button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF5E6AD2),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            onPressed: _savePassword,
                            child: Text(
                              _hasExistingPassword ? 'Update Password' : 'Save Password',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 300.ms),

                const SizedBox(height: 24),

                // Danger Zone Info (Stitch design)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCF6679).withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFCF6679).withValues(alpha: 0.3), width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.warning_amber_rounded, color: Color(0xFFCF6679), size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Warning / Disclaimer',
                            style: TextStyle(
                              color: Color(0xFFCF6679),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'If you forget your administrator password, you will not be able to change settings or bypass focus screens. Please keep it secure.',
                        style: TextStyle(color: Color(0xFFC6C5D5), fontSize: 12, height: 1.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _savePassword() async {
    if (_formKey.currentState!.validate()) {
      final passwordService = ref.read(passwordServiceProvider);

      if (_hasExistingPassword) {
        final settings = await passwordService.getAdminSettings();
        if (settings != null) {
          final isCorrect = passwordService.verifyPassword(
            _currentPasswordController.text,
            settings.passwordHash,
          );
          if (!isCorrect) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Incorrect current password'),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
            return;
          }
        }
      }

      // Capture values and clear controllers immediately to minimize
      // time plain-text passwords spend in memory.
      final newPassword = _newPasswordController.text;
      final challenge = _recoveryChallengeController.text;
      final answer = _recoveryAnswerController.text;
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      _recoveryChallengeController.clear();
      _recoveryAnswerController.clear();

      await passwordService.setPassword(newPassword);
      final overrideService = ref.read(emergencyOverrideServiceProvider);
      await overrideService.setRecoveryChallenge(challenge, answer);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password and recovery challenge updated successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {
          _hasExistingPassword = true;
          _showForm = false;
        });
      }
    }
  }

  void _removePassword() {
    final removePasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Password?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'This will disable administrator protection. Enter your current password to confirm.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: removePasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: 'Current password',
                prefixIcon: Icon(Icons.lock_outline_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFCF6679),
            ),
            onPressed: () async {
              final enteredPassword = removePasswordController.text;

              if (enteredPassword.isEmpty) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Password is required to remove protection'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
                return;
              }

              try {
                final passwordService = ref.read(passwordServiceProvider);
                final settings = await passwordService.getAdminSettings();

                if (settings != null) {
                  final isCorrect = passwordService.verifyPassword(
                    enteredPassword,
                    settings.passwordHash,
                  );
                  if (!isCorrect) {
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Password is incorrect'),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                    return;
                  }
                }

                await ref.read(storageServiceProvider).delete(
                  AppConstants.adminSettingsBox,
                  AppConstants.adminPasswordKey,
                );

                if (ctx.mounted) Navigator.pop(ctx);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Password removed successfully'),
                      backgroundColor: Color(0xFF4CAF7D),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  setState(() {
                    _hasExistingPassword = false;
                    _showForm = false;
                    _currentPasswordController.clear();
                  });
                }
              } catch (_) {
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Something went wrong. Please try again.'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    ).then((_) {
      removePasswordController.dispose();
    });
  }
}
