import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/log_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';
import 'daily_log_screen.dart';

class DatePickerScreen extends StatefulWidget {
  const DatePickerScreen({super.key});

  @override
  State<DatePickerScreen> createState() => _DatePickerScreenState();
}

class _DatePickerScreenState extends State<DatePickerScreen> {
  List<Map<String, dynamic>> weekData = [];
  DateTime selectedDate = DateTime.now();
  final LogService _logService = LogService();
  bool _isLoading = true;

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

      final entries = await _logService.getLogEntriesByDate(dateStr);
      double sum = 0;
      for (var entry in entries) {
        sum += entry.calories! * entry.amount / 100;
      }

      data.add({
        'dateStr': dateStr,
        'weekday': DateFormat('EEEE').format(date),
        'pretty': DateFormat('MMM d').format(date),
        'cal': sum,
        'entries': entries.length,
        'isToday': i == 0,
        'isYesterday': i == 1,
      });
    }

    if (!mounted) return;
    setState(() {
      weekData = data;
      _isLoading = false;
    });
  }

  void _openDay(String dateStr) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DailyLogScreen(date: dateStr),
      ),
    );
  }

  Future<void> _selectDate() async {
    try {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: selectedDate,
        firstDate: DateTime(2020),
        lastDate: DateTime.now().add(const Duration(days: 365)),
      );
      if (!mounted || picked == null) return;

      setState(() => selectedDate = picked);
      _openDay(DateFormat('yyyy-MM-dd').format(picked));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting date: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: const PageAppBar(
        title: 'Select date',
        subtitle: 'Jump to a recent day or pick any date',
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AppTheme.pagePadding,
                        AppTheme.space12,
                        AppTheme.pagePadding,
                        AppTheme.space8,
                      ),
                      children: List.generate(
                        7,
                        (_) => const Padding(
                          padding: EdgeInsets.only(bottom: AppTheme.space8),
                          child: SkeletonTile(),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppTheme.pagePadding,
                        AppTheme.space12,
                        AppTheme.pagePadding,
                        AppTheme.space8,
                      ),
                      itemCount: weekData.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppTheme.space8),
                      itemBuilder: (context, index) =>
                          _buildDayRow(weekData[index]),
                    ),
            ),
            _buildPickButton(scheme),
          ],
        ),
      ),
    );
  }

  Widget _buildDayRow(Map<String, dynamic> item) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final isToday = item['isToday'] as bool;
    final entries = item['entries'] as int;
    final cal = (item['cal'] as double).round();

    final title = isToday
        ? 'Today'
        : (item['isYesterday'] as bool)
            ? 'Yesterday'
            : item['weekday'] as String;

    final subtitle = entries == 0
        ? '${item['pretty']} · No entries'
        : '${item['pretty']} · $entries ${entries == 1 ? 'entry' : 'entries'}';

    return SectionCard(
      color: isToday ? scheme.primaryContainer : null,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space16,
        vertical: AppTheme.space12,
      ),
      onTap: () => _openDay(item['dateStr'] as String),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.space8),
            decoration: BoxDecoration(
              color: isToday
                  ? scheme.onPrimaryContainer.withValues(alpha: 0.12)
                  : scheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Icon(
              isToday
                  ? Icons.today_rounded
                  : Icons.calendar_today_rounded,
              size: 20,
              color: isToday ? scheme.onPrimaryContainer : scheme.primary,
            ),
          ),
          const SizedBox(width: AppTheme.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: isToday ? scheme.onPrimaryContainer : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isToday
                        ? scheme.onPrimaryContainer.withValues(alpha: 0.8)
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.space8),
          Text(
            '$cal kcal',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: isToday ? scheme.onPrimaryContainer : scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickButton(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.pagePadding,
        AppTheme.space12,
        AppTheme.pagePadding,
        AppTheme.space16,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _selectDate,
          icon: const Icon(Icons.calendar_month_rounded),
          label: const Text('Pick another date'),
        ),
      ),
    );
  }
}
