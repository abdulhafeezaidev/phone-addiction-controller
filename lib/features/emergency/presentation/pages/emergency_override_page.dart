import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/focus_tokens.dart';
import '../../../../domain/models/emergency_override_state.dart';

class EmergencyOverridePage extends ConsumerStatefulWidget {
  const EmergencyOverridePage({super.key});

  @override
  ConsumerState<EmergencyOverridePage> createState() => _EmergencyOverridePageState();
}

class _EmergencyOverridePageState extends ConsumerState<EmergencyOverridePage> {
  final _answerController = TextEditingController();
  bool _isLoading = false;
  String? _challengeQuestion;
  String? _errorMessage;
  EmergencyOverrideState _overrideState = EmergencyOverrideState();
  Timer? _refreshTimer;

  // Hold-to-confirm progress
  double _holdProgress = 0.0;
  Timer? _holdTimer;

  @override
  void initState() {
    super.initState();
    _loadState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _checkProgress();
    });
  }

  @override
  void dispose() {
    _answerController.dispose();
    _refreshTimer?.cancel();
    _holdTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadState() async {
    final emergencyService = ref.read(emergencyOverrideServiceProvider);
    final question = await emergencyService.getRecoveryChallenge();
    final state = await emergencyService.getOverrideState();

    if (mounted) {
      setState(() {
        _challengeQuestion = question;
        _overrideState = state;
      });
    }
  }

  Future<void> _checkProgress() async {
    final emergencyService = ref.read(emergencyOverrideServiceProvider);
    await emergencyService.checkStateAndProgress();
    final state = await emergencyService.getOverrideState();
    if (mounted) {
      setState(() => _overrideState = state);
    }
  }

  bool _isInCooldown() {
    final lastActivation = _overrideState.lastActivationTime;
    if (lastActivation == null) return false;
    final cooldownDuration = ref.read(emergencyOverrideServiceProvider).cooldownDuration;
    return DateTime.now().difference(lastActivation) < cooldownDuration;
  }

  Duration _remainingCooldown() {
    final lastActivation = _overrideState.lastActivationTime;
    if (lastActivation == null) return Duration.zero;
    final cooldownDuration = ref.read(emergencyOverrideServiceProvider).cooldownDuration;
    final remaining = cooldownDuration - DateTime.now().difference(lastActivation);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  void _startHolding() {
    if (_isInCooldown()) {
      final rem = _remainingCooldown();
      final hours = rem.inHours;
      final mins = rem.inMinutes.remainder(60);
      setState(() => _errorMessage =
          'Cooldown active. Please wait ${hours > 0 ? '${hours}h ' : ''}${mins}m before requesting another override.');
      return;
    }
    if (_answerController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter your emergency answer first.');
      return;
    }

    setState(() {
      _errorMessage = null;
      _holdProgress = 0.0;
    });

    _holdTimer?.cancel();
    const intervalMs = 50;
    const totalMs = 3000; // 3 seconds hold
    const step = intervalMs / totalMs;

    _holdTimer = Timer.periodic(const Duration(milliseconds: intervalMs), (timer) {
      if (_holdProgress + step >= 1.0) {
        timer.cancel();
        setState(() => _holdProgress = 1.0);
        _submitAnswer();
      } else {
        setState(() => _holdProgress += step);
      }
    });
  }

  void _cancelHolding() {
    _holdTimer?.cancel();
    if (_holdProgress < 1.0) {
      setState(() => _holdProgress = 0.0);
    }
  }

  Future<void> _submitAnswer() async {
    setState(() => _isLoading = true);
    final emergencyService = ref.read(emergencyOverrideServiceProvider);

    try {
      final success = await emergencyService.verifyRecoveryAnswer(_answerController.text.trim());
      if (success) {
        _answerController.clear();
        await _loadState();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Verified. Reflection period initiated.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        setState(() {
          _errorMessage = 'Incorrect answer or active cooldown period.';
          _holdProgress = 0.0;
        });
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cancelReflection() async {
    final emergencyService = ref.read(emergencyOverrideServiceProvider);
    await emergencyService.cancelReflection();
    await _loadState();
  }

  Future<void> _endOverride() async {
    final emergencyService = ref.read(emergencyOverrideServiceProvider);
    await emergencyService.deactivateOverride();
    ref.invalidate(focusSessionProvider);
    await _loadState();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Emergency override deactivated. Detox restored.')),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FocusTokens.canvas,
      appBar: AppBar(
        title: const Text(
          'Emergency Override',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: FocusTokens.ink,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── State Banner ─────────────────────────────────────────────────
            if (_overrideState.isOverrideActive)
              _buildOverrideActiveCard()
            else if (_overrideState.isInReflection)
              _buildReflectionActiveCard()
            else
              _buildRequestForm(),
          ],
        ),
      ),
    );
  }

  // ── Override Currently Active ───────────────────────────────────────────────

  Widget _buildOverrideActiveCard() {
    final emergencyService = ref.read(emergencyOverrideServiceProvider);
    final overrideDuration = emergencyService.overrideDuration;
    final start = _overrideState.overrideStartTime ?? DateTime.now();
    final elapsed = DateTime.now().difference(start);
    final remaining = overrideDuration - elapsed;
    final remainingSecs = remaining.isNegative ? 0 : remaining.inSeconds;
    final mins = (remainingSecs ~/ 60).toString().padLeft(2, '0');
    final secs = (remainingSecs % 60).toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: FocusTokens.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FocusTokens.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: FocusTokens.warning.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_open_rounded, color: FocusTokens.warning, size: 32),
          ),
          const SizedBox(height: 16),
          const Text(
            'Emergency Access Active',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: FocusTokens.ink),
          ),
          const SizedBox(height: 8),
          const Text(
            'Focus protections and app blocks are temporarily bypassed.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: FocusTokens.inkMuted),
          ),
          const SizedBox(height: 16),
          Text(
            '$mins:$secs',
            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: FocusTokens.warning),
          ),
          const SizedBox(height: 4),
          const Text(
            'Remaining access window',
            style: TextStyle(fontSize: 12, color: FocusTokens.inkMuted),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _endOverride,
              style: ElevatedButton.styleFrom(
                backgroundColor: FocusTokens.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('End Emergency Access & Re-Guard', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Reflection Timer Active ────────────────────────────────────────────────

  Widget _buildReflectionActiveCard() {
    final emergencyService = ref.read(emergencyOverrideServiceProvider);
    final reflectionDuration = emergencyService.reflectionDuration;
    final start = _overrideState.reflectionStartTime ?? DateTime.now();
    final elapsed = DateTime.now().difference(start);
    final remaining = reflectionDuration - elapsed;
    final remainingSecs = remaining.isNegative ? 0 : remaining.inSeconds;
    final mins = (remainingSecs ~/ 60).toString().padLeft(2, '0');
    final secs = (remainingSecs % 60).toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: FocusTokens.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FocusTokens.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.hourglass_top_rounded, color: FocusTokens.primary, size: 36),
          const SizedBox(height: 16),
          const Text(
            'Reflection Period in Progress',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: FocusTokens.ink),
          ),
          const SizedBox(height: 8),
          Text(
            'To deter impulsive phone usage, a ${reflectionDuration.inMinutes}-minute buffer is required before access unlocks.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: FocusTokens.inkMuted, height: 1.4),
          ),
          const SizedBox(height: 20),
          Text(
            '$mins:$secs',
            style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: FocusTokens.ink),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton(
              onPressed: _cancelReflection,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: FocusTokens.divider),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Cancel Request', style: TextStyle(fontWeight: FontWeight.w600, color: FocusTokens.ink)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Request Form ───────────────────────────────────────────────────────────

  Widget _buildRequestForm() {
    final emergencyService = ref.read(emergencyOverrideServiceProvider);
    final reflectionMins = emergencyService.reflectionDuration.inMinutes;
    final inCooldown = _isInCooldown();
    final remainingCooldown = _remainingCooldown();
    final cooldownHours = remainingCooldown.inHours;
    final cooldownMins = remainingCooldown.inMinutes.remainder(60);
    final isDefaultQuestion =
        _challengeQuestion == 'Why are you requesting an emergency override right now?';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: FocusTokens.warning.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded, color: FocusTokens.warning, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Emergency Override is designed strictly for urgent real-life crises when your accountability partner cannot be reached. It involves a $reflectionMins-minute reflection delay.',
                  style: const TextStyle(fontSize: 12, color: FocusTokens.ink, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        if (inCooldown) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: FocusTokens.danger.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: FocusTokens.danger.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer_off_outlined, color: FocusTokens.danger, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Cooldown active: ${cooldownHours > 0 ? '${cooldownHours}h ' : ''}${cooldownMins}m remaining before another emergency request can be initiated.',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: FocusTokens.danger,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),

        // Challenge Question
        const Text(
          'Security Question',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: FocusTokens.ink),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: FocusTokens.elevated,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _challengeQuestion ?? 'Loading question...',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: FocusTokens.ink),
          ),
        ),
        if (isDefaultQuestion) ...[
          const SizedBox(height: 6),
          const Text(
            'No custom security question set yet. Default phrase: "I need emergency access"',
            style: TextStyle(fontSize: 11, color: FocusTokens.inkMuted),
          ),
        ],
        const SizedBox(height: 16),

        // Answer
        const Text(
          'Security Answer',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: FocusTokens.ink),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _answerController,
          enabled: !inCooldown,
          decoration: InputDecoration(
            hintText: isDefaultQuestion ? 'I need emergency access' : 'Enter your answer',
            filled: true,
            fillColor: FocusTokens.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),

        if (_errorMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            _errorMessage!,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: FocusTokens.danger),
          ),
        ],
        const SizedBox(height: 24),

        // Hold-to-Confirm Button
        GestureDetector(
          onTapDown: (_) => _startHolding(),
          onTapUp: (_) => _cancelHolding(),
          onTapCancel: () => _cancelHolding(),
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: FocusTokens.elevated,
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                // Filling Progress bar
                FractionallySizedBox(
                  widthFactor: _holdProgress,
                  alignment: Alignment.centerLeft,
                  child: Container(color: FocusTokens.warning),
                ),
                Center(
                  child: _isLoading
                      ? const CircularProgressIndicator(strokeWidth: 2)
                      : Text(
                          inCooldown
                              ? 'Cooldown Active'
                              : _holdProgress > 0
                                  ? 'Holding... ${(_holdProgress * 100).toInt()}%'
                                  : 'Press & Hold (3s) to Verify',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: inCooldown
                                ? FocusTokens.inkMuted
                                : (_holdProgress > 0.5 ? Colors.white : FocusTokens.ink),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
