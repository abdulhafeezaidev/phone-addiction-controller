import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/app_logger.dart';
import '../../domain/models/emergency_override_state.dart';
import '../interfaces/emergency_override_service.dart';
import '../interfaces/storage_service.dart';
import '../interfaces/password_service.dart';
import '../native_bridge_service.dart';

class EmergencyOverrideServiceImpl implements EmergencyOverrideService {
  final StorageService _storageService;
  final PasswordService _passwordService;
  final NativeBridgeService _nativeBridgeService;

  Timer? _checkTimer;

  EmergencyOverrideServiceImpl({
    required StorageService storageService,
    required PasswordService passwordService,
    required NativeBridgeService nativeBridgeService,
  })  : _storageService = storageService,
        _passwordService = passwordService,
        _nativeBridgeService = nativeBridgeService {
    _startPeriodicCheck();
  }

  void _startPeriodicCheck() {
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      checkStateAndProgress();
    });
  }

  @override
  Duration get reflectionDuration {
    final mins = _storageService.get<dynamic>(
      AppConstants.settingsBox,
      AppConstants.emergencyReflectionMinsKey,
    ) as int?;
    return Duration(minutes: mins ?? 15);
  }

  @override
  Duration get overrideDuration {
    final hours = _storageService.get<dynamic>(
      AppConstants.settingsBox,
      AppConstants.emergencyOverrideHoursKey,
    ) as int?;
    return Duration(hours: hours ?? 24);
  }

  @override
  Duration get cooldownDuration {
    final hours = _storageService.get<dynamic>(
      AppConstants.settingsBox,
      AppConstants.emergencyCooldownHoursKey,
    ) as int?;
    return Duration(hours: hours ?? 24);
  }

  @override
  Future<void> updateProtocolSettings({
    int? reflectionMinutes,
    int? overrideHours,
    int? cooldownHours,
  }) async {
    if (reflectionMinutes != null) {
      await _storageService.put(
        AppConstants.settingsBox,
        AppConstants.emergencyReflectionMinsKey,
        reflectionMinutes,
      );
    }
    if (overrideHours != null) {
      await _storageService.put(
        AppConstants.settingsBox,
        AppConstants.emergencyOverrideHoursKey,
        overrideHours,
      );
    }
    if (cooldownHours != null) {
      await _storageService.put(
        AppConstants.settingsBox,
        AppConstants.emergencyCooldownHoursKey,
        cooldownHours,
      );
    }
  }

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
    final hashedAnswer = sha256.convert(utf8.encode(normalized)).toString();

    await _storageService.put<String>(
      AppConstants.settingsBox,
      'emergency_challenge',
      challenge,
    );
    await _storageService.put<String>(
      AppConstants.settingsBox,
      'emergency_answer_hash',
      hashedAnswer,
    );
  }

  @override
  Future<String?> getRecoveryChallenge() async {
    final custom = _storageService.get<dynamic>(
      AppConstants.settingsBox,
      'emergency_challenge',
    ) as String?;
    if (custom != null && custom.isNotEmpty) return custom;

    final admin = await _passwordService.getAdminSettings();
    if (admin?.recoveryChallenge != null && admin!.recoveryChallenge!.isNotEmpty) {
      return admin.recoveryChallenge;
    }
    return "What is your emergency override security answer?";
  }

  @override
  Future<bool> verifyRecoveryAnswer(String plainAnswer) async {
    final normalized = plainAnswer.trim().toLowerCase();
    final hash = sha256.convert(utf8.encode(normalized)).toString();

    var storedHash = _storageService.get<dynamic>(
      AppConstants.settingsBox,
      'emergency_answer_hash',
    ) as String?;
    if (storedHash == null) {
      final admin = await _passwordService.getAdminSettings();
      storedHash = admin?.recoveryAnswerHash;
    }

    final hasConfiguredHash = storedHash != null && storedHash.isNotEmpty;
    final isMatch = hasConfiguredHash
        ? storedHash == hash
        : normalized == 'i need emergency access';

    if (isMatch) {
      final state = await getOverrideState();
      final now = DateTime.now();

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
    AppLogger.info('Emergency Override reflection timer cancelled.');
  }

  @override
  Future<void> checkStateAndProgress() async {
    final state = await getOverrideState();
    final now = DateTime.now();

    if (state.isInReflection && state.reflectionStartTime != null) {
      final elapsed = now.difference(state.reflectionStartTime!);
      if (elapsed >= reflectionDuration) {
        await _activateOverrideInternal(state, now);
        return;
      }
    }

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

    await _nativeBridgeService.setEmergencyOverrideActive(
      active: true,
      expirationTimeMs: endTime.millisecondsSinceEpoch,
    );

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

    await _nativeBridgeService.setEmergencyOverrideActive(
      active: false,
      expirationTimeMs: 0,
    );

    AppLogger.info('Emergency Override deactivated.');
  }

  void dispose() {
    _checkTimer?.cancel();
  }
}
