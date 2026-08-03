import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/health_data.dart';
import '../models/log_entry.dart';
import '../services/log_service.dart';
import '../theme/app_theme.dart';
import '../utils/num_format.dart';
import '../utils/health_permission_provider.dart';
import '../widgets/enhanced_nutrition_summary_card.dart';
import '../widgets/ai_suggestions_card.dart';
import '../widgets/add_entry_speed_dial.dart';
import '../widgets/ui_kit.dart';
import 'log_entry_screen.dart';
import 'settings_screen.dart';

class DailyLogScreen extends StatefulWidget {
  final String date;

  const DailyLogScreen({super.key, required this.date});

  @override
  State<DailyLogScreen> createState() => _DailyLogScreenState();
}

class _DailyLogScreenState extends State<DailyLogScreen> {
  List<LogEntry> entries = [];
  bool _loadingEntries = true;
  final LogService _logService = LogService();
  late final String prettyDate;
  HealthData _healthData = HealthData.empty();

  @override
  void initState() {
    super.initState();
    prettyDate = DateFormat.yMMMMd().format(DateTime.parse(widget.date));
    _loadEntries();
    _initializeHealthData();
  }

  Future<void> _loadEntries() async {
    final loadedEntries = await _logService.getLogEntriesByDate(widget.date);
    if (!mounted) return;
    setState(() {
      entries = loadedEntries;
      _loadingEntries = false;
    });
  }

  Future<void> _initializeHealthData() async {
    final healthProvider = Provider.of<HealthPermissionProvider>(context, listen: false);
    
    if (healthProvider.hasPermissions) {
      try {
        final healthData = await healthProvider.getHealthDataForDate(DateTime.parse(widget.date));
        setState(() {
          _healthData = healthData;
        });
      } catch (e) {
        // Handle error silently
      }
    }
  }

  Future<void> _requestHealthPermissions() async {
    final healthProvider = Provider.of<HealthPermissionProvider>(context, listen: false);
    
    try {
      final granted = await healthProvider.requestPermissions();
      
      if (granted) {
        final healthData = await healthProvider.getHealthDataForDate(DateTime.parse(widget.date));
        setState(() {
          _healthData = healthData;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error requesting health permissions: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Map<String, double> get totals {
    double cal = 0, fat = 0, carb = 0, prot = 0;
    
    for (var entry in entries) {
      cal += entry.calories! * entry.amount / 100;
      fat += entry.fat! * entry.amount / 100;
      carb += entry.carbs! * entry.amount / 100;
      prot += entry.protein! * entry.amount / 100;
    }
    
    return {
      'cal': cal,
      'fat': fat,
      'carb': carb,
      'prot': prot,
    };
  }

  void _navigateToSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    );
    // Refresh the screen when returning from settings
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<HealthPermissionProvider>(
      builder: (context, healthProvider, child) {
        return Scaffold(
          appBar: PageAppBar(title: 'Daily Log', subtitle: prettyDate),
          floatingActionButton: AddEntrySpeedDial(
            date: widget.date,
            onComplete: () {
              _loadEntries();
              _initializeHealthData();
            },
          ),
          body: SafeArea(
            top: false,
            child: RefreshIndicator(
              onRefresh: () async {
                await _loadEntries();
                await _initializeHealthData();
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.pagePadding,
                  AppTheme.space8,
                  AppTheme.pagePadding,
                  96,
                ),
                children: [
                  if (_loadingEntries)
                    const _SummaryCardSkeleton()
                  else
                    EnhancedNutritionSummaryCard(
                      title: widget.date ==
                              DateFormat('yyyy-MM-dd').format(DateTime.now())
                          ? "Today's progress"
                          : 'Progress · '
                              '${DateFormat('EEE, MMM d').format(DateTime.parse(widget.date))}',
                      nutritionData: {
                        'cal': totals['cal']!,
                        'prot': totals['prot']!,
                        'fat': totals['fat']!,
                        'carb': totals['carb']!,
                      },
                      healthData:
                          healthProvider.hasPermissions ? _healthData : null,
                      onSetTargetsTap: _navigateToSettings,
                      onHealthPermissionTap:
                          !healthProvider.hasPermissions
                              ? _requestHealthPermissions
                              : null,
                    ),
                  if (!_loadingEntries) AiSuggestionsCard(date: widget.date),
                  const SizedBox(height: AppTheme.space16),
                  SectionHeader(
                    title: 'Food entries',
                    action:
                        (_loadingEntries || entries.isEmpty)
                            ? null
                            : Text(
                              '${entries.length} item${entries.length == 1 ? '' : 's'}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                  ),
                  if (_loadingEntries)
                    ...List.generate(4, (_) => const SkeletonTile())
                  else if (entries.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: AppTheme.space16),
                      child: const EmptyStateView(
                        icon: Icons.restaurant_outlined,
                        title: 'No entries yet',
                        message: 'Add your first meal to start tracking.',
                      ),
                    )
                  else
                    ...List.generate(entries.length, (index) {
                      return _EntryTile(
                        key: ValueKey(entries[index].id),
                        entry: entries[index],
                        onTap: () => _openEntry(entries[index]),
                      );
                    }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openEntry(LogEntry entry) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => LogEntryScreen(
              food: {
                'id': entry.foodId,
                'name': entry.foodName!,
                'calories': entry.calories!,
                'fat': entry.fat!,
                'carbs': entry.carbs!,
                'protein': entry.protein!,
                'defaultPortionSize': entry.defaultPortionSize ?? 100.0,
                'portionDescription': entry.portionDescription ?? '100g',
                'unit': entry.unit ?? 'g',
                'hasServing': entry.hasServing ?? false,
              },
              date: widget.date,
              editMode: true,
              logId: entry.id!,
              initialAmount: entry.amount,
            ),
      ),
    );
    _loadEntries();
  }
}

/// A single food entry row. Renders immediately (no entrance animation) so the
/// list is never briefly invisible while a page transition is running.
class _EntryTile extends StatelessWidget {
  const _EntryTile({super.key, required this.entry, required this.onTap});

  final LogEntry entry;
  final VoidCallback onTap;

  String _amountLabel(LogEntry entry) {
    final unit = entry.unit ?? 'g';
    final amount = entry.amount;
    final amountStr = fmtNum(amount);
    if ((entry.hasServing ?? false) &&
        (entry.defaultPortionSize ?? 100) > 0 &&
        entry.portionDescription != null) {
      final portions = amount / (entry.defaultPortionSize ?? 100);
      return '$amountStr $unit · ${fmtNum(portions)} × ${entry.portionDescription}';
    }
    return '$amountStr $unit';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final kcal = fmtNum(entry.calories! * entry.amount / 100);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space8),
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.space12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.space8),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Icon(
                    Icons.restaurant_rounded,
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
                        entry.foodName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _amountLabel(entry),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppTheme.space8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      kcal,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'kcal',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Skeleton placeholder that matches the nutrition summary card's footprint so
/// the header/progress area doesn't jump when data arrives.
class _SummaryCardSkeleton extends StatelessWidget {
  const _SummaryCardSkeleton();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.space16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Skeleton(width: 160, height: 18),
          SizedBox(height: AppTheme.space16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Skeleton(width: 90, height: 14),
              Skeleton(width: 120, height: 14),
            ],
          ),
          SizedBox(height: AppTheme.space12),
          Skeleton(width: double.infinity, height: 10, radius: 8),
          SizedBox(height: AppTheme.space12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Skeleton(width: 80, height: 12),
              Skeleton(width: 80, height: 12),
            ],
          ),
        ],
      ),
    );
  }
}