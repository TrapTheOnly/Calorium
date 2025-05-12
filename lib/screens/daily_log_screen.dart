import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/log_entry.dart';
import '../services/log_service.dart';
import 'inventory_screen.dart';
import 'log_entry_screen.dart';
import '../widgets/nutrition_summary_card.dart';

class DailyLogScreen extends StatefulWidget {
  final String date;

  const DailyLogScreen({Key? key, required this.date}) : super(key: key);

  @override
  State<DailyLogScreen> createState() => _DailyLogScreenState();
}

class _DailyLogScreenState extends State<DailyLogScreen> {
  List<LogEntry> entries = [];
  final LogService _logService = LogService();
  late final String prettyDate;

  @override
  void initState() {
    super.initState();
    prettyDate = DateFormat.yMMMMd().format(DateTime.parse(widget.date));
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final loadedEntries = await _logService.getLogEntriesByDate(widget.date);
    setState(() {
      entries = loadedEntries;
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.background,
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
                  color: Theme.of(context).colorScheme.onBackground,
                ),
              ),
              Text(
                prettyDate,
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onBackground,
                ),
              ),
              const SizedBox(height: 28),
              
              // Totals card
              NutritionSummaryCard(
                nutritionData: {
                  'cal': totals['cal']!,
                  'prot': totals['prot']!,
                  'fat': totals['fat']!,
                  'carb': totals['carb']!,
                },
              ),
              const SizedBox(height: 28),
              
              // Entries list
              Expanded(
                child: entries.isEmpty
                    ? const Center(
                        child: Text(
                          'No entries yet',
                          style: TextStyle(color: Color(0xFF888888)),
                        ),
                      )
                    : ListView.builder(
                        itemCount: entries.length,
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          return InkWell(
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
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: const BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: Color(0xFFECECEC),
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          entry.foodName!,
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                            color: Theme.of(context).colorScheme.onSecondaryContainer,
                                          ),
                                        ),
                                        Text(
                                          '${entry.amount} g',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF607080),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '${(entry.calories! * entry.amount / 100).toStringAsFixed(0)} kcal',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
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
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => InventoryScreen(date: widget.date),
              ),
            );
            _loadEntries();
          },
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
  }
}