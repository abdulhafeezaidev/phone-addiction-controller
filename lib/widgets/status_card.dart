import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// A gradient status card used on the Home page to show Focus Mode status.
class StatusCard extends StatelessWidget {
  const StatusCard({
    super.key,
    required this.isActive,
    this.sessionDuration,
  });

  final bool isActive;
  final Duration? sessionDuration;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isActive
              ? [const Color(0xFF6C63FF), const Color(0xFF9C27B0)]
              : [const Color(0xFF1E1E2A), const Color(0xFF2A2A3A)],
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: const Color(0xFF6C63FF).withOpacity(0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                )
              ]
            : [],
        border: Border.all(
          color: isActive
              ? Colors.white.withOpacity(0.2)
              : cs.outline.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isActive ? Icons.shield_rounded : Icons.shield_outlined,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isActive ? 'Focus Mode Active' : 'Focus Mode Off',
                    style: tt.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isActive
                        ? 'Distractions are blocked'
                        : 'Tap Focus to start a session',
                    style: tt.bodyMedium?.copyWith(
                      color: Colors.white.withOpacity(0.75),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (isActive)
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Color(0xFF4CAF7D),
                    shape: BoxShape.circle,
                  ),
                )
                    .animate(onPlay: (c) => c.repeat())
                    .scaleXY(begin: 0.8, end: 1.2, duration: 1000.ms)
                    .then()
                    .scaleXY(begin: 1.2, end: 0.8, duration: 1000.ms),
            ],
          ),
          if (isActive && sessionDuration != null) ...[
            const SizedBox(height: 20),
            Divider(color: Colors.white.withOpacity(0.15)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(
                  label: 'Duration',
                  value: _formatDuration(sessionDuration!),
                ),
                _StatItem(label: 'Apps Blocked', value: '—'),
                _StatItem(label: 'Status', value: 'Active'),
              ],
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) return '${h}h ${m}m';
    return '${m}m ${s}s';
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withOpacity(0.6),
              ),
        ),
      ],
    );
  }
}
