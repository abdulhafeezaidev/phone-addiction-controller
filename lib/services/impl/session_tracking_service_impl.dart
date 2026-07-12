import 'package:uuid/uuid.dart';
import '../../domain/models/focus_session.dart';
import '../interfaces/session_tracking_service.dart';
import '../interfaces/storage_service.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/app_logger.dart';

class SessionTrackingServiceImpl implements SessionTrackingService {
  SessionTrackingServiceImpl({required this.storageService});

  final StorageService storageService;
  final _uuid = const Uuid();

  @override
  Future<FocusSession> startSession({
    SessionTriggerType triggerType = SessionTriggerType.manual,
    String? routineId,
  }) async {
    // Check if there's already an active session
    var activeSession = await getActiveSession();
    if (activeSession != null) {
      AppLogger.warning('Attempted to start a session but one is already active.');
      return activeSession;
    }

    final session = FocusSession(
      id: _uuid.v4(),
      startTime: DateTime.now(),
      enabled: true,
      triggerType: triggerType,
      routineId: routineId,
    );

    await storageService.put(
      AppConstants.focusSessionBox,
      session.id,
      session,
    );

    AppLogger.info('Started new focus session: ${session.id}');
    return session;
  }

  @override
  Future<FocusSession?> endSession({
    SessionStopType stopType = SessionStopType.manual,
  }) async {
    final activeSession = await getActiveSession();
    if (activeSession == null) {
      AppLogger.warning('Attempted to end session but none is active.');
      return null;
    }

    final endedSession = activeSession.copyWith(
      endTime: DateTime.now(),
      enabled: false,
      stopType: stopType,
    );

    await storageService.put(
      AppConstants.focusSessionBox,
      endedSession.id,
      endedSession,
    );

    AppLogger.info('Ended focus session: ${endedSession.id}');
    return endedSession;
  }

  @override
  Future<FocusSession?> getActiveSession() async {
    final sessions = await getAllSessions();
    try {
      return sessions.firstWhere((s) => s.isActive);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<FocusSession>> getAllSessions() async {
    final sessions = storageService.getAll<FocusSession>(AppConstants.focusSessionBox);
    final list = sessions.toList();
    // Sort descending by start time
    list.sort((a, b) => b.startTime.compareTo(a.startTime));
    return list;
  }

  @override
  Future<List<FocusSession>> getSessionsInDateRange(DateTime start, DateTime end) async {
    final sessions = await getAllSessions();
    return sessions.where((s) => 
      s.startTime.isAfter(start) && s.startTime.isBefore(end)
    ).toList();
  }

  @override
  Future<void> recordBlockedAttempt(String packageName) async {
    final activeSession = await getActiveSession();
    if (activeSession != null) {
      activeSession.recordBlockedAttempt(packageName);
      await storageService.put(
        AppConstants.focusSessionBox,
        activeSession.id,
        activeSession,
      );
      AppLogger.debug('Recorded block attempt for $packageName in session ${activeSession.id}');
    }
  }

  @override
  Future<void> clearHistory() async {
    await storageService.clearBox(AppConstants.focusSessionBox);
    AppLogger.info('Cleared all session history.');
  }
}
