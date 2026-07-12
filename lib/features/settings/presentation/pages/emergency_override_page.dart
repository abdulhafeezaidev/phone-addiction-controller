import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/service_providers.dart';
import '../../../../domain/models/emergency_override_state.dart';

class EmergencyOverridePage extends ConsumerStatefulWidget {
  const EmergencyOverridePage({super.key});

  @override
  ConsumerState<EmergencyOverridePage> createState() => _EmergencyOverridePageState();
}

class _EmergencyOverridePageState extends ConsumerState<EmergencyOverridePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  final _answerController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String? _challenge;
  EmergencyOverrideState? _state;
  Timer? _stateTimer;
  bool _isLoading = true;
  bool _showChallengeForm = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _onHoldSuccess();
      }
    });

    _loadState();
    _startPeriodicTimer();
  }

  void _startPeriodicTimer() {
    _stateTimer?.cancel();
    _stateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _state != null) {
        _updateState();
      }
    });
  }

  Future<void> _loadState() async {
    final service = ref.read(emergencyOverrideServiceProvider);
    final challenge = await service.getRecoveryChallenge();
    final state = await service.getOverrideState();
    if (mounted) {
      setState(() {
        _challenge = challenge;
        _state = state;
        _isLoading = false;
      });
    }
  }

  Future<void> _updateState() async {
    final service = ref.read(emergencyOverrideServiceProvider);
    await service.checkStateAndProgress();
    final state = await service.getOverrideState();
    if (mounted) {
      setState(() {
        _state = state;
      });
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    _answerController.dispose();
    _stateTimer?.cancel();
    super.dispose();
  }

  void _onHoldSuccess() {
    setState(() {
      _showChallengeForm = true;
      _progressController.reset();
    });
  }

  Future<void> _verifyAnswer() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _errorMessage = null;
    });

    final answer = _answerController.text;
    final service = ref.read(emergencyOverrideServiceProvider);
    final success = await service.verifyRecoveryAnswer(answer);

    if (success) {
      _answerController.clear();
      setState(() {
        _showChallengeForm = false;
      });
      await _updateState();
    } else {
      setState(() {
        _errorMessage = 'Incorrect answer or cooldown in effect.';
      });
    }
  }

  Future<void> _cancelReflection() async {
    final service = ref.read(emergencyOverrideServiceProvider);
    await service.cancelReflection();
    await _updateState();
  }

  Future<void> _deactivateOverride() async {
    final service = ref.read(emergencyOverrideServiceProvider);
    await service.deactivateOverride();
    await _updateState();
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF121414),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final tt = Theme.of(context).textTheme;
    final service = ref.read(emergencyOverrideServiceProvider);

    if (_challenge == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF121414),
        appBar: AppBar(title: const Text('Emergency Override')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              'Please set up an administrator password and recovery challenge in Settings first.',
              textAlign: TextAlign.center,
              style: tt.bodyLarge?.copyWith(color: const Color(0xFFC6C5D5)),
            ),
          ),
        ),
      );
    }

    final now = DateTime.now();

    // Calculate times
    Duration? reflectionRemaining;
    if (_state?.isInReflection == true && _state?.reflectionStartTime != null) {
      final elapsed = now.difference(_state!.reflectionStartTime!);
      final remaining = service.reflectionDuration - elapsed;
      reflectionRemaining = remaining > Duration.zero ? remaining : Duration.zero;
    }

    Duration? overrideRemaining;
    if (_state?.isOverrideActive == true && _state?.overrideStartTime != null) {
      final elapsed = now.difference(_state!.overrideStartTime!);
      final remaining = service.overrideDuration - elapsed;
      overrideRemaining = remaining > Duration.zero ? remaining : Duration.zero;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121414),
      appBar: AppBar(
        title: const Text('Emergency Override'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF5E6AD2)),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_state?.isOverrideActive == true)
                _buildActiveOverrideWidget(overrideRemaining ?? Duration.zero)
              else if (_state?.isInReflection == true)
                _buildReflectionWidget(reflectionRemaining ?? Duration.zero)
              else if (_showChallengeForm)
                _buildChallengeFormWidget()
              else
                _buildInitialTriggerWidget(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveOverrideWidget(Duration remaining) {
    final tt = Theme.of(context).textTheme;

    return Center(
      child: Column(
        children: [
          const SizedBox(height: 20),
          const Icon(Icons.gpp_maybe_rounded, color: Color(0xFFFFB867), size: 80),
          const SizedBox(height: 24),
          Text(
            'Emergency Override Active',
            style: tt.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: const Color(0xFFE3E2E2),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Focus protections are temporarily suspended.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFFC6C5D5), fontSize: 14),
          ),
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
            decoration: BoxDecoration(
              color: const Color(0xFF212123),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF2C2C2E)),
            ),
            child: Column(
              children: [
                Text(
                  _formatDuration(remaining),
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFFB867),
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Remaining Suspension Time',
                  style: TextStyle(color: Color(0xFFC6C5D5), fontSize: 12, letterSpacing: 1.1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5E6AD2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              onPressed: _deactivateOverride,
              icon: const Icon(Icons.lock_reset_rounded),
              label: const Text('Restore Protections Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReflectionWidget(Duration remaining) {
    final tt = Theme.of(context).textTheme;

    return Center(
      child: Column(
        children: [
          const SizedBox(height: 20),
          const Icon(Icons.hourglass_empty_rounded, color: Color(0xFF5E6AD2), size: 80),
          const SizedBox(height: 24),
          Text(
            'Reflection Period Active',
            style: tt.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: const Color(0xFFE3E2E2),
            ),
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'A reflection period reduces impulsive activation. Take a moment to consider if ending this session is necessary.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFC6C5D5), fontSize: 14, height: 1.4),
            ),
          ),
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
            decoration: BoxDecoration(
              color: const Color(0xFF212123),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF2C2C2E)),
            ),
            child: Column(
              children: [
                Text(
                  _formatDuration(remaining),
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF5E6AD2),
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Override Will Activate Automatically In',
                  style: TextStyle(color: Color(0xFFC6C5D5), fontSize: 12, letterSpacing: 1.1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFCF6679),
                side: const BorderSide(color: Color(0xFFCF6679)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              onPressed: _cancelReflection,
              icon: const Icon(Icons.close_rounded),
              label: const Text('Cancel Request & Keep Focusing', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChallengeFormWidget() {
    final tt = Theme.of(context).textTheme;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Text(
            'Recovery Challenge',
            style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: const Color(0xFFE3E2E2)),
          ),
          const SizedBox(height: 8),
          const Text(
            'Answer the recovery challenge challenge question accurately.',
            style: TextStyle(color: Color(0xFFC6C5D5), fontSize: 14),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF212123),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF2C2C2E)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Question:',
                  style: TextStyle(color: Color(0xFFC6C5D5), fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  _challenge ?? '',
                  style: tt.titleLarge?.copyWith(color: const Color(0xFFE3E2E2), fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _answerController,
                  obscureText: true,
                  style: const TextStyle(color: Color(0xFFE3E2E2)),
                  decoration: const InputDecoration(
                    hintText: 'Enter recovery answer',
                    prefixIcon: Icon(Icons.question_answer_outlined, color: Color(0xFFC6C5D5)),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'Answer is required';
                    }
                    return null;
                  },
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Color(0xFFCF6679), fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFC6C5D5),
                      side: const BorderSide(color: Color(0xFF2C2C2E)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    onPressed: () {
                      setState(() {
                        _showChallengeForm = false;
                        _errorMessage = null;
                        _answerController.clear();
                      });
                    },
                    child: const Text('Back', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5E6AD2),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    onPressed: _verifyAnswer,
                    child: const Text('Submit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInitialTriggerWidget() {
    final tt = Theme.of(context).textTheme;

    return Center(
      child: Column(
        children: [
          const SizedBox(height: 10),
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFCF6679), size: 64),
          const SizedBox(height: 20),
          Text(
            'Emergency Override',
            style: tt.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: const Color(0xFFE3E2E2),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFCF6679).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFCF6679).withValues(alpha: 0.2)),
            ),
            child: const Column(
              children: [
                Text(
                  'READ CAREFULLY',
                  style: TextStyle(color: Color(0xFFCF6679), fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.1),
                ),
                SizedBox(height: 12),
                Text(
                  'Emergency Override temporarily suspends all Focus protections for 24 hours. Use this ONLY for genuine emergencies. Impulsive use bypasses the self-control benefits of this application.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFFC6C5D5), fontSize: 13, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 60),
          GestureDetector(
            onLongPressStart: (_) {
              _progressController.forward();
            },
            onLongPressEnd: (_) {
              if (_progressController.status != AnimationStatus.completed) {
                _progressController.reverse();
              }
            },
            child: AnimatedBuilder(
              animation: _progressController,
              builder: (context, child) {
                return Container(
                  width: 160,
                  height: 160,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF212123),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 150,
                        height: 150,
                        child: CircularProgressIndicator(
                          value: _progressController.value,
                          strokeWidth: 6,
                          color: const Color(0xFFCF6679),
                          backgroundColor: const Color(0xFF2C2C2E),
                        ),
                      ),
                      const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.touch_app_rounded, color: Color(0xFFCF6679), size: 36),
                          SizedBox(height: 8),
                          Text(
                            'Hold 3 Seconds',
                            style: TextStyle(color: Color(0xFFE3E2E2), fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'To Unlock',
                            style: TextStyle(color: Color(0xFFC6C5D5), fontSize: 10),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
