import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/health_data.dart';
import '../models/log_entry.dart';
import '../services/log_service.dart';
import '../services/fasting_service.dart';
import '../models/fasting_settings.dart';
import '../services/scheduler_service.dart';
import '../utils/app_layout.dart';
import '../utils/num_format.dart';
import '../utils/health_permission_provider.dart';
import '../widgets/health_data_card.dart';
import '../widgets/add_entry_speed_dial.dart';
import '../widgets/fasting_overview_card.dart';
import '../widgets/ui_kit.dart';
import 'date_picker_screen.dart';
import 'ai_meal_planner_screen.dart';
import 'settings_screen.dart';
import 'daily_log_screen.dart';
import 'log_entry_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  double todayCal = 0;
  List<LogEntry> _todayEntries = [];
  bool _loadingEntries = true;
  HealthData _healthData = HealthData.empty();
  bool _isLoadingHealth = true;
  bool _isLoadingFasting = true;
  bool _healthBannerDismissed = false;
  FastingSettings? _fastingSettings;
  FastingStatus? _fastingStatus;
  Timer? _fastingTimer;
  int _fastingStreakDays = 0;
  Duration _timeUntilChange = Duration.zero;
  final String todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final String prettyToday = DateFormat.yMMMMd().format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _loadTodayData();
    _initializeHealthData();
    _loadFastingSettings();
  }

  Future<void> _loadTodayData() async {
    final logService = LogService();
    final entries = await logService.getLogEntriesByDate(todayDate);

    double sum = 0;
    for (var entry in entries) {
      sum += (entry.calories ?? 0) * entry.amount / 100;
    }

    if (!mounted) return;
    setState(() {
      todayCal = sum;
      _todayEntries = entries;
      _loadingEntries = false;
    });
  }

  Future<void> _loadFastingSettings() async {
    final settings = await FastingService.getSettings();
    final now = DateTime.now();
    final status = settings.statusAt(now);
    final streak = await FastingService.getStreak(now);

    if (!mounted) return;

    setState(() {
      _fastingSettings = settings;
      _fastingStatus = status;
      _isLoadingFasting = false;
      _fastingStreakDays = streak.days;
      final diff = status.nextChange.difference(now);
      _timeUntilChange = diff.isNegative ? Duration.zero : diff;
    });

    if (settings.enabled && status.enabled) {
      await SchedulerService.showEatingWindowNotification(
        timeRemaining:
            status.phase == FastingPhase.eating
                ? _timeUntilChange
                : Duration.zero,
        isActive: status.phase == FastingPhase.eating,
      );
      _startFastingTicker();
    } else {
      _stopFastingTicker();
      await SchedulerService.showEatingWindowNotification(
        timeRemaining: Duration.zero,
        isActive: false,
      );
    }
  }

  void _startFastingTicker() {
    _fastingTimer?.cancel();
    _fastingTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      await _refreshFastingStatus();
    });
    _refreshFastingStatus();
  }

  void _stopFastingTicker() {
    _fastingTimer?.cancel();
    _fastingTimer = null;
  }

  Future<void> _refreshFastingStatus() async {
    if (!mounted) return;
    final settings = _fastingSettings;
    if (settings == null || !settings.enabled) {
      return;
    }
    final now = DateTime.now();
    final nextStatus = settings.statusAt(now);
    final nextDiff = nextStatus.nextChange.difference(now);
    final remaining = nextDiff.isNegative ? Duration.zero : nextDiff;

    if (!mounted) return;

    setState(() {
      _fastingStatus = nextStatus;
      _timeUntilChange = remaining;
    });

    await SchedulerService.showEatingWindowNotification(
      timeRemaining:
          nextStatus.phase == FastingPhase.eating ? remaining : Duration.zero,
      isActive: nextStatus.phase == FastingPhase.eating,
    );
  }

  @override
  void dispose() {
    _stopFastingTicker();
    super.dispose();
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    ).then((_) {
      _loadFastingSettings();
      _loadTodayData();
    });
  }

  bool get _shouldShowFastingCard {
    final settings = _fastingSettings;
    final status = _fastingStatus;
    if (_isLoadingFasting || settings == null || status == null) {
      return false;
    }
    return settings.enabled && status.enabled;
  }

  Future<void> _initializeHealthData() async {
    final healthProvider = Provider.of<HealthPermissionProvider>(
      context,
      listen: false,
    );

    if (!healthProvider.isInitialized) {
      healthProvider.addListener(_onHealthProviderChange);
      return;
    }

    if (healthProvider.hasPermissions) {
      try {
        final healthData = await healthProvider.getTodayHealthData();
        if (!mounted) return;
        setState(() {
          _healthData = healthData;
          _isLoadingHealth = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() => _isLoadingHealth = false);
      }
    } else {
      if (!mounted) return;
      setState(() => _isLoadingHealth = false);
    }
  }

  void _onHealthProviderChange() {
    final healthProvider = Provider.of<HealthPermissionProvider>(
      context,
      listen: false,
    );

    if (healthProvider.isInitialized) {
      healthProvider.removeListener(_onHealthProviderChange);
      _initializeHealthData();
    }
  }

  Future<void> _requestHealthPermissions() async {
    final healthProvider = Provider.of<HealthPermissionProvider>(
      context,
      listen: false,
    );

    try {
      final granted = await healthProvider.requestPermissions();
      if (granted) {
        final healthData = await healthProvider.getTodayHealthData();
        if (!mounted) return;
        setState(() => _healthData = healthData);
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

  void _openDailyLog() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => DailyLogScreen(date: todayDate)),
    ).then((_) => _loadTodayData());
  }

  void _editEntry(LogEntry entry) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LogEntryScreen(
          food: {
            'id': entry.foodId,
            'name': entry.foodName ?? 'Food',
            'calories': entry.calories ?? 0,
            'fat': entry.fat ?? 0,
            'carbs': entry.carbs ?? 0,
            'protein': entry.protein ?? 0,
            'defaultPortionSize': entry.defaultPortionSize ?? 100.0,
            'portionDescription': entry.portionDescription ?? '100g',
            'unit': entry.unit ?? 'g',
            'hasServing': entry.hasServing ?? false,
          },
          date: todayDate,
          editMode: true,
          logId: entry.id,
          initialAmount: entry.amount,
        ),
      ),
    ).then((_) => _loadTodayData());
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Consumer<HealthPermissionProvider>(
      builder: (context, healthProvider, child) {
        return Scaffold(
          appBar: PageAppBar(
            title: 'Today',
            subtitle: prettyToday,
            automaticallyImplyLeading: false,
          ),
          floatingActionButton: AddEntrySpeedDial(
            date: todayDate,
            onComplete: _loadTodayData,
          ),
          body: SafeArea(
            top: false,
            child: RefreshIndicator(
              onRefresh: () async {
                await _loadTodayData();
                await _loadFastingSettings();
                await _initializeHealthData();
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppLayout.pagePadding,
                  AppLayout.sectionGap,
                  AppLayout.pagePadding,
                  96,
                ),
                children: [
                  // Compact today summary
                  Material(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppLayout.radius),
                    child: InkWell(
                      onTap: _openDailyLog,
                      borderRadius: BorderRadius.circular(AppLayout.radius),
                      child: Padding(
                        padding: const EdgeInsets.all(AppLayout.cardPadding),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Today's Log",
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: scheme.onPrimaryContainer,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _todayEntries.isEmpty
                                        ? 'No meals logged yet'
                                        : '${_todayEntries.length} '
                                            '${_todayEntries.length == 1 ? 'entry' : 'entries'}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: scheme.onPrimaryContainer
                                          .withOpacity(0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  todayCal.toStringAsFixed(0),
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: scheme.onPrimaryContainer,
                                  ),
                                ),
                                Text(
                                  'kcal',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.onPrimaryContainer
                                        .withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.chevron_right,
                              color: scheme.onPrimaryContainer.withOpacity(0.7),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppLayout.sectionGap),

                  if (_shouldShowFastingCard) ...[
                    FastingOverviewCard(
                      status: _fastingStatus!,
                      settings: _fastingSettings!,
                      streakDays: _fastingStreakDays,
                      onConfigure: _openSettings,
                      timeRemaining: _timeUntilChange,
                    ),
                    const SizedBox(height: AppLayout.sectionGap),
                  ],

                  if (_isLoadingHealth)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                    )
                  else if (!healthProvider.hasPermissions &&
                      !_healthBannerDismissed)
                    HealthPermissionBanner(
                      onRequestPermissions: _requestHealthPermissions,
                      onDismiss:
                          () => setState(() => _healthBannerDismissed = true),
                    )
                  else if (healthProvider.hasPermissions)
                    HealthDataCard(
                      healthData: _healthData,
                      showWorkoutSessions: false,
                    ),

                  const SizedBox(height: AppLayout.sectionGap),

                  const SectionHeader(title: "Today's meals"),
                  if (_loadingEntries)
                    ...List.generate(3, (_) => const SkeletonTile())
                  else if (_todayEntries.isEmpty)
                    const EmptyStateView(
                      icon: Icons.restaurant_outlined,
                      title: 'No meals yet',
                      message: 'Tap "Add entry" to log your first meal.',
                    )
                  else
                    ..._todayEntries.take(5).map((entry) {
                      final kcal =
                          fmtNum((entry.calories ?? 0) * entry.amount / 100);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: scheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(AppLayout.radius),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => _editEntry(entry),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          entry.foodName ?? 'Food',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${fmtNum(entry.amount)} ${entry.unit ?? 'g'}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: scheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '$kcal kcal',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: scheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  if (_todayEntries.length > 5)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: _openDailyLog,
                        child: Text(
                          '+${_todayEntries.length - 5} more',
                        ),
                      ),
                    ),

                  const SizedBox(height: AppLayout.sectionGap),

                  const SectionHeader(title: 'Actions'),
                  NavRow(
                    icon: Icons.calendar_today_outlined,
                    title: 'Select Date',
                    subtitle: 'Browse or open another day',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DatePickerScreen(),
                        ),
                      ).then((_) => _loadTodayData());
                    },
                  ),
                  const SizedBox(height: 8),
                  NavRow(
                    icon: Icons.auto_awesome_outlined,
                    title: 'AI Recipe Generator',
                    subtitle: 'Create recipes from a photo',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AiMealPlannerScreen(),
                        ),
                      ).then((_) => _loadTodayData());
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

