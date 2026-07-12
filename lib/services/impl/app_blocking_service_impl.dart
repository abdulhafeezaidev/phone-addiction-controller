import 'dart:async';
import 'package:flutter/services.dart';

import '../interfaces/allowed_apps_repository.dart';
import '../interfaces/app_blocking_service.dart';

/// Concrete implementation of [AppBlockingService].
class AppBlockingServiceImpl implements AppBlockingService {
  final AllowedAppsRepository _allowedAppsRepository;
  static const _methodChannel = MethodChannel('com.personal.phone_addiction_controller/accessibility');
  static const _blockedEventChannel = EventChannel('com.personal.phone_addiction_controller/blocked_events');

  bool _isBlocking = false;
  final _blockedAppsController = StreamController<Map<String, dynamic>>.broadcast();
  StreamSubscription? _blockedEventSub;

  AppBlockingServiceImpl(this._allowedAppsRepository) {
    _initBlockedEventsListener();
    _checkInitialState();
  }

  void _initBlockedEventsListener() {
    _blockedEventSub = _blockedEventChannel.receiveBroadcastStream().listen((event) {
      if (event is Map) {
        final data = Map<String, dynamic>.from(event);
        _blockedAppsController.add(data);
      }
    });
  }

  Future<void> _checkInitialState() async {
    try {
      final active = await _methodChannel.invokeMethod<bool>('isFocusModeActive');
      _isBlocking = active ?? false;
    } catch (e) {
      // Ignore
    }
  }

  @override
  Future<void> startBlocking() async {
    // 1. Get all allowed packages from storage
    final allowedApps = _allowedAppsRepository.getAllowedApps();
    final allowedPackages = allowedApps.map((a) => a.packageName).toList();
    
    // 2. Send allowed apps to native
    await _methodChannel.invokeMethod('updateAllowedApps', {
      'apps': allowedPackages,
      'alwaysAllowedApps': <String>[],
    });
    
    // 3. Start focus mode
    await _methodChannel.invokeMethod('startFocusMode');
    _isBlocking = true;
  }

  @override
  Future<void> stopBlocking() async {
    await _methodChannel.invokeMethod('stopFocusMode');
    _isBlocking = false;
  }

  @override
  Future<List<String>> getBlockedPackages() async {
    return []; // We block dynamically based on AllowedApps in native layer
  }

  @override
  Future<void> updateAllowedApps(List<String> packageNames) async {
    await _methodChannel.invokeMethod('updateAllowedApps', {
      'apps': packageNames,
      'alwaysAllowedApps': <String>[],
    });
  }

  @override
  bool get isBlocking => _isBlocking;

  @override
  Stream<Map<String, dynamic>> get blockedEventsStream => _blockedAppsController.stream;

  void dispose() {
    _blockedEventSub?.cancel();
    _blockedAppsController.close();
  }
}
