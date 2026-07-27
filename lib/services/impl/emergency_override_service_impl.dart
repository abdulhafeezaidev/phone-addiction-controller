import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/app_logger.dart';
import '../../domain/models/emergency_override_state.dart';
import '../interfaces/emergency_override_service.dart';
import '../interfaces/storage_service.dart';
import '../interfaces/password_service.dart';
import '../interfaces/schedule_service.dart';
import '../interfaces/focus_session_manager.dart';

class EmergencyOverrideServiceImpl implements EmergencyOverrideService {
  final StorageService _storageService;
  final PasswordService _passwordService;
  final ScheduleService _scheduleService;
  final FocusSessionManager _focusSessionManager;

  Timer? _checkTimer;

  EmergencyOverrideServiceImpl({
    required StorageService storageService,
    required PasswordService passwordService,
    required ScheduleService scheduleService,
    required FocusSessionManager focusSessionManager,
  })  : _storageService = storageService,
        _passwordService = passwordService,
        _scheduleService = scheduleService,
        _focusSessionManager = focusSessionManager {
    // Check on init if periodic monitoring is needed
    _checkAndStartTimerIfNeeded();
  }

  Future<void> _checkAndStartTimerIfNeeded() async {
    final state = await getOverrideState();
    if (state.isInReflection || state.isOverrideActive) {
      _startPeriodicCheck();
    }
  }

  void _startPeriodicCheck() {
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      checkStateAndProgress();
    });
  }

  void _stopPeriodicCheck() {
    _checkTimer?.cancel();
    _checkTimer = null;
  }

  @override
  Duration get reflectionDuration => const Duration(minutes: 15);

  @override
  Duration get overrideDuration => const Duration(hours: 24);

  @override
  Duration get cooldownDuration => const Duration(hours: 24);

  @override
  Future<EmergencyOverrideState> getOverrideState() async {
    final state = _storageService.get<EmergencyOverrideState>(
      AppConstants.emergencyOverrideBox,
      'state',
    );
    return state ?? EmergencyOverrideState();
  }

  Future<void> _saveState(EmergencyOverrideState state) async {
    await _storageService.put(
      AppConstants.emergencyOverrideBox,
      'state',
      state,
    );
  }

  @override
  Future<void> setRecoveryChallenge(String challenge, String plainAnswer) async {
    final normalized = plainAnswer.trim().toLowerCase();
    // Use HMAC-SHA256 with the challenge as key to add uniqueness (pseudo-salt)
    final hmacInstance = Hmac(sha256, utf8.encode(challenge));
    final hashedAnswer = hmacInstance.convert(utf8.encode(normalized)).toString();

    final current = await _passwordService.getAdminSettings();
    if (current != null) {
      final updated = current.copyWith(
        recoveryChallenge: challenge,
        recoveryAnswerHash: hashedAnswer,
      );
      await _storageService.put(
        AppConstants.adminSettingsBox,
        AppConstants.adminPasswordKey,
        updated,
      );
    }
  }

  @override
  Future<String?> getRecoveryChallenge() async {
    final settings = await _passwordService.getAdminSettings();
    return settings?.recoveryChallenge;
  }

  @override
  Future<bool> verifyRecoveryAnswer(String plainAnswer) async {
    final settings = await _passwordService.getAdminSettings();
    if (settings == null || settings.recoveryAnswerHash == null) {
      return false;
    }

    final normalized = plainAnswer.trim().toLowerCase();
    final challenge = settings.recoveryChallenge ?? '';
    final hmacInstance = Hmac(sha256, utf8.encode(challenge));
    final hash = hmacInstance.convert(utf8.encode(normalized)).toString();

    if (settings.recoveryAnswerHash == hash) {
      final state = await getOverrideState();
      final now = DateTime.now();

      // Check cooldown
      if (state.lastActivationTime != null) {
        final cooldownElapsed = now.difference(state.lastActivationTime!);
        if (cooldownElapsed < cooldownDuration) {
          AppLogger.warning('Emergency override activation blocked by active cooldown.');
          return false;
        }
      }

      final newState = state.copyWith(
        isInReflection: true,
        reflectionStartTime: now,
      );
      await _saveState(newState);
      _startPeriodicCheck();
      AppLogger.info('Emergency override verified. Reflection timer started.');
      return true;
    }

    return false;
  }

  @override
  Future<void> startReflection() async {
    final state = await getOverrideState();
    final newState = state.copyWith(
      isInReflection: true,
      reflectionStartTime: DateTime.now(),
    );
    await _saveState(newState);
  }

  @override
  Future<void> cancelReflection() async {
    final state = await getOverrideState();
    final newState = state.copyWith(
      isInReflection: false,
      reflectionStartTime: null,
    );
    await _saveState(newState);
    _stopPeriodicCheck();
    AppLogger.info('Emergency Override reflection timer cancelled.');
  }

  @override
  Future<void> checkStateAndProgress() async {
    final state = await getOverrideState();
    final now = DateTime.now();

    // 1. Check reflection period expiration
    if (state.isInReflection && state.reflectionStartTime != null) {
      final elapsed = now.difference(state.reflectionStartTime!);
      if (elapsed >= reflectionDuration) {
        await _activateOverrideInternal(state, now);
        return;
      }
    }

    // 2. Check override expiration
    if (state.isOverrideActive && state.overrideStartTime != null) {
      final elapsed = now.difference(state.overrideStartTime!);
      if (elapsed >= overrideDuration) {
        await deactivateOverride();
        return;
      }
    }
  }

  Future<void> _activateOverrideInternal(EmergencyOverrideState state, DateTime now) async {
    final endTime = now.add(overrideDuration);
    final history = List<DateTime>.from(state.activationHistory)..add(now);

    final newState = state.copyWith(
      isInReflection: false,
      reflectionStartTime: null,
      isOverrideActive: true,
      overrideStartTime: now,
      lastActivationTime: now,
      activationHistory: history,
    );
    await _saveState(newState);

    const channel = MethodChannel('com.personal.phone_addiction_controller/accessibility');
    try {
      await channel.invokeMethod('setEmergencyOverrideActive', {
        'active': true,
        'expirationTime': endTime.millisecondsSinceEpoch,
      });
    } catch (e) {
      AppLogger.error('Failed to sync emergency override to native', error: e);
    }

    AppLogger.info('Emergency Override activated until $endTime');
  }

  @override
  Future<void> deactivateOverride() async {
    final state = await getOverrideState();
    final newState = state.copyWith(
      isInReflection: false,
      reflectionStartTime: null,
      isOverrideActive: false,
      overrideStartTime: null,
    );
    await _saveState(newState);

    const channel = MethodChannel('com.personal.phone_addiction_controller/accessibility');
    try {
      await channel.invokeMethod('setEmergencyOverrideActive', {
        'active': false,
        'expirationTime': 0,
      });
    } catch (e) {
      AppLogger.error('Failed to sync override deactivation to native', error: e);
    }

    _stopPeriodicCheck();
    AppLogger.info('Emergency Override deactivated.');

    // If a Focus schedule should currently be active, start a new Focus Session
    final isRoutineActive = await _scheduleService.isAnyRoutineActive();
    if (isRoutineActive) {
      AppLogger.info('Focus routine should be active. Starting a new Focus Session.');
      await _focusSessionManager.startSession(duration: const Duration(minutes: 25));
    }
  }

  void dispose() {
    _checkTimer?.cancel();
  }
}
