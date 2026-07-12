import '../../domain/models/focus_session.dart';
import '../interfaces/session_tracking_service.dart';
import '../interfaces/statistics_service.dart';

class StatisticsServiceImpl implements StatisticsService {
  StatisticsServiceImpl({required this.sessionTrackingService});

  final SessionTrackingService sessionTrackingService;

  @override
  Future<AppStatistics> getStatistics() async {
    final sessions = await sessionTrackingService.getAllSessions();
    
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    // 1 = Monday, 7 = Sunday
    final weekday = now.weekday;
    final weekStart = todayStart.subtract(Duration(days: weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);

    Duration todayDuration = Duration.zero;
    Duration weeklyDuration = Duration.zero;
    Duration monthlyDuration = Duration.zero;
    Duration allTimeDuration = Duration.zero;

    int totalBlocked = 0;
    int completedSessions = 0;
    final Map<String, int> blockedApps = {};

    // For streak calculation
    final Set<DateTime> activeDays = {};

    for (final session in sessions) {
      if (session.isActive) continue; // Only count completed/ended sessions

      completedSessions++;
      totalBlocked += session.blockedAttempts;

      // Aggregate blocked apps
      session.blockedAppCounts.forEach((pkg, count) {
        blockedApps[pkg] = (blockedApps[pkg] ?? 0) + count;
      });

      final dur = session.duration ?? Duration.zero;
      allTimeDuration += dur;

      final sTime = session.startTime;
      final sessionDay = DateTime(sTime.year, sTime.month, sTime.day);
      activeDays.add(sessionDay);

      if (sTime.isAfter(todayStart) || sTime.isAtSameMomentAs(todayStart)) {
        todayDuration += dur;
      }
      if (sTime.isAfter(weekStart) || sTime.isAtSameMomentAs(weekStart)) {
        weeklyDuration += dur;
      }
      if (sTime.isAfter(monthStart) || sTime.isAtSameMomentAs(monthStart)) {
        monthlyDuration += dur;
      }
    }

    // Sort blocked apps
    final sortedBlockedApps = Map.fromEntries(
      blockedApps.entries.toList()..sort((e1, e2) => e2.value.compareTo(e1.value)),
    );

    // Calculate streaks
    final streaks = _calculateStreaks(activeDays, todayStart);

    return AppStatistics(
      todayFocusDuration: todayDuration,
      weeklyFocusDuration: weeklyDuration,
      monthlyFocusDuration: monthlyDuration,
      allTimeFocusDuration: allTimeDuration,
      currentStreakDays: streaks.current,
      longestStreakDays: streaks.longest,
      totalSessionsCompleted: completedSessions,
      totalBlockedAttempts: totalBlocked,
      mostBlockedApps: sortedBlockedApps,
    );
  }

  @override
  Future<Map<String, int>> getTopBlockedApps(int limit) async {
    final stats = await getStatistics();
    final entries = stats.mostBlockedApps.entries.take(limit).toList();
    return Map.fromEntries(entries);
  }

  _StreakResult _calculateStreaks(Set<DateTime> activeDays, DateTime today) {
    if (activeDays.isEmpty) return _StreakResult(0, 0);

    final sortedDays = activeDays.toList()..sort((a, b) => b.compareTo(a));
    
    int currentStreak = 0;
    int longestStreak = 0;
    int tempStreak = 0;
    
    // Check if streak is alive (either played today or yesterday)
    DateTime checkDay = today;
    bool isAlive = true;
    
    if (activeDays.contains(today)) {
      currentStreak = 1;
      checkDay = today.subtract(const Duration(days: 1));
    } else if (activeDays.contains(today.subtract(const Duration(days: 1)))) {
      currentStreak = 1; // Yesterday is start of counting back
      checkDay = today.subtract(const Duration(days: 2));
    } else {
      isAlive = false;
    }

    if (isAlive) {
      while (activeDays.contains(checkDay)) {
        currentStreak++;
        checkDay = checkDay.subtract(const Duration(days: 1));
      }
    }

    // Calculate longest
    DateTime? prev;
    for (int i = 0; i < sortedDays.length; i++) {
      final d = sortedDays[i]; // descending order
      if (prev == null) {
        tempStreak = 1;
      } else {
        final diff = prev.difference(d).inDays;
        if (diff == 1) {
          tempStreak++;
        } else if (diff > 1) {
          if (tempStreak > longestStreak) longestStreak = tempStreak;
          tempStreak = 1;
        }
      }
      prev = d;
    }
    if (tempStreak > longestStreak) longestStreak = tempStreak;

    return _StreakResult(currentStreak, longestStreak);
  }
}

class _StreakResult {
  final int current;
  final int longest;
  _StreakResult(this.current, this.longest);
}
