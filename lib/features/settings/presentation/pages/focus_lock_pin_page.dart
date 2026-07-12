import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/service_providers.dart';

class FocusLockPinPage extends ConsumerStatefulWidget {
  const FocusLockPinPage({super.key});

  @override
  ConsumerState<FocusLockPinPage> createState() => _FocusLockPinPageState();
}

class _FocusLockPinPageState extends ConsumerState<FocusLockPinPage> {
  final _formKey = GlobalKey<FormState>();
  final _currentPinController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _currentPinController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _savePin() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final pinService = ref.read(focusLockPinServiceProvider);
    
    // If a PIN is already set, verify the current PIN first
    if (pinService.isPinSet()) {
      final isValid = await pinService.verifyPin(_currentPinController.text);
      if (!isValid) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Incorrect current PIN.';
        });
        return;
      }
    }

    await pinService.setPin(_newPinController.text);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Focus Lock PIN saved successfully!')),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pinService = ref.watch(focusLockPinServiceProvider);
    final hasExistingPin = pinService.isPinSet();

    return Scaffold(
      appBar: AppBar(title: const Text('Focus Lock PIN')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const Text(
                'This PIN is used exclusively to unlock the device screen during an active Focus Session.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              
              if (hasExistingPin) ...[
                TextFormField(
                  controller: _currentPinController,
                  obscureText: _obscureCurrent,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Current PIN',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureCurrent ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Current PIN is required';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],
              
              TextFormField(
                controller: _newPinController,
                obscureText: _obscureNew,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'New PIN',
                  prefixIcon: const Icon(Icons.lock_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscureNew = !_obscureNew),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'New PIN is required';
                  if (val.length < 4) return 'PIN must be at least 4 digits';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _confirmPinController,
                obscureText: _obscureConfirm,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Confirm New PIN',
                  prefixIcon: const Icon(Icons.lock_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Please confirm your PIN';
                  if (val != _newPinController.text) return 'PINs do not match';
                  return null;
                },
              ),
              const SizedBox(height: 32),
              
              ElevatedButton(
                onPressed: _isSaving ? null : _savePin,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save PIN'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
