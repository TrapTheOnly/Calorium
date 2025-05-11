import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/log_service.dart';
import 'daily_log_screen.dart';

class DatePickerScreen extends StatefulWidget {
  const DatePickerScreen({Key? key}) : super(key: key);

  @override
  State<DatePickerScreen> createState() => _DatePickerScreenState();
}

class _DatePickerScreenState extends State<DatePickerScreen> {
  List<Map<String, dynamic>> weekData = [];
  DateTime selectedDate = DateTime.now();
  final LogService _logService = LogService();

  @override
  void initState() {
    super.initState();
    _loadWeekData();
  }

  Future<void> _loadWeekData() async {
    List<Map<String, dynamic>> data = [];
    final today = DateTime.now();
    
    for (int i = 0; i < 7; i++) {
      final date = DateTime(today.year, today.month, today.day - i);
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final prettyDate = DateFormat('MMM d').format(date);
      
      final entries = await _logService.getLogEntriesByDate(dateStr);
      double sum = 0;
      for (var entry in entries) {
        sum += entry.calories! * entry.amount / 100;
      }
      
      data.add({
        'dateStr': dateStr,
        'pretty': prettyDate,
        'cal': sum,
      });
    }
    
    setState(() {
      weekData = data;
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2025),
    );
    
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
      
      final dateStr = DateFormat('yyyy-MM-dd').format(picked);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DailyLogScreen(date: dateStr),
        ),
      );
    }
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
              Text(
                'Select Date',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onBackground,
                ),
              ),
              const SizedBox(height: 24),
              
              Expanded(
                child: ListView.builder(
                  itemCount: weekData.length,
                  itemBuilder: (context, index) {
                    final item = weekData[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DailyLogScreen(date: item['dateStr']),
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 18,
                          horizontal: 20,
                        ),
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              item['pretty'],
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                            ),
                            Text(
                              '${item['cal'].round()} kcal',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _selectDate(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: 5,
                  ),
                  child: const Text(
                    'Pick Another Date',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}