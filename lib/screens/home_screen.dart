import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/log_service.dart';
import 'daily_log_screen.dart';
import 'date_picker_screen.dart';
import 'ai_meal_planner_screen.dart';
import 'settings_screen.dart';
import 'weekly_analysis_screen.dart';
import 'inventory_screen.dart';
import '../widgets/add_food_options_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  double todayCal = 0;
  bool _hasSevenDaysData = false;
  final String todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final String prettyToday = DateFormat.yMMMMd().format(DateTime.now());
  
  @override
  void initState() {
    super.initState();
    _loadTodayCalories();
    _checkSevenDaysData();
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
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
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
                  color: Theme.of(context).colorScheme.onBackground,
                ),
              ),
              const SizedBox(height: 24),
              
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
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
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
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                ),
                              ),
                              Text(
                                prettyToday,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
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
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                            ),
                            Text(
                              'kcal',
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
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
              
              // Action Buttons
              _buildActionButton(
                'Select Date',
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const DatePickerScreen()),
                  );
                },
              ),
              
              const SizedBox(height: 16),
              
              _buildActionButton(
                'Quick Add to Today',
                _showQuickAddOptions,
              ),
              
              const SizedBox(height: 16),
              
              _buildActionButton(
                'Inventory',
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const InventoryScreen(),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 16),
              
              _buildActionButton(
                'AI Recipe Generator',
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AiMealPlannerScreen(),
                    ),
                  ).then((_) => _loadTodayCalories());
                },
              ),
              
              const SizedBox(height: 16),
              
              _buildActionButton(
                'Weekly Analysis',
                _hasSevenDaysData 
                  ? () {
                      // Get the past 7 days starting from today
                      final endDate = DateTime.now();
                      final startDate = endDate.subtract(const Duration(days: 6));
                      final weekStartString = DateFormat('yyyy-MM-dd').format(startDate);
                      
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => WeeklyAnalysisScreen(weekStartDate: weekStartString),
                        ),
                      );
                    }
                  : () {
                      // Show alert that 7 days of data is required
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Text('Insufficient Data'),
                            content: const Text('At least 7 days of logged food data is required to generate a weekly analysis. Please continue logging your meals and try again.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('OK'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                isEnabled: _hasSevenDaysData,
              ),
              
              const SizedBox(height: 16),
              
              _buildActionButton(
                'Settings',
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SettingsScreen()),
                  );
                },
              ),
              
              // Bottom padding to ensure proper spacing from screen bottom
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildActionButton(String text, VoidCallback onPressed, {bool isEnabled = true}) {
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
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}