import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/health_data.dart';
import '../models/log_entry.dart';
import '../services/log_service.dart';
import '../services/health_service.dart';
import '../utils/health_permission_provider.dart';
import '../widgets/enhanced_nutrition_summary_card.dart';
import '../widgets/health_data_card.dart';
import '../widgets/ai_suggestions_card.dart';
import '../widgets/add_food_options_dialog.dart';
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
    setState(() {
      entries = loadedEntries;
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

  void _showAddEntryOptions() {
    showDialog(
      context: context,
      builder: (context) => AddFoodOptionsDialog(
        date: widget.date,
        onComplete: _loadEntries,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HealthPermissionProvider>(
      builder: (context, healthProvider, child) {
        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.surface,
            elevation: 0,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back,
                color: Theme.of(context).colorScheme.primary,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.home_outlined, color: Theme.of(context).colorScheme.primary, size: 28),
                onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
              ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Text(
                    'Daily Log',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    prettyDate,
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 28),
                  
                  // Scrollable content
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Enhanced Nutrition Summary with Health Integration
                          EnhancedNutritionSummaryCard(
                            nutritionData: {
                              'cal': totals['cal']!,
                              'prot': totals['prot']!,
                              'fat': totals['fat']!,
                              'carb': totals['carb']!,
                            },
                            healthData: healthProvider.hasPermissions ? _healthData : null,
                            onSetTargetsTap: _navigateToSettings,
                            onHealthPermissionTap: !healthProvider.hasPermissions ? _requestHealthPermissions : null,
                          ),
                          
                          // AI Suggestions Card
                          AiSuggestionsCard(date: widget.date),
                          
                          const SizedBox(height: 28),
                          
                          // Entries section header
                          Text(
                            'Food Entries',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Entries list
                          entries.isEmpty
                              ? Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(32),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.restaurant_outlined,
                                        size: 48,
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No entries yet',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Start tracking your nutrition by adding your first meal',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : Column(
                                  children: entries.map((entry) {
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      child: InkWell(
                                        onTap: () async {
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => LogEntryScreen(
                                                food: {
                                                  'id': entry.foodId,
                                                  'name': entry.foodName!,
                                                  'calories': entry.calories!,
                                                  'fat': entry.fat!,
                                                  'carbs': entry.carbs!,
                                                  'protein': entry.protein!,
                                                  'defaultPortionSize': entry.defaultPortionSize ?? 100.0,
                                                  'portionDescription': entry.portionDescription ?? '100g',
                                                },
                                                date: widget.date,
                                                editMode: true,
                                                logId: entry.id!,
                                              ),
                                            ),
                                          );
                                          _loadEntries();
                                        },
                                        borderRadius: BorderRadius.circular(16),
                                        child: Container(
                                          padding: const EdgeInsets.all(20),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.surface,
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(
                                              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Theme.of(context).colorScheme.shadow.withOpacity(0.05),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            children: [
                                              // Food icon
                                              Container(
                                                padding: const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context).colorScheme.primaryContainer,
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Icon(
                                                  Icons.restaurant,
                                                  color: Theme.of(context).colorScheme.primary,
                                                  size: 24,
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              
                                              // Food details
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      entry.foodName!,
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.w600,
                                                        color: Theme.of(context).colorScheme.onSurface,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      '${entry.amount}g',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              
                                              // Calories
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    (entry.calories! * entry.amount / 100).toStringAsFixed(0),
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight: FontWeight.bold,
                                                      color: Theme.of(context).colorScheme.primary,
                                                    ),
                                                  ),
                                                  Text(
                                                    'kcal',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                          
                          // Bottom padding for FAB
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          floatingActionButton: SizedBox(
            width: MediaQuery.of(context).size.width - 48,
            height: 56,
            child: FloatingActionButton.extended(
              onPressed: _showAddEntryOptions,
              backgroundColor: Theme.of(context).colorScheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
              label: Text(
                '＋ Add Entry',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        );
      },
    );
  }
}