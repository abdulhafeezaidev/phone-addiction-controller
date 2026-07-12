import '../../domain/models/focus_session.dart';

/// Service for managing Focus Session lifecycle and tracking.
abstract class SessionTrackingService {
  /// Starts a new focus session.
  Future<FocusSession> startSession({
    SessionTriggerType triggerType = SessionTriggerType.manual,
    String? routineId,
  });

  /// Ends the currently active focus session.
  Future<FocusSession?> endSession({
    SessionStopType stopType = SessionStopType.manual,
  });

  /// Retrieves the currently active focus session, if any.
  Future<FocusSession?> getActiveSession();

  /// Retrieves all recorded focus sessions.
  Future<List<FocusSession>> getAllSessions();

  /// Retrieves focus sessions that started within the specified date range.
  Future<List<FocusSession>> getSessionsInDateRange(DateTime start, DateTime end);

  /// Records a blocked attempt for a specific package during the active session.
  Future<void> recordBlockedAttempt(String packageName);

  /// Clears all session history.
  Future<void> clearHistory();
}
