import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/log_entry.dart';
import '../services/log_service.dart';
import '../services/settings_service.dart';
import '../services/nutrition_analysis_service.dart';
import '../services/health_service.dart';
import '../theme/app_theme.dart';
import '../utils/num_format.dart';
import '../widgets/ui_kit.dart';
import 'daily_log_screen.dart';

/// One day's rolled-up nutrition, used across the weekly report.
class _DayStat {
  _DayStat({
    required this.date,
    required this.weekday,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.entryCount,
    required this.foods,
  });

  final DateTime date;
  final int weekday; // 1 = Mon … 7 = Sun
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final int entryCount;
  final List<String> foods;

  bool get hasData => entryCount > 0;
  bool get isWeekend => weekday >= 6;
}

class WeeklyAnalysisScreen extends StatefulWidget {
  final String weekStartDate;

  const WeeklyAnalysisScreen({super.key, required this.weekStartDate});

  @override
  State<WeeklyAnalysisScreen> createState() => _WeeklyAnalysisScreenState();
}

class _WeeklyAnalysisScreenState extends State<WeeklyAnalysisScreen> {
  final LogService _logService = LogService();

  late DateTime _weekStart; // first day of the shown 7-day window

  bool _loading = true;
  List<_DayStat> _week = [];
  List<_DayStat> _prevWeek = [];

  double? _calorieTarget;
  double? _proteinTarget;
  double? _weight;

  // Body weight (from Health Connect), loaded after the main content.
  bool _weightLoaded = false;
  List<WeightPoint> _weightSeries = [];
  double? _currentWeight;
  double? _weightDelta;

  // AI layer (optional, grounded on the numbers below).
  bool _hasApiKey = false;
  Map<String, dynamic>? _aiData;
  bool _aiLoading = false;
  bool _aiCollapsed = true;

  @override
  void initState() {
    super.initState();
    _weekStart = _dateOnly(DateTime.parse(widget.weekStartDate));
    _load();
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  String _fmtDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  Future<List<_DayStat>> _collect(DateTime start) async {
    final List<_DayStat> days = [];
    for (int i = 0; i < 7; i++) {
      final date = start.add(Duration(days: i));
      final entries = await _logService.getLogEntriesByDate(_fmtDate(date));
      double cal = 0, prot = 0, carb = 0, fat = 0;
      final foods = <String>[];
      for (final LogEntry e in entries) {
        final f = e.amount / 100;
        cal += (e.calories ?? 0) * f;
        prot += (e.protein ?? 0) * f;
        carb += (e.carbs ?? 0) * f;
        fat += (e.fat ?? 0) * f;
        if (e.foodName != null) foods.add(e.foodName!);
      }
      days.add(
        _DayStat(
          date: date,
          weekday: date.weekday,
          calories: cal,
          protein: prot,
          carbs: carb,
          fat: fat,
          entryCount: entries.length,
          foods: foods,
        ),
      );
    }
    return days;
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    _calorieTarget = await SettingsService.getCalorieTarget();
    final macros = await SettingsService.getMacroTargets();
    _proteinTarget = macros?['protein'];
    _weight = await SettingsService.getWeight();
    _hasApiKey = await SettingsService.hasGeminiApiKey();

    final week = await _collect(_weekStart);
    final prev = await _collect(_weekStart.subtract(const Duration(days: 7)));
    final existingAi = await SettingsService.getWeeklyAnalysis(_weekKey());

    if (!mounted) return;
    setState(() {
      _week = week;
      _prevWeek = prev;
      _aiData = existingAi;
      _aiCollapsed = true;
      _loading = false;
    });

    // Weight is fetched separately so it never blocks the main report.
    _loadWeight();
  }

  Future<void> _loadWeight() async {
    setState(() => _weightLoaded = false);
    // Only touch Health Connect if the user already granted activity access,
    // to avoid prompting people who don't use it.
    if (!await HealthService.instance.hasPermissions()) {
      if (mounted) setState(() => _weightLoaded = true);
      return;
    }
    final end = _weekStart.add(const Duration(days: 7));
    final start = _weekStart.subtract(const Duration(days: 60));
    final series = await HealthService.instance.getWeightSeries(start, end);

    double? current;
    double? delta;
    if (series.isNotEmpty) {
      current = series.last.kg;
      await SettingsService.setWeight(current); // keep profile in sync
      WeightPoint? before;
      for (final p in series) {
        if (p.date.isBefore(_weekStart)) before = p;
      }
      if (before != null) delta = current - before.kg;
    }

    if (!mounted) return;
    setState(() {
      _weightSeries = series;
      _currentWeight = current;
      _weightDelta = delta;
      _weightLoaded = true;
    });
  }

  String _weekKey() =>
      '${_weekStart.year}-W${((_weekStart.difference(DateTime(_weekStart.year, 1, 1)).inDays) / 7).ceil()}';

  // ---- Derived metrics -----------------------------------------------------

  List<_DayStat> get _logged => _week.where((d) => d.hasData).toList();
  int get _loggedCount => _logged.length;

  bool get _isCurrentWeek {
    final end = _weekStart.add(const Duration(days: 6));
    return !end.isBefore(_dateOnly(DateTime.now()));
  }

  double _avg(double Function(_DayStat) sel) {
    if (_logged.isEmpty) return 0;
    return _logged.map(sel).reduce((a, b) => a + b) / _logged.length;
  }

  int get _streak {
    // Longest run of consecutive logged days in the window. Using the longest
    // run (rather than only the trailing run) avoids showing "0-day streak"
    // for a current week whose latest day simply isn't logged yet.
    int best = 0, run = 0;
    for (final d in _week) {
      if (d.hasData) {
        run++;
        if (run > best) best = run;
      } else {
        run = 0;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PageAppBar(title: 'Weekly report'),
      body: SafeArea(
        top: false,
        child: _loading
            ? _buildSkeleton()
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.pagePadding,
                    AppTheme.space8,
                    AppTheme.pagePadding,
                    AppTheme.space32,
                  ),
                  children: _buildContent(),
                ),
              ),
      ),
    );
  }

  List<Widget> _buildContent() {
    if (_loggedCount == 0) {
      return [
        _weekNavigator(),
        const SizedBox(height: AppTheme.space24),
        const SectionCard(
          child: EmptyStateView(
            icon: Icons.calendar_month_outlined,
            title: 'Nothing logged this week',
            message: 'Log meals across the week to see your report.',
          ),
        ),
      ];
    }

    // Assemble only the cards that apply, spacing them uniformly so a
    // collapsed (null) card never leaves a phantom gap.
    final cards = <Widget?>[
      _chartCard(),
      _averagesCard(),
      _weightCard(),
      _goalsCard(),
      _macroSplitCard(),
      _patternCard(),
      _foodsCard(),
    ].whereType<Widget>().toList();

    return [
      _weekNavigator(),
      const SizedBox(height: AppTheme.space12),
      if (_loggedCount < 7) _dataQualityBanner(),
      for (int i = 0; i < cards.length; i++) ...[
        if (i > 0) const SizedBox(height: AppTheme.space12),
        cards[i],
      ],
      if (_hasApiKey) ...[
        const SizedBox(height: AppTheme.space20),
        const SectionHeader(title: 'AI coach'),
        _aiCard(),
      ],
    ];
  }

  // ---- Week navigator ------------------------------------------------------

  Widget _weekNavigator() {
    final theme = Theme.of(context);
    final end = _weekStart.add(const Duration(days: 6));
    final label =
        '${DateFormat.MMMd().format(_weekStart)} – ${DateFormat.MMMd().format(end)}';
    return Row(
      children: [
        IconButton(
          onPressed: () {
            setState(
              () => _weekStart =
                  _weekStart.subtract(const Duration(days: 7)),
            );
            _load();
          },
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                _isCurrentWeek ? 'This week' : 'Week of',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                label,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: _isCurrentWeek
              ? null
              : () {
                  setState(
                    () => _weekStart =
                        _weekStart.add(const Duration(days: 7)),
                  );
                  _load();
                },
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }

  Widget _dataQualityBanner() {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space12),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.space12),
        decoration: BoxDecoration(
          color: scheme.tertiaryContainer.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, size: 18, color: scheme.tertiary),
            const SizedBox(width: AppTheme.space8),
            Expanded(
              child: Text(
                'You logged $_loggedCount of 7 days. Averages and rates use '
                'only the days with entries.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Chart ---------------------------------------------------------------

  Widget _chartCard() {
    final scheme = Theme.of(context).colorScheme;
    final target = _calorieTarget ?? 0;
    final maxCal = [
      ..._week.map((d) => d.calories),
      if (target > 0) target,
      1.0,
    ].reduce(math.max);

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
                label: '$_loggedCount/7 logged',
                color: scheme.primary,
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space16),
          SizedBox(
            height: 150,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children:
                        _week.map((d) => _bar(d, maxCal, target)).toList(),
                  ),
                ),
                // Target reference line, aligned to the bar baseline.
                if (target > 0)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: _kBarBaseline +
                        (_kChartHeight * (target / maxCal).clamp(0.0, 1.0)),
                    child: Container(
                      height: 1.5,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.space12),
          Wrap(
            spacing: AppTheme.space12,
            runSpacing: 6,
            children: [
              if (target > 0)
                _chartLegend(
                  'Target ${fmtNum(target)} kcal',
                  scheme.onSurfaceVariant,
                  isLine: true,
                ),
              _chartLegend('On track', scheme.primary),
              _chartLegend('Over target', scheme.error),
              _chartLegend('Not logged', scheme.surfaceContainerHighest),
            ],
          ),
        ],
      ),
    );
  }

  static const double _kChartHeight = 104.0;
  static const double _kBarBaseline = 22.0; // gap + weekday-label height

  Widget _chartLegend(String label, Color color, {bool isLine = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: isLine ? 14 : 10,
          height: isLine ? 2 : 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(isLine ? 0 : 3),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _bar(_DayStat day, double maxCal, double target) {
    final scheme = Theme.of(context).colorScheme;
    final ratio = (day.calories / maxCal).clamp(0.0, 1.0);
    final overTarget = target > 0 && day.calories > target;
    final Color barColor = !day.hasData
        ? scheme.surfaceContainerHighest
        : overTarget
            ? scheme.error
            : scheme.primary;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openDay(day.date),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                day.hasData ? fmtNum(day.calories) : '–',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 16,
              height: day.hasData
                  ? (_kChartHeight * ratio).clamp(4.0, _kChartHeight)
                  : 4,
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              DateFormat('E').format(day.date).substring(0, 1),
              style: TextStyle(
                fontSize: 11,
                fontWeight: day.isWeekend ? FontWeight.w700 : FontWeight.w400,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Averages ------------------------------------------------------------

  Widget _averagesCard() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final avgCal = _avg((d) => d.calories);
    final avgP = _avg((d) => d.protein);
    final avgC = _avg((d) => d.carbs);
    final avgF = _avg((d) => d.fat);

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Daily average', style: theme.textTheme.titleMedium),
              Text(
                'based on $_loggedCount day${_loggedCount == 1 ? '' : 's'}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                fmtNum(avgCal),
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 4),
              Text('kcal', style: theme.textTheme.titleMedium),
              const Spacer(),
              if (_calorieTarget != null)
                Flexible(
                  child: Text(
                    'target ${fmtNum(_calorieTarget!)}',
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppTheme.space12),
          Row(
            children: [
              Expanded(child: _macroChip('Protein', avgP, scheme.primary)),
              const SizedBox(width: AppTheme.space8),
              Expanded(child: _macroChip('Carbs', avgC, scheme.tertiary)),
              const SizedBox(width: AppTheme.space8),
              Expanded(child: _macroChip('Fat', avgF, scheme.secondary)),
            ],
          ),
        ],
      ),
    );
  }

  // ---- Weight trend (Health Connect) ---------------------------------------

  /// The trailing window of weight readings shown in the sparkline/labels.
  List<WeightPoint> get _weightWindow => _weightSeries.length > 16
      ? _weightSeries.sublist(_weightSeries.length - 16)
      : _weightSeries;

  Widget? _weightCard() {
    if (!_weightLoaded || _currentWeight == null) return null;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final delta = _weightDelta;
    final down = delta != null && delta < 0;
    final flat = delta == null || delta.abs() < 0.05;
    final latest = _weightSeries.isNotEmpty ? _weightSeries.last : null;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Weight', style: theme.textTheme.titleMedium),
              Text(
                'from Health Connect',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                fmtNum(_currentWeight!),
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 4),
              Text('kg', style: theme.textTheme.titleMedium),
              const Spacer(),
              if (!flat)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: (down ? scheme.primary : scheme.tertiary)
                        .withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        down
                            ? Icons.south_rounded
                            : Icons.north_rounded,
                        size: 14,
                        color: down ? scheme.primary : scheme.tertiary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${fmtNum(delta.abs())} kg this week',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: down ? scheme.primary : scheme.tertiary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Text(
                  'steady',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          if (latest != null) ...[
            const SizedBox(height: 4),
            Text(
              'Last measured ${DateFormat('MMM d').format(latest.date)}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          if (_weightSeries.length >= 2) ...[
            const SizedBox(height: AppTheme.space16),
            SizedBox(height: 44, child: _weightSparkline()),
            const SizedBox(height: 8),
            Builder(
              builder: (context) {
                final pts = _weightWindow;
                final first = pts.first;
                final last = pts.last;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _weightEndpoint(first.date, first.kg, TextAlign.start),
                    _weightEndpoint(last.date, last.kg, TextAlign.end),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _weightEndpoint(DateTime date, double kg, TextAlign align) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: align == TextAlign.start
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      children: [
        Text(
          '${fmtNum(kg)} kg',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          DateFormat('MMM d').format(date),
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _weightSparkline() {
    final scheme = Theme.of(context).colorScheme;
    final pts = _weightWindow;
    final values = pts.map((p) => p.kg).toList();
    final minV = values.reduce(math.min);
    final maxV = values.reduce(math.max);
    final range = (maxV - minV).abs() < 0.1 ? 1.0 : (maxV - minV);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: pts.map((p) {
        final ratio = ((p.kg - minV) / range).clamp(0.0, 1.0);
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: Container(
              height: (6 + 34 * ratio),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ---- Goals: adherence + protein + trend ----------------------------------

  Widget _goalsCard() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final children = <Widget>[];

    // Calorie adherence (within ±10% of target).
    if (_calorieTarget != null && _calorieTarget! > 0) {
      final t = _calorieTarget!;
      int within = 0, over = 0, under = 0;
      for (final d in _logged) {
        if (d.calories > t * 1.1) {
          over++;
        } else if (d.calories < t * 0.9) {
          under++;
        } else {
          within++;
        }
      }
      children.add(
        _goalRow(
          icon: Icons.adjust_rounded,
          title: 'Calorie target',
          value: '$within / $_loggedCount days on target',
          detail: over + under == 0
              ? 'Great consistency'
              : '$over over · $under under',
          color: scheme.primary,
        ),
      );
    }

    // Protein hit rate + g/kg.
    if (_proteinTarget != null && _proteinTarget! > 0) {
      final hits = _logged.where((d) => d.protein >= _proteinTarget!).length;
      final avgP = _avg((d) => d.protein);
      final perKg =
          (_weight != null && _weight! > 0) ? avgP / _weight! : null;
      children.add(
        _goalRow(
          icon: Icons.egg_alt_rounded,
          title: 'Protein goal',
          value: '$hits / $_loggedCount days hit ${fmtNum(_proteinTarget!)} g',
          detail: perKg != null
              ? 'Avg ${fmtNum(avgP)} g · ${fmtNum(perKg)} g/kg'
              : 'Avg ${fmtNum(avgP)} g',
          color: scheme.secondary,
        ),
      );
    }

    // Trend vs previous week (guarded).
    final prevLogged = _prevWeek.where((d) => d.hasData).toList();
    if (_loggedCount >= 4 && prevLogged.length >= 4) {
      final curAvg = _avg((d) => d.calories);
      final prevAvg =
          prevLogged.map((d) => d.calories).reduce((a, b) => a + b) /
              prevLogged.length;
      final diff = curAvg - prevAvg;
      final pct = prevAvg > 0 ? (diff / prevAvg * 100) : 0;
      final up = diff >= 0;
      children.add(
        _goalRow(
          icon: up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
          title: 'Vs last week',
          value: '${up ? '+' : ''}${fmtNum(diff)} kcal/day',
          detail: '${up ? '+' : ''}${fmtNum(pct)}% average intake',
          color: scheme.tertiary,
        ),
      );
    }

    if (children.isEmpty) {
      return SectionCard(
        child: Row(
          children: [
            Icon(Icons.flag_outlined, color: scheme.onSurfaceVariant),
            const SizedBox(width: AppTheme.space12),
            Expanded(
              child: Text(
                'Set calorie and macro targets in Settings to track adherence.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SectionCard(
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppTheme.space12),
                child: Divider(height: 1),
              ),
            children[i],
          ],
        ],
      ),
    );
  }

  Widget _goalRow({
    required IconData icon,
    required String title,
    required String value,
    required String detail,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(AppTheme.space8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: AppTheme.space12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              )),
              Text(
                value,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                detail,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---- Macro split ---------------------------------------------------------

  Widget? _macroSplitCard() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final pKcal = _logged.fold<double>(0, (s, d) => s + d.protein * 4);
    final cKcal = _logged.fold<double>(0, (s, d) => s + d.carbs * 4);
    final fKcal = _logged.fold<double>(0, (s, d) => s + d.fat * 9);
    final total = pKcal + cKcal + fKcal;
    if (total <= 0) return null;

    final pPct = pKcal / total * 100;
    final cPct = cKcal / total * 100;
    final fPct = fKcal / total * 100;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Where your calories came from',
              style: theme.textTheme.titleMedium),
          const SizedBox(height: AppTheme.space12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Row(
              children: [
                Expanded(
                  flex: math.max(1, pPct.round()),
                  child: Container(height: 14, color: scheme.primary),
                ),
                Expanded(
                  flex: math.max(1, cPct.round()),
                  child: Container(height: 14, color: scheme.tertiary),
                ),
                Expanded(
                  flex: math.max(1, fPct.round()),
                  child: Container(height: 14, color: scheme.secondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.space12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _legend('Protein', '${fmtNum(pPct)}%', scheme.primary),
              _legend('Carbs', '${fmtNum(cPct)}%', scheme.tertiary),
              _legend('Fat', '${fmtNum(fPct)}%', scheme.secondary),
            ],
          ),
        ],
      ),
    );
  }

  // ---- Weekday vs weekend --------------------------------------------------

  Widget? _patternCard() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final weekdays = _logged.where((d) => !d.isWeekend).toList();
    final weekends = _logged.where((d) => d.isWeekend).toList();
    if (weekdays.isEmpty || weekends.isEmpty) return null;

    double avg(List<_DayStat> l) =>
        l.map((d) => d.calories).reduce((a, b) => a + b) / l.length;
    final wd = avg(weekdays);
    final we = avg(weekends);
    final diff = we - wd;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Weekday vs weekend', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppTheme.space12),
          Row(
            children: [
              Expanded(child: _miniStat('Weekdays', '${fmtNum(wd)} kcal')),
              const SizedBox(width: AppTheme.space8),
              Expanded(child: _miniStat('Weekends', '${fmtNum(we)} kcal')),
            ],
          ),
          const SizedBox(height: AppTheme.space8),
          Text(
            diff.abs() < 1
                ? 'Your intake is steady across the week.'
                : 'You eat ${fmtNum(diff.abs())} kcal ${diff > 0 ? 'more' : 'less'} '
                    'per day on weekends.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // ---- Foods ---------------------------------------------------------------

  Widget? _foodsCard() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final counts = <String, int>{};
    for (final d in _week) {
      for (final f in d.foods) {
        counts[f] = (counts[f] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return null;
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(3).toList();

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Most-logged foods', style: theme.textTheme.titleMedium),
              Text(
                '${counts.length} distinct',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space12),
          for (int i = 0; i < top.length; i++) ...[
            if (i > 0) const SizedBox(height: AppTheme.space8),
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: scheme.primaryContainer,
                  child: Text(
                    '${i + 1}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.space12),
                Expanded(
                  child: Text(
                    top[i].key,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                Text(
                  '${top[i].value}×',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ---- AI layer ------------------------------------------------------------

  Widget _aiCard() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasAi = _aiData != null;

    return Container(
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.18)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: hasAi
                ? () => setState(() => _aiCollapsed = !_aiCollapsed)
                : null,
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.space12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppTheme.space8),
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Icon(Icons.auto_awesome,
                        color: scheme.onPrimary, size: 18),
                  ),
                  const SizedBox(width: AppTheme.space12),
                  Expanded(
                    child: Text(
                      'AI weekly review',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (hasAi)
                    AnimatedRotation(
                      turns: _aiCollapsed ? 0.5 : 0,
                      duration: const Duration(milliseconds: 220),
                      child: Icon(Icons.keyboard_arrow_up_rounded,
                          color: scheme.onSurfaceVariant),
                    ),
                ],
              ),
            ),
          ),
          if (!hasAi)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.space12,
                0,
                AppTheme.space12,
                AppTheme.space12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Get a short written review and recommendations based on '
                    'the numbers above.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppTheme.space12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _aiLoading ? null : _generateAi,
                      icon: _aiLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome, size: 18),
                      label: Text(_aiLoading ? 'Analyzing…' : 'Generate review'),
                    ),
                  ),
                ],
              ),
            )
          else
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity),
              secondChild: _aiBody(),
              crossFadeState: _aiCollapsed
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              duration: const Duration(milliseconds: 220),
            ),
        ],
      ),
    );
  }

  Widget _aiBody() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final pattern = _aiData!['pattern'] as String?;
    final swaps = (_aiData!['swaps'] as List?) ?? const [];
    final insights =
        (_aiData!['insights'] as List?)?.cast<String>() ?? const [];
    final recs =
        (_aiData!['recommendations'] as List?)?.cast<String>() ?? const [];
    final quote =
        (_aiData!['quote'] ?? _aiData!['weeklyQuote']) as String?;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.space12,
        0,
        AppTheme.space12,
        AppTheme.space12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (pattern != null && pattern.trim().isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppTheme.space12),
              decoration: BoxDecoration(
                color: scheme.tertiaryContainer.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.insights_rounded,
                      size: 18, color: scheme.tertiary),
                  const SizedBox(width: AppTheme.space8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Pattern of the week',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            )),
                        const SizedBox(height: 2),
                        Text(
                          pattern,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.space12),
          ],
          if (swaps.isNotEmpty) ...[
            Text('Try these swaps', style: theme.textTheme.titleSmall),
            const SizedBox(height: AppTheme.space8),
            ...swaps.whereType<Map>().map(_swapTile),
            const SizedBox(height: AppTheme.space12),
          ],
          if (quote != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppTheme.space12),
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Text(
                quote,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(height: AppTheme.space12),
          ],
          if (insights.isNotEmpty) ...[
            Text('Insights', style: theme.textTheme.titleSmall),
            const SizedBox(height: AppTheme.space8),
            ...insights.map((s) => _bullet(s)),
            const SizedBox(height: AppTheme.space12),
          ],
          if (recs.isNotEmpty) ...[
            Text('Recommendations', style: theme.textTheme.titleSmall),
            const SizedBox(height: AppTheme.space8),
            ...recs.asMap().entries.map((e) => _numbered(e.key + 1, e.value)),
            const SizedBox(height: AppTheme.space12),
          ],
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _aiLoading ? null : _generateAi,
              icon: _aiLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded, size: 18),
              label: Text(_aiLoading ? 'Analyzing…' : 'Regenerate'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generateAi() async {
    setState(() => _aiLoading = true);
    try {
      final result = await NutritionAnalysisService.generateWeeklySummary(
        _fmtDate(_weekStart),
      );
      if (result != null && mounted) {
        setState(() {
          _aiData = result;
          _aiCollapsed = false;
          _aiLoading = false;
        });
      } else if (mounted) {
        setState(() => _aiLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _aiLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not generate review: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  // ---- Small helpers -------------------------------------------------------

  void _openDay(DateTime date) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DailyLogScreen(date: _fmtDate(date)),
      ),
    ).then((_) => _load());
  }

  Widget _macroChip(String label, double value, Color color) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
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
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${fmtNum(value)} g',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppTheme.space12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          )),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _legend(String label, String value, Color color) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$label $value',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _swapTile(Map swap) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final title = (swap['title'] ?? '').toString();
    final detail = (swap['detail'] ?? '').toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space8),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.space12),
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.swap_horiz_rounded, size: 18, color: scheme.primary),
            const SizedBox(width: AppTheme.space8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  if (detail.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bullet(String text) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 7),
            decoration:
                BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppTheme.space8),
          Expanded(
            child: Text(text, style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.35,
            )),
          ),
        ],
      ),
    );
  }

  Widget _numbered(int n, String text) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration:
                BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
            child: Center(
              child: Text(
                '$n',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppTheme.space8),
          Expanded(
            child: Text(text, style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.35,
            )),
          ),
        ],
      ),
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

  Widget _buildSkeleton() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.pagePadding,
        AppTheme.space16,
        AppTheme.pagePadding,
        AppTheme.space32,
      ),
      children: const [
        Skeleton(width: 180, height: 20),
        SizedBox(height: AppTheme.space16),
        Skeleton(width: double.infinity, height: 190, radius: AppTheme.radiusMd),
        SizedBox(height: AppTheme.space12),
        Skeleton(width: double.infinity, height: 120, radius: AppTheme.radiusMd),
        SizedBox(height: AppTheme.space12),
        Skeleton(width: double.infinity, height: 120, radius: AppTheme.radiusMd),
      ],
    );
  }
}
