 import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers/admin_auth_provider.dart';

class PasswordAuthDialog extends ConsumerStatefulWidget {
  const PasswordAuthDialog({super.key});

  @override
  ConsumerState<PasswordAuthDialog> createState() => _PasswordAuthDialogState();
}

class _PasswordAuthDialogState extends ConsumerState<PasswordAuthDialog> {
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscureText = true;
  String? _errorMessage;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final password = _passwordController.text;
    final authNotifier = ref.read(adminAuthProvider.notifier);
    final success = await authNotifier.authenticate(password);

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.pop(context, true);
      } else {
        setState(() {
          _errorMessage = 'Incorrect administrator password';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(adminAuthProvider);
    final isLocked = authState.remainingLockout > Duration.zero;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.security_rounded, color: cs.primary),
          const SizedBox(width: 12),
          const Text('Admin Verification'),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your administrator password to unlock this protected action.',
            ),
            const SizedBox(height: 20),
            if (isLocked)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Too many failed attempts. Locked out for ${authState.remainingLockout.inSeconds}s.',
                  style: tt.bodySmall?.copyWith(color: cs.onErrorContainer, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              )
            else
              TextFormField(
                controller: _passwordController,
                obscureText: _obscureText,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Password',
                  errorText: _errorMessage,
                  prefixIcon: const Icon(Icons.lock_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    onPressed: () => setState(() => _obscureText = !_obscureText),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) {
                    return 'Password is required';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _submit(),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: (isLocked || _isSubmitting) ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Unlock'),
        ),
      ],
    );
  }
}
