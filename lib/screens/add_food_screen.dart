import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/food.dart';
import '../models/log_entry.dart';
import '../services/food_service.dart';
import '../services/log_service.dart';

class AddFoodScreen extends StatefulWidget {
  final Food? food;
  final String? date;

  const AddFoodScreen({Key? key, this.food, this.date}) : super(key: key);

  @override
  State<AddFoodScreen> createState() => _AddFoodScreenState();
}

class _AddFoodScreenState extends State<AddFoodScreen> {
  final _nameController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _fatController = TextEditingController();
  final _carbsController = TextEditingController();
  final _proteinController = TextEditingController();
  final _amountController = TextEditingController();
  final _portionSizeController = TextEditingController();
  final _portionDescController = TextEditingController();
  final _portionsController = TextEditingController();
  
  final FoodService _foodService = FoodService();
  final LogService _logService = LogService();
  
  bool _usePortions = false; // Toggle between grams and portions
  
  bool get isEditing => widget.food != null;
  bool get isFromBarcode => widget.food != null && widget.food!.id == null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _nameController.text = widget.food!.name;
      _caloriesController.text = widget.food!.calories.toString();
      _fatController.text = widget.food!.fat.toString();
      _carbsController.text = widget.food!.carbs.toString();
      _proteinController.text = widget.food!.protein.toString();
      _portionSizeController.text = widget.food!.defaultPortionSize.toString();
      _portionDescController.text = widget.food!.portionDescription;
    } else {
      _portionSizeController.text = "100";
      _portionDescController.text = "100g";
    }

    // Default for amount/portions when logging
    if (widget.date != null) {
      _amountController.text = "100";
      _portionsController.text = "1";
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _caloriesController.dispose();
    _fatController.dispose();
    _carbsController.dispose();
    _proteinController.dispose();
    _amountController.dispose();
    _portionSizeController.dispose();
    _portionDescController.dispose();
    _portionsController.dispose();
    super.dispose();
  }

  Future<void> _saveExisting() async {
    if (_nameController.text.trim().isEmpty) return;
    
    final updatedFood = Food(
      id: widget.food!.id,
      name: _nameController.text.trim(),
      calories: double.tryParse(_caloriesController.text) ?? 0,
      fat: double.tryParse(_fatController.text) ?? 0,
      carbs: double.tryParse(_carbsController.text) ?? 0,
      protein: double.tryParse(_proteinController.text) ?? 0,
      type: 'simple',
      defaultPortionSize: double.tryParse(_portionSizeController.text) ?? 100.0,
      portionDescription: _portionDescController.text,
    );
    
    await _foodService.updateFood(updatedFood);
    Navigator.pop(context, updatedFood.id);
  }

  Future<void> _addLogExisting() async {
    if (widget.date == null) return;
    if (_usePortions && _portionsController.text.isEmpty) return;
    if (!_usePortions && _amountController.text.isEmpty) return;
    
    double amount;
    double portions = 1.0;
    
    if (_usePortions) {
      // Calculate grams based on portions and default portion size
      portions = double.parse(_portionsController.text);
      amount = portions * (widget.food!.defaultPortionSize);
    } else {
      // Direct gram input
      amount = double.parse(_amountController.text);
    }
    
    await _logService.insertLogEntry(
      LogEntry(
        foodId: widget.food!.id!,
        amount: amount,
        portions: portions,
        date: widget.date!,
      ),
    );
    
    Navigator.pop(context, widget.food!.id);
    Navigator.popUntil(
      context, 
      (route) => route.settings.name == 'DailyLogScreen' || route.isFirst
    );
  }

  Future<int> _insertSimple() async {
    final newFood = Food(
      name: _nameController.text.trim(),
      calories: double.tryParse(_caloriesController.text) ?? 0,
      fat: double.tryParse(_fatController.text) ?? 0,
      carbs: double.tryParse(_carbsController.text) ?? 0,
      protein: double.tryParse(_proteinController.text) ?? 0,
      type: 'simple',
      defaultPortionSize: double.tryParse(_portionSizeController.text) ?? 100.0,
      portionDescription: _portionDescController.text,
    );
    
    return await _foodService.insertFood(newFood);
  }

  Future<void> _saveAndLogNew() async {
    if (_nameController.text.trim().isEmpty) return;
    if (widget.date != null) {
      if (_usePortions && _portionsController.text.isEmpty) return;
      if (!_usePortions && _amountController.text.isEmpty) return;
    }
    
    final foodId = await _insertSimple();
    
    if (widget.date != null) {
      double amount;
      double portions = 1.0;
      
      if (_usePortions) {
        // Calculate grams based on portions and default portion size
        portions = double.parse(_portionsController.text);
        final portionSize = double.tryParse(_portionSizeController.text) ?? 100.0;
        amount = portions * portionSize;
      } else {
        // Direct gram input
        amount = double.parse(_amountController.text);
      }
      
      await _logService.insertLogEntry(
        LogEntry(
          foodId: foodId,
          amount: amount,
          portions: portions,
          date: widget.date!,
        ),
      );
      
      Navigator.pop(context, foodId);
      Navigator.popUntil(
        context, 
        (route) => route.settings.name == 'DailyLogScreen' || route.isFirst
      );
    } else {
      Navigator.pop(context, foodId);
    }
  }

  bool get canSaveAndLog {
    if (_nameController.text.trim().isEmpty) return false;
    if (_caloriesController.text.isEmpty || 
        double.tryParse(_caloriesController.text) == null || 
        double.tryParse(_caloriesController.text)! <= 0) return false;
    if (_portionSizeController.text.isEmpty || 
        double.tryParse(_portionSizeController.text) == null || 
        double.tryParse(_portionSizeController.text)! <= 0) return false;
    if (widget.date != null) {
      if (_usePortions && (_portionsController.text.isEmpty || 
          double.tryParse(_portionsController.text) == null || 
          double.tryParse(_portionsController.text)! <= 0)) return false;
      if (!_usePortions && (_amountController.text.isEmpty || 
          double.tryParse(_amountController.text) == null || 
          double.tryParse(_amountController.text)! <= 0)) return false;
    }
    return true;
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEditing && !isFromBarcode ? 'Edit Food' : (isFromBarcode ? 'Add Scanned Food' : 'Add Food'),
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 24),
              
              // Food info section
              Text(
                'Food Information',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              
              _buildFormInput('Name', _nameController),
              _buildFormInput('Calories/100g', _caloriesController, numeric: true),
              _buildFormInput('Fat/100g', _fatController, numeric: true),
              _buildFormInput('Carbs/100g', _carbsController, numeric: true),
              _buildFormInput('Protein/100g', _proteinController, numeric: true),
              
              const SizedBox(height: 12),
              
              // Portion size section
              Text(
                'Portion Information',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Define a standard portion size for this food',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              
              _buildFormInput('Portion Size (g)', _portionSizeController, numeric: true),
              _buildFormInput('Description (e.g. "1 bar", "1 cup")', _portionDescController),
              
              // Logging section - only show when adding to daily log
              if (widget.date != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Add to Log',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                
                // // Toggle between portions and grams
                // Row(
                //   children: [
                //     Expanded(
                //       child: RadioListTile<bool>(
                //         title: const Text('Grams'),
                //         value: false,
                //         groupValue: _usePortions,
                //         onChanged: (bool? value) {
                //           setState(() {
                //             _usePortions = value ?? false;
                //           });
                //         },
                //       ),
                //     ),
                //     Expanded(
                //       child: RadioListTile<bool>(
                //         title: const Text('Portions'),
                //         value: true,
                //         groupValue: _usePortions,
                //         onChanged: (bool? value) {
                //           setState(() {
                //             _usePortions = value ?? true;
                //           });
                //         },
                //       ),
                //     ),
                //   ],
                // ),
                
                Container(
                  margin: const EdgeInsets.only(bottom: 16.0),
                  height: 50,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
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
                                onTap: () {
                                  setState(() {
                                    _usePortions = false;
                                  });
                                },
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
                                onTap: () {
                                  setState(() {
                                    _usePortions = true;
                                  });
                                },
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
                
                if (_usePortions)
                  _buildFormInput('Number of portions', _portionsController, numeric: true)
                else
                  _buildFormInput('Amount eaten (g)', _amountController, numeric: true),
                
                // Show estimation of actual amount
                if (_usePortions && double.tryParse(_portionsController.text) != null && double.tryParse(_portionSizeController.text) != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: Text(
                      'Estimated amount: ${(double.parse(_portionsController.text) * double.parse(_portionSizeController.text)).toStringAsFixed(1)}g',
                      style: TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
              
              const SizedBox(height: 20),
              
              if (isEditing && !isFromBarcode) ...[
                _buildPrimaryButton(
                  'Save Changes',
                  _saveExisting,
                  disabled: _nameController.text.trim().isEmpty || _portionSizeController.text.isEmpty,
                ),
                if (widget.date != null)
                  _buildPrimaryButton(
                    'Add to Log',
                    _addLogExisting,
                    disabled: (_usePortions && _portionsController.text.isEmpty) || 
                              (!_usePortions && _amountController.text.isEmpty),
                  ),
              ] else
                _buildPrimaryButton(
                  'Save' + (widget.date != null ? ' & Log Entry' : ''),
                  _saveAndLogNew,
                  disabled: !canSaveAndLog,
                ),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormInput(String label, TextEditingController controller, {bool numeric = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType: numeric ? TextInputType.number : TextInputType.text,
            inputFormatters: numeric
                ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$'))]
                : null,
            onChanged: (value) {
              setState(() {});
            },
            decoration: InputDecoration(
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              hintText: '',
              hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Theme.of(context).colorScheme.outline.withOpacity(0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                ),
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
    );
  }

  Widget _buildPrimaryButton(String text, VoidCallback onPressed, {bool disabled = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18.0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: disabled ? null : onPressed,
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
            text,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}