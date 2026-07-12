import 'package:equatable/equatable.dart';

/// Aggregated statistics for the application.
class AppStatistics extends Equatable {
  const AppStatistics({
    required this.todayFocusDuration,
    required this.weeklyFocusDuration,
    required this.monthlyFocusDuration,
    required this.allTimeFocusDuration,
    required this.currentStreakDays,
    required this.longestStreakDays,
    required this.totalSessionsCompleted,
    required this.totalBlockedAttempts,
    required this.mostBlockedApps,
  });

  final Duration todayFocusDuration;
  final Duration weeklyFocusDuration;
  final Duration monthlyFocusDuration;
  final Duration allTimeFocusDuration;
  
  final int currentStreakDays;
  final int longestStreakDays;
  final int totalSessionsCompleted;
  final int totalBlockedAttempts;
  
  /// Package name mapped to block count, sorted by count descending.
  final Map<String, int> mostBlockedApps;

  @override
  List<Object?> get props => [
        todayFocusDuration,
        weeklyFocusDuration,
        monthlyFocusDuration,
        allTimeFocusDuration,
        currentStreakDays,
        longestStreakDays,
        totalSessionsCompleted,
        totalBlockedAttempts,
        mostBlockedApps,
      ];
}

/// Service for calculating focus mode statistics.
abstract class StatisticsService {
  /// Computes all aggregated statistics.
  Future<AppStatistics> getStatistics();
  
  /// Helper to get the top N most blocked apps.
  Future<Map<String, int>> getTopBlockedApps(int limit);
}
