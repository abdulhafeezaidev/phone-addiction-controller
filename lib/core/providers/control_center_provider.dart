import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ControlCenterState {
  final int batteryLevel;
  final bool isWifiEnabled;
  final bool isBluetoothEnabled;
  final bool isAirplaneModeEnabled;
  final bool isFlashlightEnabled;
  final int ringerMode; // 0 = Silent, 1 = Vibrate, 2 = Normal
  final double brightness; // 0.0 to 1.0
  final double volume; // 0.0 to 1.0
  final bool hasWriteSettingsPermission;
  final bool hasDndPermission;

  ControlCenterState({
    this.batteryLevel = 100,
    this.isWifiEnabled = false,
    this.isBluetoothEnabled = false,
    this.isAirplaneModeEnabled = false,
    this.isFlashlightEnabled = false,
    this.ringerMode = 2,
    this.brightness = 0.5,
    this.volume = 0.5,
    this.hasWriteSettingsPermission = false,
    this.hasDndPermission = false,
  });

  ControlCenterState copyWith({
    int? batteryLevel,
    bool? isWifiEnabled,
    bool? isBluetoothEnabled,
    bool? isAirplaneModeEnabled,
    bool? isFlashlightEnabled,
    int? ringerMode,
    double? brightness,
    double? volume,
    bool? hasWriteSettingsPermission,
    bool? hasDndPermission,
  }) {
    return ControlCenterState(
      batteryLevel: batteryLevel ?? this.batteryLevel,
      isWifiEnabled: isWifiEnabled ?? this.isWifiEnabled,
      isBluetoothEnabled: isBluetoothEnabled ?? this.isBluetoothEnabled,
      isAirplaneModeEnabled: isAirplaneModeEnabled ?? this.isAirplaneModeEnabled,
      isFlashlightEnabled: isFlashlightEnabled ?? this.isFlashlightEnabled,
      ringerMode: ringerMode ?? this.ringerMode,
      brightness: brightness ?? this.brightness,
      volume: volume ?? this.volume,
      hasWriteSettingsPermission: hasWriteSettingsPermission ?? this.hasWriteSettingsPermission,
      hasDndPermission: hasDndPermission ?? this.hasDndPermission,
    );
  }
}

class ControlCenterStateNotifier extends StateNotifier<ControlCenterState> {
  ControlCenterStateNotifier() : super(ControlCenterState()) {
    refreshData();
    // Refresh battery percentage and other dynamic states periodically
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) {
        refreshData();
      }
    });
  }

  static const _channel = MethodChannel('com.personal.phone_addiction_controller/accessibility');
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> refreshData() async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('getControlCenterData');
      if (res != null && mounted) {
        final maxVol = (res['maxVolume'] as num?)?.toDouble() ?? 15.0;
        final vol = (res['volume'] as num?)?.toDouble() ?? 0.0;
        final brightnessRaw = (res['brightness'] as num?)?.toDouble() ?? 128.0;

        state = state.copyWith(
          batteryLevel: res['batteryLevel'] as int?,
          isWifiEnabled: res['wifiEnabled'] as bool?,
          isBluetoothEnabled: res['bluetoothEnabled'] as bool?,
          isAirplaneModeEnabled: res['airplaneModeEnabled'] as bool?,
          ringerMode: res['ringerMode'] as int?,
          brightness: (brightnessRaw / 255.0).clamp(0.0, 1.0),
          volume: maxVol > 0 ? (vol / maxVol).clamp(0.0, 1.0) : 0.0,
          hasWriteSettingsPermission: res['hasWriteSettingsPermission'] as bool?,
          hasDndPermission: res['hasDndPermission'] as bool?,
          isFlashlightEnabled: res['isFlashlightEnabled'] as bool?,
        );
      }
    } catch (_) {}
  }

  Future<void> toggleWifi() async {
    final target = !state.isWifiEnabled;
    state = state.copyWith(isWifiEnabled: target);
    try {
      final handled = await _channel.invokeMethod<bool>('setWifiEnabled', {'enabled': target});
      if (handled == false) {
        state = state.copyWith(isWifiEnabled: !target);
        await openWifiSettings();
      }
    } catch (_) {
      state = state.copyWith(isWifiEnabled: !target);
    }
    await refreshData();
  }

  Future<void> toggleBluetooth() async {
    final target = !state.isBluetoothEnabled;
    state = state.copyWith(isBluetoothEnabled: target);
    try {
      final handled = await _channel.invokeMethod<bool>('setBluetoothEnabled', {'enabled': target});
      if (handled == false) {
        state = state.copyWith(isBluetoothEnabled: !target);
        await openBluetoothSettings();
      }
    } catch (_) {
      state = state.copyWith(isBluetoothEnabled: !target);
    }
    await refreshData();
  }

  Future<void> toggleFlashlight() async {
    final target = !state.isFlashlightEnabled;
    state = state.copyWith(isFlashlightEnabled: target);
    try {
      await _channel.invokeMethod('setFlashlightEnabled', {'enabled': target});
    } catch (_) {
      state = state.copyWith(isFlashlightEnabled: !target);
    }
    await refreshData();
  }

  Future<void> cycleRingerMode() async {
    // Cycle modes: Normal (2) -> Vibrate (1) -> Silent (0) -> Normal (2)
    int target = 2;
    if (state.ringerMode == 2) {
      target = 1;
    } else if (state.ringerMode == 1) {
      target = 0;
    } else {
      target = 2;
    }

    final originalMode = state.ringerMode;
    state = state.copyWith(ringerMode: target);

    try {
      final success = await _channel.invokeMethod<bool>('setRingerMode', {'mode': target});
      if (success == false) {
        state = state.copyWith(ringerMode: originalMode);
        await openDndAccessSettings();
      }
    } catch (_) {
      state = state.copyWith(ringerMode: originalMode);
    }
    await refreshData();
  }

  Future<void> setBrightness(double value) async {
    state = state.copyWith(brightness: value);
    final int brightnessInt = (value * 255.0).round().clamp(0, 255);
    try {
      final success = await _channel.invokeMethod<bool>('setBrightness', {'brightness': brightnessInt});
      if (success == false) {
        await openWriteSettingsPermission();
      }
    } catch (_) {}
  }

  Future<void> setVolume(double value) async {
    state = state.copyWith(volume: value);
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('getControlCenterData');
      if (res != null) {
        final maxVol = (res['maxVolume'] as num?)?.toDouble() ?? 15.0;
        final volumeInt = (value * maxVol).round().clamp(0, maxVol.round());
        await _channel.invokeMethod('setVolume', {'volume': volumeInt});
      }
    } catch (_) {}
  }

  Future<void> openWriteSettingsPermission() async {
    try {
      await _channel.invokeMethod('openWriteSettingsPermissionSettings');
    } catch (_) {}
  }

  Future<void> openDndAccessSettings() async {
    try {
      await _channel.invokeMethod('openDndAccessSettings');
    } catch (_) {}
  }

  Future<void> openWifiSettings() async {
    try {
      await _channel.invokeMethod('openWifiSettings');
    } catch (_) {}
  }

  Future<void> openMobileDataSettings() async {
    try {
      await _channel.invokeMethod('openMobileDataSettings');
    } catch (_) {}
  }

  Future<void> openBluetoothSettings() async {
    try {
      await _channel.invokeMethod('openBluetoothSettings');
    } catch (_) {}
  }

  Future<void> openAirplaneModeSettings() async {
    try {
      await _channel.invokeMethod('openAirplaneModeSettings');
    } catch (_) {}
  }
}

final controlCenterProvider = StateNotifierProvider<ControlCenterStateNotifier, ControlCenterState>((ref) {
  return ControlCenterStateNotifier();
});
