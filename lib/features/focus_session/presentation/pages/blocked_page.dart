import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/admin_auth_provider.dart';
import '../../../../core/providers/focus_providers.dart';
import '../../../../core/providers/service_providers.dart';
import '../../../../core/constants/route_names.dart';
import '../../../../core/router/app_router.dart';

class BlockedPage extends ConsumerStatefulWidget {
  final String appName;

  const BlockedPage({super.key, required this.appName});

  @override
  ConsumerState<BlockedPage> createState() => _BlockedPageState();
}

class _BlockedPageState extends ConsumerState<BlockedPage> {
  Timer? _timer;
  Duration _remaining = const Duration(minutes: 25);
  DateTime? _endTime;

  @override
  void initState() {
    super.initState();
    _checkActiveSession();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkActiveSession() async {
    final service = ref.read(sessionTrackingServiceProvider);
    final session = await service.getActiveSession();
    if (session != null) {
      final elapsed = DateTime.now().difference(session.startTime);
      final target = const Duration(minutes: 25);
      final rem = target - elapsed;
      if (mounted) {
        setState(() {
          _remaining = rem > Duration.zero ? rem : Duration.zero;
          _endTime = session.startTime.add(target);
        });
        _startCountdown();
      }
    }
  }

  void _startCountdown() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remaining.inSeconds > 0) {
        setState(() {
          _remaining -= const Duration(seconds: 1);
        });
      } else {
        _timer?.cancel();
      }
    });
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF121414),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),

              // Blocked App Icon Container (Top 1/3)
              Center(
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: const Color(0xFF212123),
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(color: const Color(0xFF2C2C2E), width: 1),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              )
                            ],
                          ),
                          child: const Icon(
                            Icons.block_rounded,
                            size: 64,
                            color: Color(0xFFCF6679),
                          ),
                        ),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E2020),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF121414), width: 2),
                          ),
                          child: const Icon(
                            Icons.apps_rounded,
                            size: 18,
                            color: Color(0xFF5E6AD2),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Application Unavailable',
                      style: tt.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 24,
                        color: const Color(0xFFE3E2E2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${widget.appName} is currently restricted to maintain your focus session.',
                      textAlign: TextAlign.center,
                      style: tt.bodyMedium?.copyWith(
                        color: const Color(0xFFC6C5D5),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Countdown Card & Action Buttons (Bottom 2/3)
              Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF212123),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFF2C2C2E), width: 1),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'REMAINING FOCUS TIME',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFC6C5D5),
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _formatDuration(_remaining),
                          style: const TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF5E6AD2),
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.timer_outlined, color: Color(0xFFC6C5D5), size: 14),
                            const SizedBox(width: 6),
                            Text(
                              _endTime != null
                                  ? 'Session ends at ${DateFormat('hh:mm a').format(_endTime!)}'
                                  : 'Active focus session ongoing',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFFC6C5D5),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Return Home Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5E6AD2),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        // Navigate to FocusOS Home screen
                        ref.read(appRouterProvider).go(RouteNames.focusSession);
                      },
                      icon: const Icon(Icons.home_rounded, size: 20),
                      label: const Text(
                        'Return Home',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Enter Admin Password Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2C2C2E),
                        foregroundColor: const Color(0xFFE3E2E2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        // Request Admin PIN to stop focus mode
                        ref.read(adminAuthProvider.notifier).runProtectedAction(context, () {
                          ref.read(focusModeProvider.notifier).stopFocus();
                          SystemNavigator.pop();
                        });
                      },
                      icon: const Icon(Icons.lock_open_rounded, size: 20, color: Color(0xFFC6C5D5)),
                      label: const Text(
                        'Enter Admin Password',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    ),
  );
}
}
