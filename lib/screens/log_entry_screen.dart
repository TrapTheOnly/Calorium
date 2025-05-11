import 'package:flutter/material.dart';
import "../models/log_entry.dart";
import 'package:flutter/services.dart';
import '../services/log_service.dart';

class LogEntryScreen extends StatefulWidget {
  final Map<String, dynamic> food;
  final String date;
  final bool editMode;
  final int? logId;

  const LogEntryScreen({
    Key? key,
    required this.food,
    required this.date,
    this.editMode = false,
    this.logId,
  }) : super(key: key);

  @override
  State<LogEntryScreen> createState() => _LogEntryScreenState();
}

class _LogEntryScreenState extends State<LogEntryScreen> {
  final TextEditingController _amountController = TextEditingController();
  final LogService _logService = LogService();
  
  Map<String, double> get totals {
    final g = double.tryParse(_amountController.text) ?? 0;
    final factor = g / 100;
    
    return {
      'cal': widget.food['calories'] * factor,
      'prot': widget.food['protein'] * factor,
      'fat': widget.food['fat'] * factor,
      'carb': widget.food['carbs'] * factor,
    };
  }

  @override
  void initState() {
    super.initState();
    if (widget.editMode && widget.logId != null) {
      _loadExistingAmount();
    }
  }

  Future<void> _loadExistingAmount() async {
    final entries = await _logService.getLogEntriesByDate(widget.date);
    final entry = entries.firstWhere((e) => e.id == widget.logId);
    _amountController.text = entry.amount.toString();
  }

  Future<void> _saveLog() async {
    if (_amountController.text.isEmpty) return;
    
    final amount = double.parse(_amountController.text);
    
    if (widget.editMode && widget.logId != null) {
      await _logService.updateLogEntry(
        LogEntry(
          id: widget.logId,
          foodId: widget.food['id'],
          amount: amount,
          date: widget.date,
        ),
      );
    } else {
      await _logService.insertLogEntry(
        LogEntry(
          foodId: widget.food['id'],
          amount: amount,
          date: widget.date,
        ),
      );
    }
    
    Navigator.pop(context);
  }

  Future<void> _deleteLog() async {
    if (!widget.editMode || widget.logId == null) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Entry'),
        content: Text('Are you sure you want to delete this ${widget.food['name']} entry?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await _logService.deleteLogEntry(widget.logId!);
              if (mounted) {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Return to log screen
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
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
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.food['name'],
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF101010),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Per 100g info
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Per 100 g',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Calories: ${widget.food['calories'].toStringAsFixed(1)} kcal',
                        style: TextStyle(
                          fontSize: 16, 
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                          height: 1.5,
                        ),
                      ),
                      Text(
                        'Protein: ${widget.food['protein'].toStringAsFixed(1)} g',
                        style: TextStyle(
                          fontSize: 16, 
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                          height: 1.5,
                        ),
                      ),
                      Text(
                        'Fat: ${widget.food['fat'].toStringAsFixed(1)} g',
                        style: TextStyle(
                          fontSize: 16, 
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                          height: 1.5,
                        ),
                      ),
                      Text(
                        'Carbs: ${widget.food['carbs'].toStringAsFixed(1)} g',
                        style: TextStyle(
                          fontSize: 16, 
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Amount input
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Amount eaten (g)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$'))],
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        hintText: '0',
                        hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      style: TextStyle(
                        fontSize: 18,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Live total
                if (_amountController.text.isNotEmpty && double.tryParse(_amountController.text) != null)
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Calories: ${totals['cal']!.toStringAsFixed(0)} kcal',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                            height: 1.5,
                          ),
                        ),
                        Text(
                          'Protein: ${totals['prot']!.toStringAsFixed(1)} g',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                            height: 1.5,
                          ),
                        ),
                        Text(
                          'Fat: ${totals['fat']!.toStringAsFixed(1)} g',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                            height: 1.5,
                          ),
                        ),
                        Text(
                          'Carbs: ${totals['carb']!.toStringAsFixed(1)} g',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                
                // Save button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _amountController.text.isEmpty ? null : _saveLog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.4),
                      disabledForegroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 5,
                    ),
                    child: Text(
                      widget.editMode ? 'Update Entry' : 'Add to Log',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                
                // Delete button (only in edit mode)
                if (widget.editMode)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _deleteLog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF4455),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 5,
                      ),
                      child: const Text(
                        'Delete Entry',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}