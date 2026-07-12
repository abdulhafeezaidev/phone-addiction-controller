import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/providers/statistics_providers.dart';

class StatisticsPage extends ConsumerWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(appStatisticsProvider);
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFF121414),
      appBar: AppBar(
        title: const Text('Focus Stats'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF5E6AD2)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: statsAsync.when(
          data: (stats) {
            final weeklyHours = stats.weeklyFocusDuration.inHours;
            final weeklyMins = stats.weeklyFocusDuration.inMinutes % 60;
            final weeklyDurStr = weeklyHours > 0 ? '${weeklyHours}h ${weeklyMins}m' : '${weeklyMins}m';

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              children: [
                // Viewing Area: Description
                const Text(
                  'Your productivity breakdown.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFFC6C5D5),
                  ),
                ),
                const SizedBox(height: 24),

                // Weekly Summary Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF212123),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: const Color(0xFF2C2C2E), width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Weekly Summary',
                                style: tt.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFE3E2E2),
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Rolling 7-day focus overview',
                                style: TextStyle(fontSize: 12, color: Color(0xFFC6C5D5)),
                              ),
                            ],
                          ),
                          Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: Color(0xFF1E2020),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.local_fire_department_rounded,
                              color: Color(0xFF5E6AD2),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        weeklyDurStr,
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF5E6AD2),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: const [
                          Icon(Icons.trending_up_rounded, color: Color(0xFFFFB867), size: 16),
                          SizedBox(width: 4),
                          Text(
                            'You focused more than last week.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFFFFB867),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Bar Chart
                      SizedBox(
                        height: 96,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildBar('M', 0.4, false),
                            _buildBar('T', 0.65, false),
                            _buildBar('W', 0.8, false),
                            _buildBar('T', 1.0, true),
                            _buildBar('F', 0.5, false),
                            _buildBar('S', 0.2, false),
                            _buildBar('S', 0.1, false),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Bento Grid for Streak & Total Sessions
                Row(
                  children: [
                    // Longest Session / Current Streak
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF212123),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: const Color(0xFF2C2C2E), width: 1),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF1E2020),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.timer_outlined, color: Color(0xFFE3E2E2), size: 18),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Current Streak',
                                    style: TextStyle(fontSize: 12, color: Color(0xFFC6C5D5)),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${stats.currentStreakDays} Days',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFE3E2E2),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Focus Score / Sessions Completed
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF212123),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: const Color(0xFF2C2C2E), width: 1),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF1E2020),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.verified_outlined, color: Color(0xFF5E6AD2), size: 18),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Total Sessions',
                                    style: TextStyle(fontSize: 12, color: Color(0xFFC6C5D5)),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${stats.totalSessionsCompleted} Completed',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFE3E2E2),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Top Focus Apps Card (Blocked Apps)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF212123),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: const Color(0xFF2C2C2E), width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Top Blocked Apps',
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFE3E2E2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (stats.mostBlockedApps.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24.0),
                          child: Center(
                            child: Text(
                              'No blocked attempts recorded yet.',
                              style: TextStyle(color: Color(0xFFC6C5D5)),
                            ),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: stats.mostBlockedApps.length.clamp(0, 5),
                          itemBuilder: (context, index) {
                            final entry = stats.mostBlockedApps.entries.elementAt(index);
                            final packageName = entry.key;
                            final blockCount = entry.value;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E2020),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.block_rounded, color: Color(0xFFCF6679), size: 20),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          packageName.split('.').last,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFFE3E2E2),
                                          ),
                                        ),
                                        Text(
                                          packageName,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFFC6C5D5),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '$blockCount blocks',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFE3E2E2),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error loading stats: $e')),
        ),
      ),
    );
  }

  Widget _buildBar(String label, double fillRatio, bool isHighlight) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            height: (72 * fillRatio).clamp(4.0, 72.0),
            width: 12,
            decoration: BoxDecoration(
              color: isHighlight ? const Color(0xFF5E6AD2) : const Color(0xFF343535),
              borderRadius: BorderRadius.circular(4),
              boxShadow: isHighlight
                  ? [
                      BoxShadow(
                        color: const Color(0xFF5E6AD2).withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 0),
                      )
                    ]
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
              color: isHighlight ? const Color(0xFF5E6AD2) : const Color(0xFFC6C5D5),
            ),
          ),
        ],
      ),
    );
  }
}
