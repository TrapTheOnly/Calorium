import 'package:flutter/material.dart';
import '../models/fasting_settings.dart';

class FastingOverviewCard extends StatelessWidget {
  const FastingOverviewCard({
    super.key,
    required this.status,
    required this.settings,
    required this.streakDays,
    required this.onConfigure,
  });

  final FastingStatus status;
  final FastingSettings settings;
  final int streakDays;
  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final duration = _timeUntilWindowEnds(status);
    final formattedDuration = _formatDuration(duration);
    final progress = _fastProgress(status, settings);
    final isFasting = status.phase == FastingPhase.fasting;
    final phaseLabel = isFasting ? 'Fasting now' : 'Eating window';
    final actionLabel = isFasting ? 'Fast ends in' : 'Eating ends in';
    final streakLabel = streakDays == 1 ? 'day' : 'days';

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withOpacity(0.4),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Intermittent Fasting',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    _buildPhaseChip(context, phaseLabel, isFasting),
                  ],
                ),
              ),
              IconButton(
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
                icon: Icon(Icons.edit_outlined, color: colorScheme.primary),
                tooltip: 'Adjust fasting schedule',
                onPressed: onConfigure,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _MetricTile(
                  icon: Icons.hourglass_bottom,
                  iconColor: colorScheme.primary,
                  title: actionLabel,
                  value: formattedDuration,
          subtitle: isFasting
              ? 'Stay focused until your eating window returns.'
              : 'Wrap up meals before fasting resumes.',
                ),
              ),
              Container(
                width: 1,
                height: 64,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                color: colorScheme.outlineVariant.withOpacity(0.4),
              ),
              Expanded(
                child: _MetricTile(
                  icon: Icons.local_fire_department,
                  iconColor: colorScheme.secondary,
                  title: 'Streak',
                  value: '$streakDays $streakLabel',
                  subtitle: 'Consecutive days staying on schedule.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: colorScheme.primary.withOpacity(0.08),
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhaseChip(BuildContext context, String label, bool isFasting) {
    final colorScheme = Theme.of(context).colorScheme;
    final background =
        isFasting
            ? colorScheme.primary.withOpacity(0.12)
            : colorScheme.secondary.withOpacity(0.12);
    final foreground = isFasting ? colorScheme.primary : colorScheme.secondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isFasting ? Icons.timer_outlined : Icons.restaurant,
            size: 16,
            color: foreground,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }

  Duration _timeUntilWindowEnds(FastingStatus status) {
    final now = status.reference;
    final remaining = status.nextChange.difference(now);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  double _fastProgress(FastingStatus status, FastingSettings settings) {
    if (status.phase != FastingPhase.fasting) {
      return 0;
    }
    final totalSeconds = settings.fastingDuration.inSeconds;
    if (totalSeconds <= 0) return 0;
    final elapsed = status.reference.difference(status.phaseStart).inSeconds;
    return (elapsed / totalSeconds).clamp(0.0, 1.0);
  }

  String _formatDuration(Duration duration) {
    final totalMinutes = duration.inMinutes;
    if (totalMinutes <= 0) {
      return 'Less than 1m';
    }
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours == 0) {
      return '${minutes.toString().padLeft(2, '0')}m';
    }
    return '${hours.toString().padLeft(2, '0')}h ${minutes.toString().padLeft(2, '0')}m';
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
