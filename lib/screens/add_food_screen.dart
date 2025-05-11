import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/food.dart';
import '../models/log_entry.dart';
import '../services/food_service.dart';
import '../services/log_service.dart';

class AddFoodScreen extends StatefulWidget {
  final Food? food;
  final String? date;
  final VoidCallback? onSave; // Add callback for custom navigation

  const AddFoodScreen({Key? key, this.food, this.date, this.onSave}) : super(key: key);

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
  
  final FoodService _foodService = FoodService();
  final LogService _logService = LogService();
  
  // Keep the original check but add logic for barcode foods
  bool get isEditing => widget.food != null;
  bool get isBarcodeFood => widget.food?.fromBarcode == true;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _nameController.text = widget.food!.name;
      _caloriesController.text = widget.food!.calories.toString();
      _fatController.text = widget.food!.fat.toString();
      _carbsController.text = widget.food!.carbs.toString();
      _proteinController.text = widget.food!.protein.toString();
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
    super.dispose();
  }

  Future<void> _saveExisting() async {
    if (_nameController.text.trim().isEmpty) return;
    
    if (isBarcodeFood) {
      // For barcode foods, treat as new food instead of updating
      await _saveAndLogNew();
      return;
    }
    
    final updatedFood = Food(
      id: widget.food!.id,
      name: _nameController.text.trim(),
      calories: double.tryParse(_caloriesController.text) ?? 0,
      fat: double.tryParse(_fatController.text) ?? 0,
      carbs: double.tryParse(_carbsController.text) ?? 0,
      protein: double.tryParse(_proteinController.text) ?? 0,
      type: 'simple',
    );
    
    await _foodService.updateFood(updatedFood);
    
    if (widget.onSave != null) {
      widget.onSave!();
    } else {
      Navigator.pop(context, updatedFood.id);
    }
  }

  Future<void> _addLogExisting() async {
    if (_amountController.text.isEmpty || widget.date == null) return;
    
    if (isBarcodeFood) {
      // For barcode foods, insert as new food first
      final foodId = await _insertSimple();
      await _logService.insertLogEntry(
        LogEntry(
          foodId: foodId,
          amount: double.parse(_amountController.text),
          date: widget.date!,
        ),
      );
      
      if (widget.onSave != null) {
        widget.onSave!();
      } else {
        Navigator.pop(context, foodId);
        Navigator.popUntil(
          context, 
          (route) => route.settings.name == 'DailyLogScreen' || route.isFirst
        );
      }
      return;
    }
    
    await _logService.insertLogEntry(
      LogEntry(
        foodId: widget.food!.id!,
        amount: double.parse(_amountController.text),
        date: widget.date!,
      ),
    );
    
    if (widget.onSave != null) {
      widget.onSave!();
    } else {
      Navigator.pop(context, widget.food!.id);
      Navigator.popUntil(
        context, 
        (route) => route.settings.name == 'DailyLogScreen' || route.isFirst
      );
    }
  }

  Future<int> _insertSimple() async {
    final newFood = Food(
      name: _nameController.text.trim(),
      calories: double.tryParse(_caloriesController.text) ?? 0,
      fat: double.tryParse(_fatController.text) ?? 0,
      carbs: double.tryParse(_carbsController.text) ?? 0,
      protein: double.tryParse(_proteinController.text) ?? 0,
      type: 'simple',
    );
    
    return await _foodService.insertFood(newFood);
  }

  Future<void> _saveAndLogNew() async {
    if (_nameController.text.trim().isEmpty) return;
    if (widget.date != null && _amountController.text.isEmpty) return;
    
    final foodId = await _insertSimple();
    
    if (widget.date != null) {
      await _logService.insertLogEntry(
        LogEntry(
          foodId: foodId,
          amount: double.parse(_amountController.text),
          date: widget.date!,
        ),
      );
      
      if (widget.onSave != null) {
        widget.onSave!();
      } else {
        Navigator.pop(context, foodId);
        Navigator.popUntil(
          context, 
          (route) => route.settings.name == 'DailyLogScreen' || route.isFirst
        );
      }
    } else {
      if (widget.onSave != null) {
        widget.onSave!();
      } else {
        Navigator.pop(context, foodId);
      }
    }
  }

  bool get canSaveAndLog {
    if (_nameController.text.trim().isEmpty) return false;
    if (_caloriesController.text.isEmpty || 
        double.tryParse(_caloriesController.text) == null || 
        double.tryParse(_caloriesController.text)! <= 0) return false;
    if (widget.date != null && (_amountController.text.isEmpty || 
        double.tryParse(_amountController.text) == null || 
        double.tryParse(_amountController.text)! <= 0)) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final String titleText = isBarcodeFood 
        ? 'Add Scanned Food' 
        : (isEditing ? 'Edit Food' : 'Add Food');
    
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titleText,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onBackground,
                ),
              ),
              const SizedBox(height: 24),
              
              _buildFormInput('Name', _nameController),
              _buildFormInput('Calories/100g', _caloriesController, numeric: true),
              _buildFormInput('Fat/100g', _fatController, numeric: true),
              _buildFormInput('Carbs/100g', _carbsController, numeric: true),
              _buildFormInput('Protein/100g', _proteinController, numeric: true),
              
              if (widget.date != null)
                _buildFormInput('Amount eaten (g)', _amountController, numeric: true),
              
              const SizedBox(height: 20),
              
              if (isEditing && !isBarcodeFood) ...[
                _buildPrimaryButton(
                  'Save Changes',
                  _saveExisting,
                  disabled: _nameController.text.trim().isEmpty,
                ),
                if (widget.date != null)
                  _buildPrimaryButton(
                    'Add to Log',
                    _addLogExisting,
                    disabled: _amountController.text.isEmpty,
                  ),
              ] else if (isBarcodeFood) ...[
                _buildPrimaryButton(
                  'Save Scanned Food',
                  _saveAndLogNew,
                  disabled: !canSaveAndLog,
                ),
              ] else
                _buildPrimaryButton(
                  'Save & Log Entry',
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