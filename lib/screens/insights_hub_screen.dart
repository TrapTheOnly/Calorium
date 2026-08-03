import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/log_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_layout.dart';
import '../widgets/custom_alert.dart';
import '../widgets/ui_kit.dart';
import 'ai_meal_planner_screen.dart';
import 'daily_log_screen.dart';
import 'weekly_analysis_screen.dart';

class _DayStat {
  _DayStat({
    required this.date,
    required this.label,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.hasData,
  });

  final String date;
  final String label;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final bool hasData;
}

class InsightsHubScreen extends StatefulWidget {
  const InsightsHubScreen({super.key});

  @override
  State<InsightsHubScreen> createState() => _InsightsHubScreenState();
}

class _InsightsHubScreenState extends State<InsightsHubScreen> {
  bool _loading = true;
  int _daysWithData = 0;
  int _streak = 0;
  double _avgCalories = 0;
  double _avgProtein = 0;
  double? _calorieTarget;
  Map<String, double>? _macroTargets;
  _DayStat? _bestDay;
  List<_DayStat> _week = [];

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final logService = LogService();
    final target = await SettingsService.getCalorieTarget();
    final macros = await SettingsService.getMacroTargets();
    final List<_DayStat> week = [];

    // Build oldest -> newest for a natural left-to-right timeline.
    // Sum entries the same way Home/Daily Log do (calories * amount / 100) so
    // the numbers stay consistent across the app.
    for (int i = 6; i >= 0; i--) {
      final date = DateTime.now().subtract(Duration(days: i));
      final dateString = DateFormat('yyyy-MM-dd').format(date);
      final entries = await logService.getLogEntriesByDate(dateString);
      double calories = 0, protein = 0, carbs = 0, fat = 0;
      for (final e in entries) {
        final f = e.amount / 100;
        calories += (e.calories ?? 0) * f;
        protein += (e.protein ?? 0) * f;
        carbs += (e.carbs ?? 0) * f;
        fat += (e.fat ?? 0) * f;
      }
      week.add(
        _DayStat(
          date: dateString,
          label: DateFormat('E').format(date).substring(0, 1),
          calories: calories,
          protein: protein,
          carbs: carbs,
          fat: fat,
          hasData: entries.isNotEmpty,
        ),
      );
    }

    final logged = week.where((d) => d.hasData).toList();
    final daysWithData = logged.length;

    // Current streak: consecutive logged days ending today (newest last).
    int streak = 0;
    for (int i = week.length - 1; i >= 0; i--) {
      if (week[i].hasData) {
        streak++;
      } else {
        break;
      }
    }

    final avgCalories = logged.isEmpty
        ? 0.0
        : logged.map((d) => d.calories).reduce((a, b) => a + b) / logged.length;
    final avgProtein = logged.isEmpty
        ? 0.0
        : logged.map((d) => d.protein).reduce((a, b) => a + b) / logged.length;
    _DayStat? best;
    for (final d in logged) {
      if (best == null || d.calories > best.calories) best = d;
    }

    if (!mounted) return;
    setState(() {
      _week = week;
      _daysWithData = daysWithData;
      _streak = streak;
      _avgCalories = avgCalories;
      _avgProtein = avgProtein;
      _calorieTarget = target;
      _macroTargets = macros;
      _bestDay = best;
      _loading = false;
    });
  }

  void _openFillGap(Map<String, double> remaining) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AiMealPlannerScreen(initialTargetMacros: remaining),
      ),
    ).then((_) => _loadProgress());
  }

  /// Builds the "close today's gap" card, or null when there are no targets.
  Widget? _buildFillGap() {
    final today = _week.isNotEmpty ? _week.last : null;
    final proteinTarget = _macroTargets?['protein'];
    if (_calorieTarget == null && proteinTarget == null) return null;

    final consumedCal = today?.calories ?? 0;
    final consumedProt = today?.protein ?? 0;
    final consumedCarb = today?.carbs ?? 0;
    final consumedFat = today?.fat ?? 0;

    final remainingCal = (_calorieTarget ?? 0) - consumedCal;
    final remainingProt = (proteinTarget ?? 0) - consumedProt;
    final remainingCarb = (_macroTargets?['carbs'] ?? 0) - consumedCarb;
    final remainingFat = (_macroTargets?['fat'] ?? 0) - consumedFat;

    final hour = DateTime.now().hour;
    final short = proteinTarget != null && consumedProt < 0.7 * proteinTarget;
    final prominent = hour >= 17 && short && remainingCal > 100;

    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    final remaining = <String, double>{
      if (remainingCal > 0) 'calories': remainingCal,
      if (remainingProt > 0) 'protein': remainingProt,
      if (remainingCarb > 0) 'carbs': remainingCarb,
      if (remainingFat > 0) 'fat': remainingFat,
    };

    final subtitle = remainingProt > 0 || remainingCal > 0
        ? 'You have ${remainingCal > 0 ? '${remainingCal.toStringAsFixed(0)} kcal' : 'no calories'}'
            '${remainingProt > 0 ? ' and ${remainingProt.toStringAsFixed(0)}g protein' : ''} left today.'
        : "You've hit today's targets — plan ahead if you like.";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.space16),
      decoration: BoxDecoration(
        color: prominent
            ? scheme.primaryContainer.withValues(alpha: 0.5)
            : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: prominent
            ? Border.all(color: scheme.primary.withValues(alpha: 0.3))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.space8),
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(Icons.restaurant_menu_rounded,
                    color: scheme.onPrimary, size: 18),
              ),
              const SizedBox(width: AppTheme.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Close today\'s gap',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        )),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        )),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _openFillGap(remaining),
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: Text(prominent ? 'Get a meal to hit your macros' : 'Plan a meal with AI'),
            ),
          ),
        ],
      ),
    );
  }

  void _openDay(String date) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => DailyLogScreen(date: date)),
    ).then((_) => _loadProgress());
  }

  void _openWeeklyAnalysis() {
    if (_daysWithData == 0) {
      AlertHelper.showInfoAlert(
        context,
        title: 'Keep logging',
        message:
            'Log at least one day of food to see your weekly report.',
      );
      return;
    }

    final endDate = DateTime.now();
    final startDate = endDate.subtract(const Duration(days: 6));
    final weekStartString = DateFormat('yyyy-MM-dd').format(startDate);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => WeeklyAnalysisScreen(weekStartDate: weekStartString),
      ),
    );
  }

  void _openAiRecipes() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AiMealPlannerScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fillGap = _loading ? null : _buildFillGap();
    return Scaffold(
      appBar: const PageAppBar(
        title: 'Insights',
        subtitle: 'Trends, analysis, and AI tools',
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _loadProgress,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppLayout.pagePadding,
              AppLayout.pagePadding,
              AppLayout.pagePadding,
              AppLayout.pagePadding,
            ),
            children: [
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                if (fillGap != null) ...[
                  const SectionHeader(title: 'Today'),
                  fillGap,
                  const SizedBox(height: AppTheme.space20),
                ],
                if (_daysWithData == 0)
                  const SectionCard(
                    child: EmptyStateView(
                      icon: Icons.insights_outlined,
                      title: 'No trends yet',
                      message:
                          'Log meals for a few days to see your weekly patterns.',
                    ),
                  )
                else ...[
                  const SectionHeader(title: 'This week'),
                  _buildWeekCard(),
                  const SizedBox(height: AppTheme.space12),
                  _buildStatTiles(),
                  const SizedBox(height: AppTheme.space20),
                ],
                const SectionHeader(title: 'Tools'),
                _buildTools(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeekCard() {
    final scheme = Theme.of(context).colorScheme;
    final maxCal = [
      ..._week.map((d) => d.calories),
      if (_calorieTarget != null) _calorieTarget!,
      1.0,
    ].reduce((a, b) => a > b ? a : b);

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _chip(
                icon: Icons.local_fire_department_rounded,
                label: '$_streak-day streak',
                color: scheme.tertiary,
              ),
              const SizedBox(width: AppTheme.space8),
              _chip(
                icon: Icons.event_available_rounded,
                label: '$_daysWithData/7 logged',
                color: scheme.primary,
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space16),
          SizedBox(
            height: 132,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _week.map((d) => _buildBar(d, maxCal)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBar(_DayStat day, double maxCal) {
    final scheme = Theme.of(context).colorScheme;
    final ratio = (day.calories / maxCal).clamp(0.0, 1.0);
    final overTarget =
        _calorieTarget != null && day.calories > _calorieTarget!;
    final barColor = !day.hasData
        ? scheme.surfaceContainerHighest
        : overTarget
            ? scheme.error
            : scheme.primary;
    // The tallest bar fills the available column space; the rest scale
    // proportionally, so a single big day can never overflow the chart.
    final factor = day.hasData ? ratio.clamp(0.05, 1.0) : 0.05;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openDay(day.date),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              day.hasData ? day.calories.toStringAsFixed(0) : '–',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: FractionallySizedBox(
                  heightFactor: factor,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                    width: 14,
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              day.label,
              style: TextStyle(
                fontSize: 11,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatTiles() {
    return Row(
      children: [
        Expanded(
          child: _statTile(
            'Avg calories',
            _avgCalories.toStringAsFixed(0),
            'kcal/day',
          ),
        ),
        const SizedBox(width: AppTheme.space12),
        Expanded(
          child: _statTile(
            'Avg protein',
            _avgProtein.toStringAsFixed(0),
            'g/day',
          ),
        ),
        const SizedBox(width: AppTheme.space12),
        Expanded(
          child: _statTile(
            'Best day',
            _bestDay == null
                ? '–'
                : DateFormat('E').format(DateTime.parse(_bestDay!.date)),
            _bestDay == null
                ? ''
                : '${_bestDay!.calories.toStringAsFixed(0)} kcal',
          ),
        ),
      ],
    );
  }

  Widget _statTile(String label, String value, String unit) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return SectionCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space12,
        vertical: AppTheme.space16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (unit.isNotEmpty)
            Text(
              unit,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTools() {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        NavRow(
          icon: Icons.insights_outlined,
          title: 'Weekly Report',
          subtitle: 'Charts, trends & AI review of your week',
          trailing: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$_daysWithData/7',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
          onTap: _openWeeklyAnalysis,
        ),
        const SizedBox(height: 8),
        NavRow(
          icon: Icons.auto_awesome_outlined,
          title: 'AI Recipe Generator',
          subtitle: 'Photo ingredients → recipe ideas',
          onTap: _openAiRecipes,
        ),
      ],
    );
  }

  Widget _chip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
