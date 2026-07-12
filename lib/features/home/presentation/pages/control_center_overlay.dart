import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/control_center_provider.dart';
import '../../../../core/providers/focus_providers.dart';
import '../../../../core/providers/admin_auth_provider.dart';
import '../../../../core/constants/route_names.dart';

class ControlCenterOverlay extends ConsumerStatefulWidget {
  final bool isShown;
  final VoidCallback onClose;

  const ControlCenterOverlay({
    super.key,
    required this.isShown,
    required this.onClose,
  });

  @override
  ConsumerState<ControlCenterOverlay> createState() => _ControlCenterOverlayState();
}

class _ControlCenterOverlayState extends ConsumerState<ControlCenterOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  Timer? _timeTimer;
  DateTime _currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _timeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });

    if (widget.isShown) {
      _animationController.forward();
    }
  }

  @override
  void didUpdateWidget(covariant ControlCenterOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isShown != oldWidget.isShown) {
      if (widget.isShown) {
        ref.read(controlCenterProvider.notifier).refreshData();
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _timeTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!widget.isShown) return;
    final screenHeight = MediaQuery.of(context).size.height;
    _animationController.value += details.primaryDelta! / screenHeight;
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_animationController.value < 0.7 ||
        (details.primaryVelocity ?? 0.0) < -300) {
      _animationController.reverse().then((_) => widget.onClose());
    } else {
      _animationController.forward();
    }
  }


  String _formatFocusDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:${m}:${s}' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(controlCenterProvider);
    final isFocusActive = ref.watch(focusModeProvider);
    final focusSnapshot = ref.watch(activeSessionSnapshotProvider);

    final size = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;

    // Active Focus details calculations
    Duration remaining = Duration.zero;
    if (isFocusActive && focusSnapshot != null) {
      final elapsed = DateTime.now().difference(focusSnapshot.startTime);
      final rem = focusSnapshot.duration - elapsed;
      remaining = rem > Duration.zero ? rem : Duration.zero;
    }

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        if (_animationController.value == 0.0) {
          return const SizedBox.shrink();
        }

        return Stack(
          children: [
            // Dark scrim background
            GestureDetector(
              onTap: () {
                _animationController.reverse().then((_) => widget.onClose());
              },
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  color: Colors.black.withOpacity(0.4),
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            ),

            // Sliding panel
            SlideTransition(
              position: _slideAnimation,
              child: child,
            ),
          ],
        );
      },
      child: GestureDetector(
        onVerticalDragUpdate: _handleDragUpdate,
        onVerticalDragEnd: _handleDragEnd,
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxHeight: size.height * 0.88,
          ),
          decoration: const BoxDecoration(
            color: Color(0xCC0D0E10),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
            border: Border(
              bottom: BorderSide(color: Color(0x1AFFFFFF), width: 1.5),
              left: BorderSide(color: Color(0x0DFFFFFF), width: 1),
              right: BorderSide(color: Color(0x0DFFFFFF), width: 1),
            ),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Row: Time & Battery
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormat('hh:mm').format(_currentTime),
                                style: const TextStyle(
                                  color: Color(0xFFE3E2E2),
                                  fontSize: 42,
                                  fontWeight: FontWeight.w300,
                                  fontFamily: 'Inter',
                                  letterSpacing: -1,
                                ),
                              ),
                              Text(
                                DateFormat('EEEE, MMM d').format(_currentTime),
                                style: TextStyle(
                                  color: const Color(0xFFC6C5D5).withOpacity(0.7),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                  fontFamily: 'Inter',
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Icon(
                                _getBatteryIcon(state.batteryLevel),
                                color: const Color(0xFFE3E2E2),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${state.batteryLevel}%',
                                style: const TextStyle(
                                  color: Color(0xFFE3E2E2),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Inter',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Toggles Grid
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 2.2,
                        children: [
                          // Wi-Fi Toggle
                          _buildToggleTile(
                            icon: state.isWifiEnabled
                                ? Icons.wifi_rounded
                                : Icons.wifi_off_rounded,
                            label: 'Wi-Fi',
                            subtitle: state.isWifiEnabled ? 'Enabled' : 'Disabled',
                            isActive: state.isWifiEnabled,
                            onTap: () => ref
                                .read(controlCenterProvider.notifier)
                                .toggleWifi(),
                            onLongPress: () => ref
                                .read(controlCenterProvider.notifier)
                                .openWifiSettings(),
                          ),

                          // Bluetooth Toggle
                          _buildToggleTile(
                            icon: state.isBluetoothEnabled
                                ? Icons.bluetooth_rounded
                                : Icons.bluetooth_disabled_rounded,
                            label: 'Bluetooth',
                            subtitle:
                                state.isBluetoothEnabled ? 'Enabled' : 'Disabled',
                            isActive: state.isBluetoothEnabled,
                            onTap: () => ref
                                .read(controlCenterProvider.notifier)
                                .toggleBluetooth(),
                            onLongPress: () => ref
                                .read(controlCenterProvider.notifier)
                                .openBluetoothSettings(),
                          ),

                          // Flashlight Toggle
                          _buildToggleTile(
                            icon: Icons.flashlight_on_rounded,
                            label: 'Flashlight',
                            subtitle:
                                state.isFlashlightEnabled ? 'On' : 'Off',
                            isActive: state.isFlashlightEnabled,
                            onTap: () => ref
                                .read(controlCenterProvider.notifier)
                                .toggleFlashlight(),
                          ),

                          // Sound Mode Toggle
                          _buildToggleTile(
                            icon: _getRingerIcon(state.ringerMode),
                            label: 'Sound Mode',
                            subtitle: _getRingerLabel(state.ringerMode),
                            isActive: state.ringerMode == 2, // Normal active glow
                            onTap: () => ref
                                .read(controlCenterProvider.notifier)
                                .cycleRingerMode(),
                            onLongPress: () => ref
                                .read(controlCenterProvider.notifier)
                                .openDndAccessSettings(),
                          ),

                          // Mobile Data Settings
                          _buildToggleTile(
                            icon: Icons.cell_tower_rounded,
                            label: 'Mobile Data',
                            subtitle: 'Tap to configure',
                            isActive: false,
                            onTap: () => ref
                                .read(controlCenterProvider.notifier)
                                .openMobileDataSettings(),
                          ),

                          // Airplane Mode Settings
                          _buildToggleTile(
                            icon: state.isAirplaneModeEnabled
                                ? Icons.airplanemode_active_rounded
                                : Icons.airplanemode_inactive_rounded,
                            label: 'Airplane Mode',
                            subtitle: state.isAirplaneModeEnabled ? 'On' : 'Off',
                            isActive: state.isAirplaneModeEnabled,
                            onTap: () => ref
                                .read(controlCenterProvider.notifier)
                                .openAirplaneModeSettings(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Sliders Container
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          color: const Color(0x13FFFFFF),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.05)),
                        ),
                        child: Column(
                          children: [
                            // Brightness Slider
                            _buildSliderRow(
                              icon: Icons.brightness_6_rounded,
                              value: state.brightness,
                              onChanged: (val) {
                                ref
                                    .read(controlCenterProvider.notifier)
                                    .setBrightness(val);
                              },
                              onPermissionTap: () => ref
                                  .read(controlCenterProvider.notifier)
                                  .openWriteSettingsPermission(),
                              hasPermission: state.hasWriteSettingsPermission,
                              tooltip: 'Modify System Settings permission required',
                            ),
                            const SizedBox(height: 12),
                            // Volume Slider
                            _buildSliderRow(
                              icon: Icons.volume_up_rounded,
                              value: state.volume,
                              onChanged: (val) {
                                ref
                                    .read(controlCenterProvider.notifier)
                                    .setVolume(val);
                              },
                              hasPermission: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Quick Navigation Row
                      Row(
                        children: [
                          Expanded(
                            child: _buildNavButton(
                              context,
                              icon: Icons.apps_rounded,
                              label: 'Apps',
                              onTap: () {
                                widget.onClose();
                                context.go(RouteNames.allowedApps);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildNavButton(
                              context,
                              icon: Icons.schedule_rounded,
                              label: 'Schedule',
                              onTap: () {
                                widget.onClose();
                                context.go(RouteNames.schedule);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildNavButton(
                              context,
                              icon: Icons.settings_rounded,
                              label: 'Settings',
                              onTap: () {
                                widget.onClose();
                                context.go(RouteNames.settings);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Session Tracking Card
                      _buildFocusSessionCard(
                        context,
                        isFocusActive,
                        remaining,
                        focusSnapshot?.activeProfile ?? 'Focus Session',
                      ),

                      const SizedBox(height: 16),

                      // Drag handle indicator
                      Center(
                        child: Container(
                          width: 40,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0x13FFFFFF),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () {
          // If focus is active, run protected action before navigating
          final isFocusActive = ref.read(focusModeProvider);
          if (isFocusActive) {
            ref.read(adminAuthProvider.notifier).runProtectedAction(context, () {
               onTap();
            });
          } else {
             onTap();
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Column(
            children: [
              Icon(icon, color: const Color(0xFFC6C5D5), size: 24),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFE3E2E2),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleTile({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool isActive,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {
    return Material(
      color: isActive ? const Color(0xFF5E6AD2) : const Color(0x13FFFFFF),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
          child: Row(
            children: [
              Icon(
                icon,
                color: isActive ? Colors.white : const Color(0xFFC6C5D5),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: isActive ? Colors.white : const Color(0xFFE3E2E2),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: isActive
                            ? Colors.white.withOpacity(0.8)
                            : const Color(0xFFC6C5D5).withOpacity(0.6),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliderRow({
    required IconData icon,
    required double value,
    required ValueChanged<double> onChanged,
    required bool hasPermission,
    VoidCallback? onPermissionTap,
    String tooltip = '',
  }) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFC6C5D5), size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: !hasPermission
              ? InkWell(
                  onTap: onPermissionTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Permissions Required',
                            style: TextStyle(
                              color: Color(0xFFCF6679),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: const Color(0xFFCF6679).withOpacity(0.7),
                          size: 10,
                        ),
                      ],
                    ),
                  ),
                )
              : SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                    activeTrackColor: const Color(0xFF5E6AD2),
                    inactiveTrackColor: Colors.white.withOpacity(0.1),
                    thumbColor: const Color(0xFF5E6AD2),
                    overlayColor: const Color(0xFF5E6AD2).withOpacity(0.12),
                  ),
                  child: Slider(
                    value: value,
                    onChanged: onChanged,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildFocusSessionCard(
    BuildContext context,
    bool isFocusActive,
    Duration remainingTime,
    String sessionTitle,
  ) {
    if (!isFocusActive) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0x0DFFFFFF),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.03)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.nights_stay_rounded,
                color: Color(0xFFC6C5D5),
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'No Active Session',
                    style: TextStyle(
                      color: Color(0xFFE3E2E2),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'FocusOS is in standby mode.',
                    style: TextStyle(
                      color: const Color(0xFFC6C5D5).withOpacity(0.6),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF231E3D).withOpacity(0.7),
            const Color(0xFF171426).withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF5E6AD2).withOpacity(0.3), width: 1.2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF5E6AD2).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shield_rounded,
                  color: Color(0xFF5E6AD2),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sessionTitle,
                      style: const TextStyle(
                        color: Color(0xFFE3E2E2),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Focus Protection Active',
                      style: TextStyle(
                        color: Color(0xFFFFB867),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF5E6AD2).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF5E6AD2).withOpacity(0.2)),
                ),
                child: Text(
                  _formatFocusDuration(remainingTime),
                  style: const TextStyle(
                    color: Color(0xFF5E6AD2),
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 38,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: const Color(0xFF5E6AD2).withOpacity(0.4)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () {
                _animationController.reverse().then((_) {
                  widget.onClose();
                  context.push(RouteNames.focusSession);
                });
              },
              child: const Text(
                'Open Session Manager',
                style: TextStyle(
                  color: Color(0xFF5E6AD2),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getBatteryIcon(int level) {
    if (level > 85) return Icons.battery_full_rounded;
    if (level > 50) return Icons.battery_5_bar_rounded;
    if (level > 25) return Icons.battery_3_bar_rounded;
    return Icons.battery_alert_rounded;
  }

  IconData _getRingerIcon(int mode) {
    switch (mode) {
      case 0:
        return Icons.volume_mute_rounded;
      case 1:
        return Icons.vibration_rounded;
      case 2:
      default:
        return Icons.volume_up_rounded;
    }
  }

  String _getRingerLabel(int mode) {
    switch (mode) {
      case 0:
        return 'Silent';
      case 1:
        return 'Vibrate';
      case 2:
      default:
        return 'Normal';
    }
  }
}
