import 'package:flutter/material.dart';
import '../models/fasting_settings.dart';

class FastingOverviewCard extends StatelessWidget {
  const FastingOverviewCard({
    super.key,
    required this.status,
    required this.settings,
    required this.streakDays,
    this.onConfigure,
    this.timeRemaining,
  });

  final FastingStatus status;
  final FastingSettings settings;
  final int streakDays;
  final VoidCallback? onConfigure;
  final Duration? timeRemaining;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final width =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 360.0;
        final scale = (width / 360.0).clamp(0.85, 1.15);
        final isCompact = width < 320;

        final rawDuration = timeRemaining ?? _timeUntilWindowEnds(status);
        final duration = rawDuration.isNegative ? Duration.zero : rawDuration;
        final formattedDuration = _formatDuration(duration);
        final progress = _fastProgress(status, settings);
        final isFasting = status.phase == FastingPhase.fasting;
        final phaseLabel = isFasting ? 'Fasting now' : 'Eating now';
        final actionLabel = isFasting ? 'Fast ends in' : 'Eating ends in';
        final streakLabel = streakDays == 1 ? 'day' : 'days';

        final cardBackground = colorScheme.primaryContainer;
        final onCard = colorScheme.onPrimaryContainer;
        final dividerColor = onCard.withOpacity(
          colorScheme.brightness == Brightness.dark ? 0.18 : 0.2,
        );
        final bannerColor = colorScheme.primary.withOpacity(0.16);
        final streakColor = _streakColor(onCard, streakDays);

        final content = Container(
          decoration: BoxDecoration(
            color: cardBackground,
            borderRadius: BorderRadius.circular(20 * scale),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withOpacity(
                  colorScheme.brightness == Brightness.dark ? 0.35 : 0.12,
                ),
                blurRadius: 16 * scale,
                offset: Offset(0, 6 * scale),
              ),
            ],
          ),
          padding: EdgeInsets.symmetric(
            horizontal: 20 * scale,
            vertical: 18 * scale,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Intermittent Fasting',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                  color: onCard,
                ),
              ),
              SizedBox(height: 12 * scale),
              _buildPhaseBanner(
                phaseLabel: phaseLabel,
                isFasting: isFasting,
                background: bannerColor,
                accent: colorScheme.primary,
                textColor: onCard,
                scale: scale,
              ),
              SizedBox(height: 16 * scale),
              _buildMetricsRow(
                scale: scale,
                compact: isCompact,
                primaryLabel: actionLabel,
                primaryValue: formattedDuration,
                primarySubtitle:
                    isFasting
                        ? 'Stay focused until your eating window returns.'
                        : 'Wrap up meals before fasting resumes.',
                secondaryValue: '$streakDays $streakLabel',
                secondarySubtitle: 'Consecutive days staying on schedule.',
                foregroundColor: onCard,
                dividerColor: dividerColor,
                streakColor: streakColor,
              ),
              SizedBox(height: 18 * scale),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: (isCompact ? 4 : 6) * scale,
                  backgroundColor: onCard.withOpacity(0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        );

        if (onConfigure == null) {
          return content;
        }

        return InkWell(
          borderRadius: BorderRadius.circular(20 * scale),
          onTap: onConfigure,
          child: content,
        );
      },
    );
  }

  Widget _buildMetricsRow({
    required double scale,
    required bool compact,
    required String primaryLabel,
    required String primaryValue,
    required String primarySubtitle,
    required String secondaryValue,
    required String secondarySubtitle,
    required Color foregroundColor,
    required Color dividerColor,
    required Color streakColor,
  }) {
    final spacing = 16 * scale;

    final primaryTile = _MetricTile(
      icon: Icons.hourglass_bottom,
      iconColor: foregroundColor.withOpacity(0.85),
      title: primaryLabel,
      value: primaryValue,
      subtitle: primarySubtitle,
      scale: scale,
      titleColor: foregroundColor.withOpacity(0.7),
      valueColor: foregroundColor,
      subtitleColor: foregroundColor.withOpacity(0.65),
    );

    final secondaryTile = _MetricTile(
      icon: Icons.local_fire_department,
      iconColor: streakColor,
      title: 'Streak',
      value: secondaryValue,
      subtitle: secondarySubtitle,
      scale: scale,
      titleColor: streakColor.withOpacity(0.85),
      valueColor: streakColor,
      subtitleColor: streakColor.withOpacity(0.75),
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          primaryTile,
          SizedBox(height: spacing),
          Divider(color: dividerColor),
          SizedBox(height: spacing),
          secondaryTile,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: primaryTile),
        Container(
          width: 1,
          height: 64 * scale,
          margin: EdgeInsets.symmetric(horizontal: spacing),
          color: dividerColor,
        ),
        Expanded(child: secondaryTile),
      ],
    );
  }

  Widget _buildPhaseBanner({
    required String phaseLabel,
    required bool isFasting,
    required Color background,
    required Color accent,
    required Color textColor,
    required double scale,
  }) {
    final icon = isFasting ? Icons.timer_outlined : Icons.restaurant;
    final foreground = isFasting ? accent : accent.withOpacity(0.8);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: 14 * scale,
        vertical: 12 * scale,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16 * scale),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8 * scale),
            decoration: BoxDecoration(
              color: foreground.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18 * scale, color: foreground),
          ),
          SizedBox(width: 12 * scale),
          Expanded(
            child: Text(
              phaseLabel,
              style: TextStyle(
                fontSize: 14 * scale,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Duration _timeUntilWindowEnds(FastingStatus status) {
    final now = DateTime.now();
    final remaining = status.nextChange.difference(now);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  double _fastProgress(FastingStatus status, FastingSettings settings) {
    final totalSeconds = status.phaseDuration.inSeconds;
    if (totalSeconds <= 0) return 0;
    final now = DateTime.now();
    final elapsed = now.difference(status.phaseStart).inSeconds;
    return (elapsed / totalSeconds).clamp(0.0, 1.0);
  }

  Color _streakColor(Color base, int streak) {
    final ratio = (streak.clamp(0, 10)) / 10;
    return Color.lerp(base, Colors.deepOrangeAccent, ratio) ?? base;
  }

  String _formatDuration(Duration duration) {
    final totalMinutes = duration.inMinutes;
    if (totalMinutes <= 0) {
      return '< 1m';
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
    required this.scale,
    required this.titleColor,
    required this.valueColor,
    required this.subtitleColor,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final String subtitle;
  final double scale;
  final Color titleColor;
  final Color valueColor;
  final Color subtitleColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(10 * scale),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 18 * scale),
            ),
            SizedBox(width: 12 * scale),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: titleColor,
                      fontSize:
                          (Theme.of(context).textTheme.bodySmall?.fontSize ??
                              12) *
                          scale,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4 * scale),
                  Text(
                    value,
                    style: TextStyle(
                      color: valueColor,
                      fontSize:
                          (Theme.of(context).textTheme.titleLarge?.fontSize ??
                              22) *
                          scale,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 8 * scale),
        Text(
          subtitle,
          style: TextStyle(
            color: subtitleColor,
            fontSize:
                (Theme.of(context).textTheme.bodySmall?.fontSize ?? 12) * scale,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
