import '../../domain/models/focus_session_snapshot.dart';

abstract class FocusSessionManager {
  /// Retrieves the currently active focus session snapshot, if any.
  Future<FocusSessionSnapshot?> getActiveSnapshot();

  /// Starts a focus session with a snapshot of the current configuration.
  Future<FocusSessionSnapshot> startSession({
    required Duration duration,
    String? scheduleId,
  });

  /// Ends the currently active focus session and clears the active snapshot.
  Future<void> endSession();

  /// Updates the running session's snapshot.
  Future<void> updateActiveSnapshot(FocusSessionSnapshot snapshot);

  /// Restores session state from the persisted snapshot (e.g. on reboot/restart).
  Future<void> restoreSessionState();
}
