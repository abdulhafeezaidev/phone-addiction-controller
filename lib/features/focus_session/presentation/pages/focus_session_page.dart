import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/route_names.dart';
import '../../../../core/providers/service_providers.dart';
import '../../../../core/providers/focus_providers.dart';
import '../../../../core/providers/admin_auth_provider.dart';
import '../../../../domain/models/allowed_app.dart';
import '../../../home/presentation/pages/control_center_overlay.dart';

class FocusSessionPage extends ConsumerStatefulWidget {
  const FocusSessionPage({super.key});

  @override
  ConsumerState<FocusSessionPage> createState() => _FocusSessionPageState();
}

class _FocusSessionPageState extends ConsumerState<FocusSessionPage>
    with TickerProviderStateMixin {
  bool _isRunning = false;
  Duration _elapsed = Duration.zero;
  Duration _targetDuration = const Duration(minutes: 25);
  Timer? _timer;
  DateTime? _endTime;
  bool _showControlCenter = false;

  late AnimationController _pulseController;
  static const _platformChannel =
      MethodChannel('com.personal.phone_addiction_controller/accessibility');

  static const _durationOptions = [
    Duration(minutes: 15),
    Duration(minutes: 25),
    Duration(minutes: 45),
    Duration(hours: 1),
    Duration(hours: 2),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _checkActiveSession();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _checkActiveSession() async {
    final active = ref.read(focusModeProvider);
    if (active) {
      final snapshot = ref.read(activeSessionSnapshotProvider);
      if (snapshot != null) {
        final elapsed = DateTime.now().difference(snapshot.startTime);
        if (mounted) {
          setState(() {
            _isRunning = true;
            _elapsed = elapsed;
            _targetDuration = snapshot.duration;
            _endTime = snapshot.endTime;
          });
          _startTimer();
        }
      } else {
        final sessionTrackingService = ref.read(sessionTrackingServiceProvider);
        final activeSession = await sessionTrackingService.getActiveSession();
        if (activeSession != null) {
          final elapsed = DateTime.now().difference(activeSession.startTime);
          if (mounted) {
            setState(() {
              _isRunning = true;
              _elapsed = elapsed;
              _endTime = activeSession.startTime.add(_targetDuration);
            });
            _startTimer();
          }
        }
      }
    }
  }



  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsed += const Duration(seconds: 1);
      });
      if (_elapsed >= _targetDuration) {
        _completeSession();
      }
    });
  }

  Future<void> _startSession() async {
    final passwordService = ref.read(passwordServiceProvider);
    final hasAdminPassword = await passwordService.getAdminSettings() != null;
    if (!hasAdminPassword) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Set an administrator password before starting Focus Mode.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.push(RouteNames.adminPassword);
      return;
    }

    final accessibility = ref.read(accessibilityServiceManagerProvider);
    final isDefault = await accessibility.isDefaultLauncher();
    if (!isDefault) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            backgroundColor: const Color(0xFF212123),
            title: const Text(
              'Default Home App Required',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'To begin Focus Mode and prevent bypassing, FocusOS must be set as your default Home launcher.\n\n'
              'Please tap "Set Default" and select FocusOS as "Always" in the next screen.',
              style: TextStyle(color: Color(0xFFC6C5D5)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF5E6AD2))),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await accessibility.openDefaultLauncherSettings();
                },
                child: const Text('Set Default', style: TextStyle(color: Color(0xFFFFB867))),
              ),
            ],
          );
        },
      );
      return;
    }

    setState(() {
      _isRunning = true;
      _elapsed = Duration.zero;
      _endTime = DateTime.now().add(_targetDuration);
    });
    _startTimer();
    await ref.read(focusModeProvider.notifier).startFocus(_targetDuration);
  }

  Future<void> _launchAllowedApp(AllowedApp app) async {
    try {
      await _platformChannel.invokeMethod(
        'launchApp',
        {'packageName': app.packageName},
      );
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Could not open ${app.appName}: ${e.message ?? e.code}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _completeSession() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _elapsed = Duration.zero;
      _endTime = null;
    });
    ref.read(focusModeProvider.notifier).stopFocus();
  }

  void _stopSession(BuildContext context) {
    ref.read(adminAuthProvider.notifier).runProtectedAction(context, () {
      _timer?.cancel();
      setState(() {
        _isRunning = false;
        _elapsed = Duration.zero;
        _endTime = null;
      });
      ref.read(focusModeProvider.notifier).stopFocus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Focus Session ended successfully'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }

  void _emergencyExit(BuildContext context) {
    ref.read(adminAuthProvider.notifier).runProtectedAction(context, () {
      _timer?.cancel();
      setState(() {
        _isRunning = false;
        _elapsed = Duration.zero;
        _endTime = null;
      });
      ref.read(focusModeProvider.notifier).stopFocus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Emergency exit authorized. Session aborted.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    });
  }

  double get _progress {
    if (_targetDuration.inSeconds == 0) return 0.0;
    return (_elapsed.inSeconds / _targetDuration.inSeconds).clamp(0.0, 1.0);
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isFocusActive = ref.watch(focusModeProvider);
    final activeSnapshot = ref.watch(activeSessionSnapshotProvider);
    final allowedAppsAsync = ref.watch(allowedAppsProvider);
    final mutableAllowedApps = allowedAppsAsync.valueOrNull ?? const <AllowedApp>[];

    List<AllowedApp> userAllowedApps;
    List<AllowedApp> systemApps;
    if (isFocusActive && activeSnapshot != null) {
      final allAppsAsync = ref.watch(installedAppsProvider(true));
      final allApps = allAppsAsync.valueOrNull ?? const <AllowedApp>[];
      final packageMap = {for (var app in allApps) app.packageName: app};

      // User-selected allowed third-party apps
      userAllowedApps = activeSnapshot.allowedApps.map((pkg) {
        return packageMap[pkg] ?? AllowedApp(packageName: pkg, appName: pkg, isAllowed: true);
      }).toList();

      // Always-allowed system apps (Phone, Camera, Clock, etc.)
      // Filter to only those actually installed on this device
      systemApps = activeSnapshot.alwaysAllowedApps
          .where((pkg) => packageMap.containsKey(pkg))
          .map((pkg) => packageMap[pkg]!)
          .toList();
    } else {
      userAllowedApps = mutableAllowedApps;
      systemApps = const <AllowedApp>[];
    }
    // Legacy alias for non-running mode
    final allowedApps = userAllowedApps;

    // Sync _isRunning with focus mode state (handles page recreation)
    if (isFocusActive && !_isRunning) {
      _isRunning = true;
      if (_timer == null) {
        _checkActiveSession();
      }
    }

    final tt = Theme.of(context).textTheme;
    final remaining = _targetDuration - _elapsed;
    final displayTime = remaining > Duration.zero ? remaining : Duration.zero;



    return PopScope(
      canPop: !_isRunning,
      onPopInvokedWithResult: (didPop, result) {
        // Prevent back gesture from exiting focus session
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF121414),
        appBar: _isRunning
            ? null
            : AppBar(
                title: const Text('Focus Session'),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: Color(0xFF5E6AD2)),
                  onPressed: () => context.pop(),
                ),
              ),
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onVerticalDragUpdate: (details) {
            if (details.delta.dy > 8) {
              if (!_showControlCenter) {
                setState(() {
                  _showControlCenter = true;
                });
              }
            }
          },
          child: Stack(
            children: [
              SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isRunning)
                  _buildFocusLauncher(context, displayTime, systemApps, allowedApps)
                else ...[
                  // Viewing Area: Title Large
                  const SizedBox(height: 20),
                  Text(
                    'Active Focus',
                    style: tt.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 28,
                      color: const Color(0xFFE3E2E2),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Interaction Area: Timer Card
                  Expanded(
                    child: ListView(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF212123),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                                color: const Color(0xFF2C2C2E), width: 1),
                            boxShadow: _isRunning
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF5E6AD2)
                                          .withValues(alpha: 0.05),
                                      blurRadius: 32,
                                      offset: const Offset(0, 8),
                                    )
                                  ]
                                : null,
                          ),
                          child: Column(
                            children: [
                              // Circular Progress Ring
                              Center(
                                child: SizedBox(
                                  width: 200,
                                  height: 200,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      // Background Ring
                                      Container(
                                        width: 180,
                                        height: 180,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: const Color(0xFF2C2C2E),
                                            width: 8,
                                          ),
                                        ),
                                      ),
                                      // Foreground Progress
                                      if (_isRunning)
                                        SizedBox(
                                          width: 180,
                                          height: 180,
                                          child: CircularProgressIndicator(
                                            value: _progress,
                                            strokeWidth: 8,
                                            color: const Color(0xFF5E6AD2),
                                            backgroundColor: Colors.transparent,
                                            strokeCap: StrokeCap.round,
                                          ),
                                        )
                                      else
                                        Container(
                                          width: 180,
                                          height: 180,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: const Color(0xFF5E6AD2)
                                                  .withValues(alpha: 0.2),
                                              width: 8,
                                            ),
                                          ),
                                        ),
                                      // Text inside Ring
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            _isRunning
                                                ? _formatDuration(displayTime)
                                                : _formatDuration(
                                                    _targetDuration),
                                            style: tt.displayLarge?.copyWith(
                                              fontSize: 40,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFFE3E2E2),
                                              letterSpacing: -1,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _isRunning
                                                ? 'Remaining'
                                                : 'Target Time',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFFC6C5D5),
                                              letterSpacing: 1.1,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Active Session Info Details Card
                        if (_isRunning) ...[
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFF212123),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                  color: const Color(0xFF2C2C2E), width: 1),
                            ),
                            child: Column(
                              children: [
                                _buildDetailsRow(
                                  icon: Icons.chat_bubble_outline_rounded,
                                  label: 'Focusing on',
                                  value: 'Restricted Apps',
                                ),
                                const SizedBox(height: 16),
                                _buildDetailsRow(
                                  icon: Icons.schedule_outlined,
                                  label: 'Ends at',
                                  value: _endTime != null
                                      ? DateFormat('hh:mm a').format(_endTime!)
                                      : '—',
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Duration Selector (Chips selector when inactive)
                        if (!_isRunning) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            child: Text(
                              'Select Duration',
                              style: tt.titleSmall
                                  ?.copyWith(color: const Color(0xFFC6C5D5)),
                            ),
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: _durationOptions.map((d) {
                              final isSelected = d == _targetDuration;
                              final label = d.inHours >= 1
                                  ? '${d.inHours}h'
                                  : '${d.inMinutes}m';
                              return ChoiceChip(
                                label: Text(label),
                                selected: isSelected,
                                onSelected: (_) =>
                                    setState(() => _targetDuration = d),
                                selectedColor: const Color(0xFF5E6AD2),
                                backgroundColor: const Color(0xFF212123),
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFFC6C5D5),
                                  fontWeight: FontWeight.w600,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                      color: isSelected
                                          ? const Color(0xFF5E6AD2)
                                          : const Color(0xFF2C2C2E)),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                        if (!_isRunning) ...[
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Allowed Apps (${allowedApps.length})',
                                  style: tt.titleSmall?.copyWith(color: const Color(0xFFC6C5D5)),
                                ),
                                TextButton(
                                  onPressed: () => context.go(RouteNames.allowedApps),
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text('Edit List', style: TextStyle(color: Color(0xFF5E6AD2), fontSize: 12)),
                                ),
                              ],
                            ),
                          ),
                            allowedApps.isEmpty
                              ? Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF212123),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0xFF2C2C2E)),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.warning_amber_rounded, color: Color(0xFFFFB867), size: 20),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'No apps allowed. You will be completely locked out during the session.',
                                          style: TextStyle(color: Color(0xFFC6C5D5), fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : SizedBox(
                                  height: 80,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                      itemCount: allowedApps.length,
                                    itemBuilder: (context, index) {
                                        final app = allowedApps[index];
                                      return Padding(
                                        padding: const EdgeInsets.only(right: 12.0),
                                        child: Column(
                                          children: [
                                            CircleAvatar(
                                              radius: 24,
                                              backgroundColor: const Color(0xFF2C2C2E),
                                              child: app.icon != null
                                                  ? Image.memory(app.icon!, width: 28, height: 28)
                                                  : const Icon(Icons.apps_rounded, color: Color(0xFFC6C5D5)),
                                            ),
                                            const SizedBox(height: 4),
                                            SizedBox(
                                              width: 60,
                                              child: Text(
                                                app.appName,
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(fontSize: 10, color: Color(0xFFC6C5D5)),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                        ],
                      ],
                    ),
                  ),

                  // Action buttons at bottom
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24.0, top: 16.0),
                    child: Column(
                      children: [
                        if (!_isRunning)
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
                              onPressed: _startSession,
                              icon: const Icon(Icons.play_arrow_rounded,
                                  size: 24),
                              label: const Text(
                                'Start Focus Session',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 16),
                              ),
                            ),
                          )
                        else ...[
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
                              onPressed: () => _stopSession(context),
                              icon: const Icon(Icons.lock_rounded,
                                  size: 20, color: Color(0xFFC6C5D5)),
                              label: const Text(
                                'End Session',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 16),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFCF6679),
                                side: BorderSide(
                                    color: const Color(0xFFCF6679)
                                        .withValues(alpha: 0.5)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                              onPressed: () => _emergencyExit(context),
                              icon: const Icon(
                                  Icons.admin_panel_settings_rounded,
                                  size: 20),
                              label: const Text(
                                'Emergency Exit',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 16),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
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
),
);
  }

  Widget _buildFocusLauncher(BuildContext context, Duration displayTime,
      List<AllowedApp> systemApps, List<AllowedApp> userApps) {
    final tt = Theme.of(context).textTheme;

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Focus Mode',
                      style: tt.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFE3E2E2),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Only listed apps are accessible during this session.',
                      style: tt.bodySmall?.copyWith(
                        color: const Color(0xFFC6C5D5),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF212123),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF2C2C2E)),
                ),
                child: Text(
                  _formatDuration(displayTime),
                  style: const TextStyle(
                    color: Color(0xFF5E6AD2),
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.menu_rounded, color: Color(0xFFC6C5D5)),
                onPressed: () {
                  setState(() {
                    _showControlCenter = true;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: (systemApps.isEmpty && userApps.isEmpty)
                ? _buildNoAllowedApps(context)
                : NotificationListener<OverscrollNotification>(
                    onNotification: (notification) {
                      if (notification.overscroll < 0) {
                        if (!_showControlCenter) {
                          setState(() {
                            _showControlCenter = true;
                          });
                        }
                      }
                      return false;
                    },
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(decelerationRate: ScrollDecelerationRate.fast),
                      ),
                      slivers: [
                      // ── Always Allowed: System Apps ──────────────────────
                      if (systemApps.isNotEmpty) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                Container(
                                  width: 3,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF5E6AD2),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Always Available',
                                  style: tt.labelLarge?.copyWith(
                                    color: const Color(0xFF5E6AD2),
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF5E6AD2).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${systemApps.length}',
                                    style: const TextStyle(
                                      color: Color(0xFF5E6AD2),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SliverGrid(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final app = systemApps[index];
                              return _AllowedLaunchTile(
                                app: app,
                                onTap: () => _launchAllowedApp(app),
                                isSystem: true,
                              );
                            },
                            childCount: systemApps.length,
                          ),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.82,
                          ),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 20)),
                      ],

                      // ── User-Allowed: Third-Party Apps ───────────────────
                      if (userApps.isNotEmpty) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                Container(
                                  width: 3,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFB867),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Allowed Apps',
                                  style: tt.labelLarge?.copyWith(
                                    color: const Color(0xFFFFB867),
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFB867).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${userApps.length}',
                                    style: const TextStyle(
                                      color: Color(0xFFFFB867),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SliverGrid(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final app = userApps[index];
                              return _AllowedLaunchTile(
                                app: app,
                                onTap: () => _launchAllowedApp(app),
                                isSystem: false,
                              );
                            },
                            childCount: userApps.length,
                          ),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.82,
                          ),
                        ),
                      ],

                      // If only system apps exist, show a hint
                      if (userApps.isEmpty && systemApps.isNotEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'No third-party apps allowed for this session.',
                              textAlign: TextAlign.center,
                              style: tt.bodySmall?.copyWith(color: const Color(0xFF6E6E73)),
                            ),
                          ),
                        ),

                      const SliverToBoxAdapter(child: SizedBox(height: 20)),
                    ],
                  ),
                ),
          ),

          const SizedBox(height: 12),
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
              onPressed: () => _stopSession(context),
              icon: const Icon(Icons.admin_panel_settings_rounded, size: 20),
              label: const Text(
                'Admin Unlock / End Focus',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFCF6679),
                side: BorderSide(
                    color: const Color(0xFFCF6679).withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              onPressed: () => context.push(RouteNames.emergencyOverride),
              icon: const Icon(Icons.warning_amber_rounded, size: 20),
              label: const Text(
                'Emergency Override',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildNoAllowedApps(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF212123),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF2C2C2E)),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_rounded, color: Color(0xFF5E6AD2), size: 44),
            SizedBox(height: 12),
            Text(
              'No apps are allowed in this session.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFE3E2E2),
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Use admin unlock to end focus, then add allowed apps from the Apps tab.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFC6C5D5), height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: Color(0xFF1E2020),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFF5E6AD2), size: 20),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFFC6C5D5)),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: tt.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: const Color(0xFFE3E2E2),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showExitConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Stop Focus Session?'),
        content: const Text(
          'Leaving will end your current focus session and unblock all apps.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep Focusing'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _stopSession(context);
              context.pop();
            },
            child: const Text('Stop & Exit'),
          ),
        ],
      ),
    );
  }
}

class _AllowedLaunchTile extends StatelessWidget {
  const _AllowedLaunchTile({
    required this.app,
    required this.onTap,
    this.isSystem = false,
  });

  final AllowedApp app;
  final VoidCallback onTap;
  final bool isSystem;

  @override
  Widget build(BuildContext context) {
    final accentColor = isSystem ? const Color(0xFF5E6AD2) : const Color(0xFFFFB867);
    final borderColor = isSystem
        ? const Color(0xFF5E6AD2).withValues(alpha: 0.3)
        : const Color(0xFF2C2C2E);

    return Material(
      color: const Color(0xFF212123),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2020),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: app.icon != null
                        ? Image.memory(app.icon!, fit: BoxFit.cover)
                        : Icon(
                            Icons.apps_rounded,
                            color: accentColor,
                          ),
                  ),
                  if (isSystem)
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFF5E6AD2),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF212123), width: 1.5),
                      ),
                      child: const Icon(Icons.lock_outline_rounded, size: 8, color: Colors.white),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                app.appName,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFE3E2E2),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
