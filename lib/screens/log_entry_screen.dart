import 'package:flutter/material.dart';
import "../models/log_entry.dart";
import 'package:flutter/services.dart';
import '../services/log_service.dart';
import '../widgets/custom_alert.dart';

class LogEntryScreen extends StatefulWidget {
  final Map<String, dynamic> food;
  final String date;
  final bool editMode;
  final int? logId;

  const LogEntryScreen({
    super.key,
    required this.food,
    required this.date,
    this.editMode = false,
    this.logId,
  });

  @override
  State<LogEntryScreen> createState() => _LogEntryScreenState();
}

class _LogEntryScreenState extends State<LogEntryScreen> {
  final TextEditingController _amountController = TextEditingController();
  final LogService _logService = LogService();
  bool _usePortions = false;
  double _portions = 1.0;
  
  // Get the default portion size and description from food data or use defaults
  double get _defaultPortionSize => widget.food['defaultPortionSize'] ?? 100.0;
  String get _portionDescription => widget.food['portionDescription'] ?? "100g";
  
  Map<String, double> get totals {
    // Calculate based on either grams or portions
    double grams;
    
    if (_usePortions) {
      // Convert portions to grams
      final portions = double.tryParse(_amountController.text) ?? 0;
      grams = portions * _defaultPortionSize;
      _portions = portions;
    } else {
      grams = double.tryParse(_amountController.text) ?? 0;
      _portions = grams / _defaultPortionSize; // Calculate portions for the log entry
    }
    
    final factor = grams / 100;
    
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
    } else {
      // Default to the food's portion size, or 100g if not specified
      final defaultValue = widget.food['defaultPortionSize'] ?? 100.0;
      
      // If defaultPortionSize is not 100g, default to portions mode
      if (defaultValue != 100.0) {
        setState(() {
          _usePortions = true;
          _amountController.text = "1"; 
        });
      } else {
        _amountController.text = "100";
      }
    }
  }

  Future<void> _loadExistingAmount() async {
    final entries = await _logService.getLogEntriesByDate(widget.date);
    final entry = entries.firstWhere((e) => e.id == widget.logId);
    
    if (entry.portions != null && entry.portions! > 0) {
      setState(() {
        _usePortions = true;
        _portions = entry.portions ?? 1.0;
        _amountController.text = _portions.toString();
      });
    } else {
      _amountController.text = entry.amount.toString();
    }
  }

  Future<void> _saveLog() async {
    if (_amountController.text.isEmpty) return;
    
    double amount;
    double portions;
    
    if (_usePortions) {
      portions = double.parse(_amountController.text);
      amount = portions * _defaultPortionSize;
    } else {
      amount = double.parse(_amountController.text);
      portions = amount / _defaultPortionSize;
    }
    
    if (widget.editMode && widget.logId != null) {
      await _logService.updateLogEntry(
        LogEntry(
          id: widget.logId,
          foodId: widget.food['id'],
          amount: amount,
          portions: portions,
          date: widget.date,
        ),
      );
      Navigator.pop(context);
    } else {
      await _logService.insertLogEntry(
        LogEntry(
          foodId: widget.food['id'],
          amount: amount,
          portions: portions,
          date: widget.date,
        ),
      );
      
      Navigator.pop(context);
      Navigator.pop(context);
    }
  }

  void _showDeleteConfirmation() async {
    if (!widget.editMode || widget.logId == null) return;
    
    final bool confirm = await AlertHelper.showConfirmationAlert(
      context,
      title: 'Delete Entry',
      message: 'Are you sure you want to delete this ${widget.food['name']} entry?',
      confirmButtonText: 'Delete',
      type: AlertType.error,
    ) ?? false;

    if (confirm) {
      await _logService.deleteLogEntry(widget.logId!);
      if (mounted) {
        Navigator.pop(context); // Return to log screen
      }
    }
  }

  void _toggleInputMode(bool usePortions) {
    if (usePortions == _usePortions) return;
    
    String newValue = "";
    if (_amountController.text.isNotEmpty && double.tryParse(_amountController.text) != null) {
      final currentValue = double.parse(_amountController.text);
      if (usePortions) {
        // Convert grams to portions
        newValue = (currentValue / _defaultPortionSize).toStringAsFixed(1);
      } else {
        // Convert portions to grams
        newValue = (currentValue * _defaultPortionSize).toStringAsFixed(0);
      }
    } else {
      // Default values
      newValue = usePortions ? "1" : "100";
    }
    
    setState(() {
      _usePortions = usePortions;
      _amountController.text = newValue;
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.food['name'],
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
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
                
                // Portion information (if available)
                if (_defaultPortionSize != 100.0) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Per Serving',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Weight: ${_defaultPortionSize.toStringAsFixed(1)} g',
                          style: TextStyle(
                            fontSize: 16, 
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                            height: 1.5,
                          ),
                        ),
                        Text(
                          'Calories: ${(widget.food['calories'] * _defaultPortionSize / 100).toStringAsFixed(1)} kcal',
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
                ],
                const SizedBox(height: 24),
                
                // Toggle between grams and portions
                // Row(
                //   children: [
                //     Expanded(
                //       child: RadioListTile<bool>(
                //         title: const Text('Grams'),
                //         value: false,
                //         groupValue: _usePortions,
                //         onChanged: (value) => _toggleInputMode(value ?? false),
                //       ),
                //     ),
                //     Expanded(
                //       child: RadioListTile<bool>(
                //         title: const Text('Portions'),
                //         value: true,
                //         groupValue: _usePortions,
                //         onChanged: (value) => _toggleInputMode(value ?? true),
                //       ),
                //     ),
                //   ],
                // ),

                Container(
                  margin: const EdgeInsets.only(bottom: 16.0),
                  height: 50,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Stack(
                    children: [
                      // Animated selection indicator
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        left: _usePortions ? MediaQuery.of(context).size.width / 2 - 24 : 0,
                        right: _usePortions ? 0 : MediaQuery.of(context).size.width / 2 - 24,
                        top: 4,
                        bottom: 4,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(21),
                          ),
                        ),
                      ),
                      // Tab buttons
                      Row(
                        children: [
                          // Grams tab
                          Expanded(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _toggleInputMode(false),
                                borderRadius: BorderRadius.circular(25),
                                child: Center(
                                  child: Text(
                                    'Grams',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: !_usePortions 
                                          ? Theme.of(context).colorScheme.onPrimaryContainer
                                          : Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Portions tab
                          Expanded(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _toggleInputMode(true),
                                borderRadius: BorderRadius.circular(25),
                                child: Center(
                                  child: Text(
                                    'Portions',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: _usePortions 
                                          ? Theme.of(context).colorScheme.onPrimaryContainer
                                          : Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Amount input
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _usePortions ? 'Number of portions' : 'Amount eaten (g)',
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
                        suffixText: _usePortions ? _portionDescription : 'g',
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
                    
                    // Show conversion helper
                    if (_usePortions && _amountController.text.isNotEmpty && double.tryParse(_amountController.text) != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                        child: Text(
                          'Equivalent to ${(double.parse(_amountController.text) * _defaultPortionSize).toStringAsFixed(1)}g',
                          style: TextStyle(
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
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
                          'Total for ${_usePortions ? "${_amountController.text} portions" : "${_amountController.text}g"}:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
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
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
                      style: TextStyle(
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
                      onPressed: _showDeleteConfirmation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
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