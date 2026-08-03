import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../models/health_data.dart';
import '../theme/app_theme.dart';
import '../utils/num_format.dart';

class EnhancedNutritionSummaryCard extends StatefulWidget {
  final Map<String, double> nutritionData;
  final HealthData? healthData;
  final VoidCallback? onSetTargetsTap;
  final VoidCallback? onHealthPermissionTap;

  /// Stable header title (e.g. "Today's progress" or a date). Kept explicit so
  /// it does not change as async health data loads in.
  final String title;

  const EnhancedNutritionSummaryCard({
    super.key,
    required this.nutritionData,
    this.healthData,
    this.onSetTargetsTap,
    this.onHealthPermissionTap,
    this.title = "Today's progress",
  });

  @override
  State<EnhancedNutritionSummaryCard> createState() =>
      _EnhancedNutritionSummaryCardState();
}

class _EnhancedNutritionSummaryCardState
    extends State<EnhancedNutritionSummaryCard> {
  double _dailyCalorieTarget = 0;
  double _dailyProteinTarget = 0;
  double _dailyFatTarget = 0;
  double _dailyCarbTarget = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTargets();
  }

  @override
  void didUpdateWidget(EnhancedNutritionSummaryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nutritionData != widget.nutritionData) {
      _loadTargets();
    }
  }

  Future<void> _loadTargets() async {
    final calorieTarget = await SettingsService.getCalorieTarget();
    final macroTargets = await SettingsService.getMacroTargets();

    if (mounted) {
      setState(() {
        _dailyCalorieTarget = calorieTarget ?? 0;
        if (macroTargets != null) {
          _dailyProteinTarget = macroTargets['protein'] ?? 0;
          _dailyFatTarget = macroTargets['fat'] ?? 0;
          _dailyCarbTarget = macroTargets['carbs'] ?? 0;
        }
        _isLoading = false;
      });
    }
  }

  Widget _shell({required Widget child}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppTheme.space16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      padding: const EdgeInsets.all(AppTheme.space16),
      // Smoothly grow/shrink when async health data arrives so the card does
      // not visibly "jiggle" once Health Connect finishes syncing.
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (_isLoading) {
      return _shell(
        child: const SizedBox(
          height: 120,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final hasTargets = _dailyCalorieTarget > 0 &&
        _dailyProteinTarget > 0 &&
        _dailyFatTarget > 0 &&
        _dailyCarbTarget > 0;

    final caloriesIntake = widget.nutritionData['cal'] ?? 0;
    final caloriesBurned = widget.healthData?.totalCaloriesBurned ?? 0;
    final netCalories = caloriesIntake - caloriesBurned;
    final hasHealthData = widget.healthData != null && caloriesBurned > 0;

    return _shell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.space8),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(
                  Icons.analytics_outlined,
                  color: scheme.onPrimaryContainer,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppTheme.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: theme.textTheme.titleMedium,
                    ),
                    if (hasHealthData &&
                        (widget.healthData!.totalSteps > 0 ||
                            widget.healthData!.totalWorkoutTime > 0)) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${widget.healthData!.totalSteps} steps  •  '
                        '${widget.healthData!.totalWorkoutTime.round()} min active',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!hasTargets)
                TextButton(
                  onPressed: widget.onSetTargetsTap,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.space12,
                      vertical: 6,
                    ),
                    backgroundColor: scheme.primaryContainer,
                    foregroundColor: scheme.onPrimaryContainer,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    ),
                  ),
                  child: const Text('Set targets'),
                ),
            ],
          ),
          if (widget.onHealthPermissionTap != null) ...[
            const SizedBox(height: AppTheme.space16),
            Material(
              color: scheme.secondaryContainer,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: widget.onHealthPermissionTap,
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.space12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.health_and_safety_rounded,
                        color: scheme.onSecondaryContainer,
                        size: 20,
                      ),
                      const SizedBox(width: AppTheme.space8),
                      Expanded(
                        child: Text(
                          'Connect health data for smart tracking',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSecondaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: scheme.onSecondaryContainer,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: AppTheme.space16),
          if (hasTargets) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Calories',
                  style: theme.textTheme.titleMedium,
                ),
                Text(
                  '${fmtNum(caloriesIntake)} / ${fmtNum(_dailyCalorieTarget)} kcal',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.space8),
            _buildCalorieBar(
              context,
              caloriesIntake,
              caloriesBurned,
              netCalories,
              _dailyCalorieTarget,
              hasHealthData,
            ),
            const SizedBox(height: AppTheme.space20),
            _buildMacroRow(context),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(AppTheme.space16),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.track_changes_outlined,
                    size: 28,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: AppTheme.space8),
                  Text(
                    'Set your daily targets to track progress',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCalorieBar(
    BuildContext context,
    double intake,
    double burned,
    double net,
    double target,
    bool hasHealthData,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final intakeProgress = target > 0 ? (intake / target).clamp(0.0, 1.0) : 0.0;
    final netProgress =
        target > 0 ? (net / target).clamp(0.0, 1.0) : 0.0;
    final intakeOver = intake > target;
    final netOver = net > target;
    // Percentage tracks the headline value (total intake).
    final percentage = target > 0 ? (intakeProgress * 100).round() : 0;

    final intakeColor = intakeOver ? scheme.error : scheme.primary;
    final netColor = netOver ? scheme.error : scheme.primary;

    // LayoutBuilder + explicit widths — FractionallySizedBox/Align inside a
    // Stack was painting 0-width fills on some devices (invisible bar).
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final intakeW = w * intakeProgress;
            final netW = w * netProgress;
            return ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              child: SizedBox(
                height: 12,
                width: w,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ColoredBox(
                        // Slightly stronger track so the empty bar isn't
                        // invisible against surfaceContainerLow cards.
                        color: scheme.outlineVariant.withValues(alpha: 0.55),
                      ),
                    ),
                    // Total intake (solid alone; lighter backdrop when net overlays).
                    if (intakeW > 0)
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: intakeW.clamp(2.0, w),
                        child: ColoredBox(
                          color: hasHealthData
                              ? intakeColor.withValues(alpha: 0.45)
                              : intakeColor,
                        ),
                      ),
                    if (hasHealthData && netW > 0)
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: netW.clamp(2.0, w),
                        child: ColoredBox(color: netColor),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: AppTheme.space8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$percentage% of target',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (hasHealthData)
              Flexible(
                child: Text(
                  'Net ${fmtNum(net)}  •  Burned ${fmtNum(burned)} kcal',
                  textAlign: TextAlign.end,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              Text(
                '${fmtNum(intake)} kcal',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        if (hasHealthData) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              _legendSwatch(netColor),
              const SizedBox(width: 4),
              Text('Net',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  )),
              const SizedBox(width: AppTheme.space12),
              _legendSwatch(intakeColor.withValues(alpha: 0.4)),
              const SizedBox(width: 4),
              Text('Total intake',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  )),
            ],
          ),
        ],
      ],
    );
  }

  Widget _legendSwatch(Color color) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  Widget _buildMacroRow(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _macroTile(
            context,
            'Protein',
            widget.nutritionData['prot'] ?? 0,
            _dailyProteinTarget,
            scheme.primary,
          ),
        ),
        const SizedBox(width: AppTheme.space8),
        Expanded(
          child: _macroTile(
            context,
            'Carbs',
            widget.nutritionData['carb'] ?? 0,
            _dailyCarbTarget,
            scheme.tertiary,
          ),
        ),
        const SizedBox(width: AppTheme.space8),
        Expanded(
          child: _macroTile(
            context,
            'Fat',
            widget.nutritionData['fat'] ?? 0,
            _dailyFatTarget,
            scheme.secondary,
          ),
        ),
      ],
    );
  }

  Widget _macroTile(
    BuildContext context,
    String label,
    double current,
    double target,
    Color color,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(AppTheme.space12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            fmtNum(current),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            '/ ${fmtNum(target)} g',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppTheme.space4),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: scheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}
