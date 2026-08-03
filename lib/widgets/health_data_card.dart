import 'package:flutter/material.dart';
import '../models/health_data.dart';
import '../utils/app_layout.dart';

class HealthDataCard extends StatelessWidget {
  final HealthData healthData;
  final bool showWorkoutSessions;

  const HealthDataCard({
    super.key,
    required this.healthData,
    this.showWorkoutSessions = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppLayout.radius),
      ),
      padding: const EdgeInsets.all(AppLayout.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Health & fitness',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  icon: Icons.local_fire_department_rounded,
                  iconColor: scheme.primary,
                  label: 'Burned',
                  value: '${healthData.totalCaloriesBurned.round()}',
                  unit: 'kcal',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricTile(
                  icon: Icons.timer_outlined,
                  iconColor: scheme.tertiary,
                  label: 'Active',
                  value: '${healthData.totalWorkoutTime.round()}',
                  unit: 'min',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricTile(
                  icon: Icons.directions_walk_rounded,
                  iconColor: scheme.secondary,
                  label: 'Steps',
                  value: '${healthData.totalSteps}',
                  unit: 'today',
                ),
              ),
            ],
          ),
          if (showWorkoutSessions && healthData.workoutSessions.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildWorkoutSessions(context),
          ],
        ],
      ),
    );
  }

  Widget _buildWorkoutSessions(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Workouts',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: scheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(height: 6),
        ...healthData.workoutSessions.take(3).map((session) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '${session.type} · ${session.duration.round()} min',
              style: TextStyle(
                fontSize: 12,
                color: scheme.onPrimaryContainer.withOpacity(0.8),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.unit,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onCard = scheme.onSurface;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 16),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: onCard.withOpacity(0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: onCard,
            ),
          ),
          Text(
            unit,
            style: TextStyle(fontSize: 11, color: onCard.withOpacity(0.7)),
          ),
        ],
      ),
    );
  }
}

/// Compact horizontal banner instead of a large permission promo card.
class HealthPermissionBanner extends StatelessWidget {
  final VoidCallback onRequestPermissions;
  final VoidCallback? onDismiss;

  const HealthPermissionBanner({
    super.key,
    required this.onRequestPermissions,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withOpacity(0.55),
        borderRadius: BorderRadius.circular(AppLayout.radius),
        border: Border.all(color: scheme.outline.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.health_and_safety_outlined, color: scheme.primary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Connect health data',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                Text(
                  'Steps, burned calories, workout time',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurface.withOpacity(0.65),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onRequestPermissions,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Grant'),
          ),
          if (onDismiss != null)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              visualDensity: VisualDensity.compact,
              onPressed: onDismiss,
              tooltip: 'Dismiss',
            ),
        ],
      ),
    );
  }
}
