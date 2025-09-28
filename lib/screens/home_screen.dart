import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/health_data.dart';
import '../services/log_service.dart';
import '../services/fasting_service.dart';
import '../models/fasting_settings.dart';
import '../services/scheduler_service.dart';
import '../utils/health_permission_provider.dart';
import '../widgets/health_data_card.dart';
import '../widgets/custom_alert.dart';
import '../widgets/add_food_options_dialog.dart';
import '../widgets/fasting_overview_card.dart';
import 'date_picker_screen.dart';
import 'inventory_screen.dart';
import 'ai_meal_planner_screen.dart';
import 'weekly_analysis_screen.dart';
import 'settings_screen.dart';
import 'daily_log_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  double todayCal = 0;
  bool _hasSevenDaysData = false;
  HealthData _healthData = HealthData.empty();
  bool _isLoadingHealth = true;
  bool _isLoadingFasting = true;
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
    _loadTodayCalories();
    _checkSevenDaysData();
    _initializeHealthData();
    _loadFastingSettings();
  }

  Future<void> _loadTodayCalories() async {
    final logService = LogService();
    final entries = await logService.getLogEntriesByDate(todayDate);

    double sum = 0;
    for (var entry in entries) {
      sum += entry.calories! * entry.amount / 100;
    }

    setState(() {
      todayCal = sum;
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
      _loadTodayCalories();
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

  Widget _buildFastingCard() {
    final settings = _fastingSettings!;
    final status = _fastingStatus!;

    return FastingOverviewCard(
      status: status,
      settings: settings,
      streakDays: _fastingStreakDays,
      onConfigure: _openSettings,
      timeRemaining: _timeUntilChange,
    );
  }

  Future<void> _checkSevenDaysData() async {
    final logService = LogService();
    int daysWithData = 0;

    // Check the past 7 days
    for (int i = 0; i < 7; i++) {
      final date = DateTime.now().subtract(Duration(days: i));
      final dateString = DateFormat('yyyy-MM-dd').format(date);
      final entries = await logService.getLogEntriesByDate(dateString);

      if (entries.isNotEmpty) {
        daysWithData++;
      }
    }

    setState(() {
      _hasSevenDaysData = daysWithData >= 7;
    });
  }

  Future<void> _initializeHealthData() async {
    final healthProvider = Provider.of<HealthPermissionProvider>(
      context,
      listen: false,
    );

    // Wait for provider to initialize if it hasn't already
    if (!healthProvider.isInitialized) {
      // Listen for initialization completion
      healthProvider.addListener(_onHealthProviderChange);
      return;
    }

    if (healthProvider.hasPermissions) {
      try {
        final healthData = await healthProvider.getTodayHealthData();
        setState(() {
          _healthData = healthData;
          _isLoadingHealth = false;
        });
      } catch (e) {
        setState(() {
          _isLoadingHealth = false;
        });
      }
    } else {
      setState(() {
        _isLoadingHealth = false;
      });
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

  void _showQuickAddOptions() {
    AddFoodOptionsDialog.show(
      context,
      date: todayDate,
      title: 'Quick Add to Today',
      subtitle: 'Choose how you want to add food to today\'s log',
      onComplete: _loadTodayCalories,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HealthPermissionProvider>(
      builder: (context, healthProvider, child) {
        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  Text(
                    'Calorium',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  // Today Card
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DailyLogScreen(date: todayDate),
                        ),
                      ).then((_) => _loadTodayCalories());
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                border: Border(
                                  right: BorderSide(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Today's Log",
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                  Text(
                                    prettyToday,
                                    style: TextStyle(
                                      fontSize: 15,
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 80,
                            child: Column(
                              children: [
                                Text(
                                  todayCal.toStringAsFixed(0),
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        Theme.of(
                                          context,
                                        ).colorScheme.onPrimaryContainer,
                                  ),
                                ),
                                Text(
                                  'kcal',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color:
                                        Theme.of(
                                          context,
                                        ).colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  if (_shouldShowFastingCard) ...[
                    _buildFastingCard(),
                    const SizedBox(height: 24),
                  ],

                  // Health Data Section
                  if (_isLoadingHealth) ...[
                    Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color:
                            Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                  ] else if (!healthProvider.hasPermissions) ...[
                    HealthPermissionCard(
                      onRequestPermissions: () {
                        debugPrint(
                          '[HomeScreen] HealthPermissionCard tapped - requesting permissions',
                        );
                        _requestHealthPermissions();
                      },
                    ),
                  ] else ...[
                    HealthDataCard(
                      healthData: _healthData,
                      showWorkoutSessions: false,
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Action Buttons
                  _buildActionButton('Select Date', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DatePickerScreen(),
                      ),
                    );
                  }),

                  const SizedBox(height: 16),

                  _buildActionButton(
                    'Quick Add to Today',
                    _showQuickAddOptions,
                  ),

                  const SizedBox(height: 16),

                  _buildActionButton('Inventory', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const InventoryScreen(),
                      ),
                    );
                  }),

                  const SizedBox(height: 16),

                  _buildActionButton('AI Recipe Generator', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AiMealPlannerScreen(),
                      ),
                    ).then((_) => _loadTodayCalories());
                  }),

                  const SizedBox(height: 16),

                  _buildActionButton(
                    'Weekly Analysis',
                    _hasSevenDaysData
                        ? () {
                          // Get the past 7 days starting from today
                          final endDate = DateTime.now();
                          final startDate = endDate.subtract(
                            const Duration(days: 6),
                          );
                          final weekStartString = DateFormat(
                            'yyyy-MM-dd',
                          ).format(startDate);

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => WeeklyAnalysisScreen(
                                    weekStartDate: weekStartString,
                                  ),
                            ),
                          );
                        }
                        : () {
                          // Show alert that 7 days of data is required
                          AlertHelper.showInfoAlert(
                            context,
                            title: 'Insufficient Data',
                            message:
                                'At least 7 days of logged food data is required to generate a weekly analysis. Please continue logging your meals and try again.',
                          );
                        },
                    isEnabled: _hasSevenDaysData,
                  ),

                  const SizedBox(height: 16),

                  _buildActionButton('Settings', _openSettings),

                  // Bottom padding to ensure proper spacing from screen bottom
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButton(
    String text,
    VoidCallback onPressed, {
    bool isEnabled = true,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isEnabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
