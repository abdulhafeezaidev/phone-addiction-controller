import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/focus_providers.dart';
import '../../../../core/providers/service_providers.dart';
import '../../../../core/constants/route_names.dart';
import 'package:go_router/go_router.dart';

/// Focus Lock Screen — a pure black OLED-friendly lock experience.
///
/// Displays a large centered clock, date, optional session title,
/// and a swipe-up indicator. After swipe, shows a numeric PIN screen.
/// On correct PIN, navigates to Focus Home.
class FocusLockScreen extends ConsumerStatefulWidget {
  const FocusLockScreen({super.key});

  @override
  ConsumerState<FocusLockScreen> createState() => _FocusLockScreenState();
}

class _FocusLockScreenState extends ConsumerState<FocusLockScreen>
    with SingleTickerProviderStateMixin {
  late Timer _clockTimer;
  DateTime _now = DateTime.now();
  bool _showPinScreen = false;
  String _pinEntry = '';
  String _pinError = '';
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    // Update clock every second
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Immersive full-screen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _pulseController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _onSwipeUp() {
    final pinService = ref.read(focusLockPinServiceProvider);
    if (!pinService.isPinSet()) {
      _unlock();
      return;
    }
    setState(() {
      _showPinScreen = true;
      _pinEntry = '';
      _pinError = '';
    });
  }

  Future<void> _onPinDigit(String digit) async {
    if (_pinEntry.length >= 6) return;
    setState(() {
      _pinEntry += digit;
      _pinError = '';
    });

    // Auto-verify when PIN reaches expected length (4-6 digits)
    if (_pinEntry.length >= 4) {
      await _verifyPin();
    }
  }

  void _onPinBackspace() {
    if (_pinEntry.isEmpty) return;
    setState(() {
      _pinEntry = _pinEntry.substring(0, _pinEntry.length - 1);
      _pinError = '';
    });
  }

  Future<void> _verifyPin() async {
    final pinService = ref.read(focusLockPinServiceProvider);

    if (!pinService.isPinSet()) {
      // No PIN set — allow through
      _unlock();
      return;
    }

    if (await pinService.verifyPin(_pinEntry)) {
      _unlock();
    } else {
      setState(() {
        _pinError = 'Incorrect PIN';
        _pinEntry = '';
      });
      HapticFeedback.heavyImpact();
    }
  }

  void _unlock() {
    if (mounted) {
      context.go(RouteNames.focusSession);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerMove: (PointerMoveEvent event) {
          if (!_showPinScreen && event.delta.dy < -12) {
            _onSwipeUp();
          }
        },
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (child, animation) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.15),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: _showPinScreen ? _buildPinScreen() : _buildClockScreen(),
        ),
      ),
    );
  }

  Widget _buildClockScreen() {
    final timeStr = '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}';
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    final dateStr = '${weekdays[_now.weekday - 1]}, ${months[_now.month - 1]} ${_now.day}';

    return SizedBox.expand(
      key: const ValueKey('clock'),
      child: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 3),
            // Clock
            Text(
              timeStr,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 80,
                fontWeight: FontWeight.w200,
                fontFamily: 'Inter',
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 8),
            // Date
            Text(
              dateStr,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 16,
                fontWeight: FontWeight.w400,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 24),
            // Session title
            _buildSessionTitle(),
            const Spacer(flex: 4),
            // Swipe up indicator
            FadeTransition(
              opacity: _pulseAnimation,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.keyboard_arrow_up_rounded,
                    color: Colors.white.withValues(alpha: 0.5),
                    size: 32,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Swipe up to unlock',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionTitle() {
    // Show the active routine name if available
    return Consumer(
      builder: (context, ref, _) {
        final isFocusActive = ref.watch(focusModeProvider);
        if (!isFocusActive) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF5E6AD2).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF5E6AD2).withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF5E6AD2),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Focus Mode Active',
                style: TextStyle(
                  color: Color(0xFF5E6AD2),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPinScreen() {
    return SizedBox.expand(
      key: const ValueKey('pin'),
      child: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            // Lock icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF5E6AD2).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_rounded,
                color: Color(0xFF5E6AD2),
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Enter PIN',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 22,
                fontWeight: FontWeight.w600,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter your Focus Lock PIN to unlock',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 13,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 32),
            // PIN dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (index) {
                final filled = index < _pinEntry.length;
                return Container(
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled
                        ? const Color(0xFF5E6AD2)
                        : Colors.transparent,
                    border: Border.all(
                      color: _pinError.isNotEmpty
                          ? const Color(0xFFCF6679)
                          : const Color(0xFF5E6AD2).withValues(alpha: 0.5),
                      width: 2,
                    ),
                  ),
                );
              }),
            ),
            if (_pinError.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                _pinError,
                style: const TextStyle(
                  color: Color(0xFFCF6679),
                  fontSize: 13,
                  fontFamily: 'Inter',
                ),
              ),
            ],
            const SizedBox(height: 40),
            // Numeric keypad
            _buildKeypad(),
            const Spacer(),
            // Back button
            TextButton(
              onPressed: () => setState(() => _showPinScreen = false),
              child: Text(
                'Back',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 14,
                  fontFamily: 'Inter',
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];

    return Column(
      children: keys.map((row) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((key) {
              if (key.isEmpty) {
                return const SizedBox(width: 80, height: 64);
              }
              return _buildKeypadButton(key);
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildKeypadButton(String key) {
    final isBackspace = key == '⌫';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(40),
          onTap: () {
            HapticFeedback.lightImpact();
            if (isBackspace) {
              _onPinBackspace();
            } else {
              _onPinDigit(key);
            }
          },
          child: Container(
            width: 72,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isBackspace
                  ? Colors.transparent
                  : Colors.white.withValues(alpha: 0.06),
            ),
            child: isBackspace
                ? Icon(
                    Icons.backspace_outlined,
                    color: Colors.white.withValues(alpha: 0.7),
                    size: 24,
                  )
                : Text(
                    key,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w300,
                      fontFamily: 'Inter',
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
