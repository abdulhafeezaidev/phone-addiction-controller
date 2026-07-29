import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/route_names.dart';
import '../../../../core/providers/service_providers.dart';
import '../../../../core/providers/statistics_providers.dart';
import '../../../../core/providers/focus_providers.dart';
import '../../../../widgets/battery_optimization_card.dart';
import 'control_center_overlay.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> with WidgetsBindingObserver {
  bool _canDrawOverlays = false;
  Timer? _activeSessionTimer;
  Duration _remaining = Duration.zero;
  final Duration _targetDuration = const Duration(minutes: 25);
  bool _showControlCenter = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkOverlayPermission();
    _checkActiveSession();
  }

  @override
  void dispose() {
    _activeSessionTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(accessibilityStatusProvider);
      ref.invalidate(appStatisticsProvider);
      ref.invalidate(defaultLauncherStatusProvider);
      _checkOverlayPermission();
      _checkActiveSession();
    }
  }

  Future<void> _checkOverlayPermission() async {
    const channel = MethodChannel('com.personal.phone_addiction_controller/accessibility');
    try {
      final res = await channel.invokeMethod<bool>('canDrawOverlays');
      if (mounted) setState(() => _canDrawOverlays = res ?? false);
    } catch (_) {}
  }

  Future<void> _checkActiveSession() async {
    final isActive = ref.read(focusModeProvider);
    if (isActive) {
      final snapshot = ref.read(activeSessionSnapshotProvider);
      final startTime = snapshot?.startTime;
      if (startTime != null) {
        _startActiveSessionTimer(startTime, snapshot!.duration);
      } else {
        final service = ref.read(sessionTrackingServiceProvider);
        final session = await service.getActiveSession();
        if (session != null) {
          _startActiveSessionTimer(session.startTime, const Duration(minutes: 25));
        }
      }
    } else {
      _activeSessionTimer?.cancel();
      if (mounted) {
        setState(() {
          _remaining = Duration.zero;
        });
      }
    }
  }

  void _startActiveSessionTimer(DateTime startTime, Duration totalDuration) {
    _activeSessionTimer?.cancel();
    _updateRemaining(startTime, totalDuration);
    _activeSessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateRemaining(startTime, totalDuration);
    });
  }

  void _updateRemaining(DateTime startTime, Duration totalDuration) {
    final elapsed = DateTime.now().difference(startTime);
    final rem = totalDuration - elapsed;
    if (mounted) {
      setState(() {
        _remaining = rem > Duration.zero ? rem : Duration.zero;
      });
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isActive = ref.watch(focusModeProvider);

    // Watch focusModeProvider and sync active session timers
    ref.listen<bool>(focusModeProvider, (prev, next) {
      _checkActiveSession();
    });

    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: const Color(0xFF121414),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0.0) > 200) {
            setState(() {
              _showControlCenter = true;
            });
          }
        },
        child: Stack(
          children: [
            SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(appStatisticsProvider);
            await _checkOverlayPermission();
            await _checkActiveSession();
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(decelerationRate: ScrollDecelerationRate.fast),
            ),
            slivers: [
              // Header Row with Logo
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset(
                          'assets/stitch/stitch/logo.jpeg',
                          width: 36,
                          height: 36,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.shield_rounded,
                            color: Color(0xFF5E6AD2),
                            size: 32,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'FocusOS',
                        style: tt.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF5E6AD2),
                          fontSize: 24,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.person_outline_rounded, color: Color(0xFFC6C5D5)),
                        onPressed: () => context.push(RouteNames.adminPassword),
                      ),
                    ],
                  ),
                ),
              ),

              // Dismissible Battery Card
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: BatteryOptimizationCard(),
                ),
              ),

              // Default Launcher Setup Card
              SliverToBoxAdapter(
                child: _buildLauncherSetupCard(context),
              ),

              // Timer / Status Ring Area
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: Column(
                    children: [
                      Center(
                        child: SizedBox(
                          width: 240,
                          height: 240,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Outer track ring
                              Container(
                                width: 220,
                                height: 220,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFF2C2C2E),
                                    width: 12,
                                  ),
                                ),
                              ),
                              // Progress Ring
                              if (isActive)
                                SizedBox(
                                  width: 220,
                                  height: 220,
                                  child: CircularProgressIndicator(
                                    value: _targetDuration.inSeconds > 0
                                        ? (_remaining.inSeconds / _targetDuration.inSeconds).clamp(0.0, 1.0)
                                        : 0.0,
                                    strokeWidth: 12,
                                    color: const Color(0xFF5E6AD2),
                                    backgroundColor: Colors.transparent,
                                    strokeCap: StrokeCap.round,
                                  ),
                                )
                              else
                                Container(
                                  width: 220,
                                  height: 220,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFF5E6AD2).withValues(alpha: 0.2),
                                      width: 12,
                                    ),
                                  ),
                                ),
                              // Time display text
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    isActive ? _formatDuration(_remaining) : '--:--',
                                    style: tt.displayLarge?.copyWith(
                                      fontSize: 48,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFFE3E2E2),
                                      letterSpacing: -1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    isActive ? 'Active Focus' : 'Inactive',
                                    style: tt.titleMedium?.copyWith(
                                      color: const Color(0xFFC6C5D5),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Start/View Focus Button
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5E6AD2),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () => context.push(RouteNames.focusSession),
                        icon: Icon(isActive ? Icons.visibility_rounded : Icons.play_arrow_rounded, size: 24),
                        label: Text(
                          isActive ? 'View Active Session' : 'Start Focus Session',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Interaction Cards Area
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Weekly Summary Card
                      _buildWeeklySummaryCard(context),
                      const SizedBox(height: 12),

                      // Quick Actions Grid
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _buildQuickActionCard(
                                context,
                                icon: Icons.block_rounded,
                                title: 'Block Apps',
                                subtitle: 'Select allowed apps',
                                color: const Color(0xFF5E6AD2),
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF231E3D), Color(0xFF171426)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderColor: const Color(0xFF5E6AD2).withValues(alpha: 0.3),
                                onTap: () => context.go(RouteNames.allowedApps),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildQuickActionCard(
                                context,
                                icon: Icons.schedule_rounded,
                                title: 'Focus Schedule',
                                subtitle: 'Configure routines',
                                color: const Color(0xFFFFB867),
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF332314), Color(0xFF1F150C)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderColor: const Color(0xFFFFB867).withValues(alpha: 0.3),
                                onTap: () => context.go(RouteNames.schedule),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Diagnostics Card
                      _buildDiagnosticsCard(context),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      ControlCenterOverlay(
        isShown: _showControlCenter,
        onClose: () {
          setState(() {
            _showControlCenter = false;
          });
        },
      ),
    ],
  ),
),
);
  }

  Widget _buildWeeklySummaryCard(BuildContext context) {
    final statsAsync = ref.watch(appStatisticsProvider);
    final tt = Theme.of(context).textTheme;

    return Container(
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
              Text(
                'Weekly Summary',
                style: tt.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFE3E2E2),
                ),
              ),
              GestureDetector(
                onTap: () => context.push(RouteNames.statistics),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View All',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF5E6AD2),
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Color(0xFF5E6AD2),
                      size: 12,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          statsAsync.when(
            data: (stats) {
              final hours = stats.weeklyFocusDuration.inHours;
              final mins = stats.weeklyFocusDuration.inMinutes % 60;
              final durationStr = hours > 0 ? '${hours}h ${mins}m' : '${mins}m';

              return Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Focus Time',
                        style: TextStyle(fontSize: 12, color: Color(0xFFC6C5D5)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        durationStr,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFE3E2E2),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'vs Last Week',
                        style: TextStyle(fontSize: 12, color: Color(0xFFC6C5D5)),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: const [
                          Icon(Icons.trending_up_rounded, color: Color(0xFF81C784), size: 18),
                          SizedBox(width: 4),
                          Text(
                            '+15%',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF81C784),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (err, _) => const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  Text(
                    'Total Focus Time: 0m',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE3E2E2),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Bar Chart Visual Elements
          SizedBox(
            height: 64,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildBarChartColumn('M', 0.4, false),
                _buildBarChartColumn('T', 0.6, false),
                _buildBarChartColumn('W', 0.8, false),
                _buildBarChartColumn('T', 0.95, true),
                _buildBarChartColumn('F', 0.5, false),
                _buildBarChartColumn('S', 0.2, false),
                _buildBarChartColumn('S', 0.1, false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChartColumn(String label, double fillRatio, bool isHighlight) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            height: (48 * fillRatio).clamp(4.0, 48.0),
            width: 14,
            decoration: BoxDecoration(
              color: isHighlight ? const Color(0xFF5E6AD2) : const Color(0xFF343535),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              boxShadow: isHighlight
                  ? [
                      BoxShadow(
                        color: const Color(0xFF5E6AD2).withValues(alpha: 0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 0),
                      )
                    ]
                  : null,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
              color: isHighlight ? const Color(0xFF5E6AD2) : const Color(0xFFC6C5D5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Gradient gradient,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          splashColor: color.withValues(alpha: 0.1),
          highlightColor: color.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Glowing Icon Wrapper
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.15),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE3E2E2),
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFC6C5D5),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLauncherSetupCard(BuildContext context) {
    final isDefault = ref.watch(defaultLauncherStatusProvider).valueOrNull ?? false;
    if (isDefault) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 6.0),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: () async {
            final manager = ref.read(accessibilityServiceManagerProvider);
            await manager.openDefaultLauncherSettings();
          },
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2A2520), Color(0xFF212123)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFFFFB867).withValues(alpha: 0.4),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB867).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.home_rounded,
                    color: Color(0xFFFFB867),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Set as Default Launcher',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFFFB867),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Home button will return to FocusOS during sessions — true bypass prevention.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFC6C5D5),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Color(0xFFFFB867),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDiagnosticsCard(BuildContext context) {
    final accessibilityAsync = ref.watch(accessibilityStatusProvider);
    final isEnabled = accessibilityAsync.valueOrNull ?? false;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF212123),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF2C2C2E), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'System Diagnostics',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFFE3E2E2),
            ),
          ),
          const SizedBox(height: 14),
          _buildDiagRow(
            'Accessibility Service',
            isEnabled ? 'Active' : 'Disabled',
            isEnabled ? const Color(0xFF4CAF7D) : const Color(0xFFCF6679),
            onTap: () async {
              final manager = ref.read(accessibilityServiceManagerProvider);
              await manager.openAccessibilitySettings();
            },
          ),
          const Divider(color: Color(0xFF2C2C2E), height: 20),
          _buildDiagRow(
            'Overlay Window Permission',
            _canDrawOverlays ? 'Granted' : 'Needs Setup',
            _canDrawOverlays ? const Color(0xFF4CAF7D) : const Color(0xFFFFB867),
            onTap: () async {
              const channel = MethodChannel('com.personal.phone_addiction_controller/accessibility');
              try {
                await channel.invokeMethod('openOverlaySettings');
              } catch (_) {}
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDiagRow(String title, String status, Color statusColor, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: Color(0xFFC6C5D5), fontSize: 13),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
