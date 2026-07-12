import '../../domain/models/emergency_override_state.dart';

abstract class EmergencyOverrideService {
  /// Get current override state.
  Future<EmergencyOverrideState> getOverrideState();

  /// Set the recovery challenge and answer during setup.
  Future<void> setRecoveryChallenge(String challenge, String plainAnswer);

  /// Get the configured recovery challenge.
  Future<String?> getRecoveryChallenge();

  /// Verifies recovery answer. If correct, starts reflection timer.
  Future<bool> verifyRecoveryAnswer(String plainAnswer);

  /// Starts the reflection timer manually.
  Future<void> startReflection();

  /// Cancel the pending reflection timer.
  Future<void> cancelReflection();

  /// Checks reflection and override state, progresses transitions if expired.
  Future<void> checkStateAndProgress();

  /// Deactivates override immediately, restoring Focus protections.
  Future<void> deactivateOverride();

  /// Configurable settings
  Duration get reflectionDuration;
  Duration get overrideDuration;
  Duration get cooldownDuration;
}
