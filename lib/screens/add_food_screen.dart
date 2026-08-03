import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/food.dart';
import '../models/log_entry.dart';
import '../services/food_service.dart';
import '../services/log_service.dart';
import '../theme/app_theme.dart';
import '../utils/fasting_prompt.dart';
import '../utils/num_format.dart';
import '../widgets/ui_kit.dart';

class AddFoodScreen extends StatefulWidget {
  final Food? food;
  final String? date;

  const AddFoodScreen({super.key, this.food, this.date});

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
  final _tagController = TextEditingController();

  final FoodService _foodService = FoodService();
  final LogService _logService = LogService();

  bool _usePortions = false; // Toggle between grams and portions
  bool _isLiquid = false; // Base measured by volume (ml) instead of weight (g)
  bool _hasServing = false; // Whether a distinct serving size is defined
  List<String> _selectedTags = [];
  List<String> _availableTags = [];

  /// Standard household volumes (US) for liquid serving presets.
  static const Map<String, double> _volumePresetsMl = {
    'tsp': 5,
    'tbsp': 15,
    'cup': 240,
    'fl oz': 29.57,
  };

  /// Selected liquid serving preset key, or null for a custom ml value.
  String? _servingPreset;
  final _servingQtyController = TextEditingController(text: '1');

  bool get isEditing => widget.food != null;
  bool get isFromBarcode => widget.food != null && widget.food!.id == null;

  String get _unit => _isLiquid ? 'ml' : 'g';

  @override
  void initState() {
    super.initState();
    _loadAvailableTags();

    if (isEditing) {
      _nameController.text = widget.food!.name;
      _caloriesController.text = widget.food!.calories.toString();
      _fatController.text = widget.food!.fat.toString();
      _carbsController.text = widget.food!.carbs.toString();
      _proteinController.text = widget.food!.protein.toString();
      _portionSizeController.text = widget.food!.defaultPortionSize.toString();
      _portionDescController.text = widget.food!.portionDescription;
      _isLiquid = widget.food!.isLiquid;
      _hasServing = widget.food!.hasServing;
      // Editing keeps the stored ml/description via the custom fields.
      _servingPreset = null;
      _selectedTags = List.from(widget.food!.tags);
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

  Future<void> _loadAvailableTags() async {
    try {
      final tags = await _foodService.getAllSimpleFoodTags();
      setState(() {
        _availableTags = tags;
      });
    } catch (e) {
      // Handle error silently
    }
  }

  void _addTag(String tag) {
    final trimmedTag = tag.trim().toLowerCase();
    if (trimmedTag.isNotEmpty && !_selectedTags.contains(trimmedTag)) {
      setState(() {
        _selectedTags.add(trimmedTag);
        if (!_availableTags.contains(trimmedTag)) {
          _availableTags.add(trimmedTag);
          _availableTags.sort();
        }
      });
      _tagController.clear();
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _selectedTags.remove(tag);
    });
  }

  /// Parses "1", "1.5", "1/2" or mixed "1 1/2" into a double.
  double _parseQty(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return 0;
    try {
      final parts = s.split(RegExp(r'\s+'));
      double frac(String f) {
        final b = f.split('/');
        if (b.length != 2) return 0;
        final d = double.parse(b[1]);
        return d == 0 ? 0 : double.parse(b[0]) / d;
      }

      if (parts.length == 2 && parts[1].contains('/')) {
        return double.parse(parts[0]) + frac(parts[1]);
      }
      if (s.contains('/')) return frac(s);
      return double.parse(s);
    } catch (_) {
      return 0;
    }
  }

  /// Recomputes the serving size (ml) + description from the selected liquid
  /// preset and quantity (e.g. "3/4" + "cup" -> 180 ml, "3/4 cup").
  void _recalcLiquidServing() {
    final preset = _servingPreset;
    if (preset == null) return; // custom: user edits ml/description directly
    // Treat a blank/invalid quantity as 1 so the ml value and the description
    // never disagree (no "1 cup = 0 ml").
    final rawQty = _parseQty(_servingQtyController.text);
    final qty = rawQty > 0 ? rawQty : 1;
    final qtyText = _servingQtyController.text.trim().isEmpty
        ? '1'
        : _servingQtyController.text.trim();
    final ml = qty * (_volumePresetsMl[preset] ?? 1);
    _portionSizeController.text = fmtNum(ml);
    _portionDescController.text = '$qtyText $preset';
  }

  Widget _buildLiquidServingSetup() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final resultMl = double.tryParse(_portionSizeController.text) ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Serving measure', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ..._volumePresetsMl.keys.map(
              (p) => ChoiceChip(
                label: Text(p),
                selected: _servingPreset == p,
                onSelected: (_) => setState(() {
                  _servingPreset = p;
                  _recalcLiquidServing();
                }),
              ),
            ),
            ChoiceChip(
              label: const Text('Custom ml'),
              selected: _servingPreset == null,
              onSelected: (_) => setState(() => _servingPreset = null),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_servingPreset != null) ...[
          TextField(
            controller: _servingQtyController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9./ ]')),
            ],
            onChanged: (_) => setState(_recalcLiquidServing),
            decoration: InputDecoration(
              labelText: 'Quantity',
              suffixText: _servingPreset,
              helperText: 'Fractions allowed, e.g. 3/4',
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: const ['1/4', '1/3', '1/2', '2/3', '3/4', '1', '2']
                .map(
                  (f) => ActionChip(
                    label: Text(f),
                    onPressed: () {
                      _servingQtyController.text = f;
                      setState(_recalcLiquidServing);
                    },
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          Text(
            '= ${fmtNum(resultMl)} ml per serving',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ] else ...[
          _buildFormInput(
            'Serving size (ml)',
            _portionSizeController,
            numeric: true,
          ),
          _buildFormInput(
            'Description (e.g. "1 glass")',
            _portionDescController,
          ),
        ],
      ],
    );
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
    _tagController.dispose();
    _servingQtyController.dispose();
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
      defaultPortionSize:
          _hasServing ? (double.tryParse(_portionSizeController.text) ?? 100.0) : 100.0,
      portionDescription: _hasServing
          ? _portionDescController.text
          : '100$_unit',
      tags: _selectedTags,
      unit: _unit,
      hasServing: _hasServing,
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

    final entry = LogEntry(
      foodId: widget.food!.id!,
      amount: amount,
      portions: portions,
      date: widget.date!,
    );

    await _logService.insertLogEntry(entry);

    if (mounted) {
      await FastingPrompt.showIfNeeded(
        context,
        loggedAt: entry.loggedAt,
        mealName: widget.food?.name,
      );
      if (!mounted) return;
    }

    Navigator.pop(context, widget.food!.id);
    Navigator.popUntil(
      context,
      (route) => route.settings.name == 'DailyLogScreen' || route.isFirst,
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
      defaultPortionSize:
          _hasServing ? (double.tryParse(_portionSizeController.text) ?? 100.0) : 100.0,
      portionDescription: _hasServing
          ? _portionDescController.text
          : '100$_unit',
      tags: _selectedTags,
      unit: _unit,
      hasServing: _hasServing,
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
        final portionSize =
            double.tryParse(_portionSizeController.text) ?? 100.0;
        amount = portions * portionSize;
      } else {
        // Direct gram input
        amount = double.parse(_amountController.text);
      }

      final entry = LogEntry(
        foodId: foodId,
        amount: amount,
        portions: portions,
        date: widget.date!,
      );

      await _logService.insertLogEntry(entry);

      if (mounted) {
        await FastingPrompt.showIfNeeded(
          context,
          loggedAt: entry.loggedAt,
          mealName: _nameController.text.trim(),
        );
        if (!mounted) return;
      }

      Navigator.pop(context, foodId);
      Navigator.popUntil(
        context,
        (route) => route.settings.name == 'DailyLogScreen' || route.isFirst,
      );
    } else {
      Navigator.pop(context, foodId);
    }
  }

  bool get canSaveAndLog {
    if (_nameController.text.trim().isEmpty) return false;
    if (_caloriesController.text.isEmpty ||
        double.tryParse(_caloriesController.text) == null ||
        double.tryParse(_caloriesController.text)! <= 0) {
      return false;
    }
    if (_hasServing &&
        (_portionSizeController.text.isEmpty ||
            double.tryParse(_portionSizeController.text) == null ||
            double.tryParse(_portionSizeController.text)! <= 0)) {
      return false;
    }
    if (widget.date != null) {
      if (_usePortions &&
          (_portionsController.text.isEmpty ||
              double.tryParse(_portionsController.text) == null ||
              double.tryParse(_portionsController.text)! <= 0)) {
        return false;
      }
      if (!_usePortions &&
          (_amountController.text.isEmpty ||
              double.tryParse(_amountController.text) == null ||
              double.tryParse(_amountController.text)! <= 0)) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: PageAppBar(
        title: isEditing && !isFromBarcode
            ? 'Edit food'
            : (isFromBarcode ? 'Add scanned food' : 'Add food'),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFormInput('Name', _nameController),

              // Base unit selector (weight vs volume).
              Text('Measured by', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    label: Text('Weight (g)'),
                    icon: Icon(Icons.scale_rounded, size: 18),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text('Volume (ml)'),
                    icon: Icon(Icons.local_drink_rounded, size: 18),
                  ),
                ],
                selected: {_isLiquid},
                showSelectedIcon: false,
                onSelectionChanged: (s) {
                  setState(() {
                    _isLiquid = s.first;
                    // Keep the portion description's unit in sync when it's the
                    // default so liquids round-trip as volume.
                    final desc = _portionDescController.text.trim();
                    if (desc.isEmpty || desc == '100g' || desc == '100ml') {
                      _portionDescController.text = '100$_unit';
                    }
                  });
                },
              ),
              const SizedBox(height: 16),

              // Nutrition section with distinct, color-coded macros.
              Text(
                'Nutrition per 100 $_unit',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              _macroField(
                'Calories',
                _caloriesController,
                scheme.primary,
                suffix: 'kcal',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _macroField(
                      'Protein',
                      _proteinController,
                      scheme.primary,
                      suffix: 'g',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _macroField(
                      'Carbs',
                      _carbsController,
                      scheme.tertiary,
                      suffix: 'g',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _macroField(
                      'Fat',
                      _fatController,
                      scheme.secondary,
                      suffix: 'g',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Optional serving section.
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  title: const Text('Has a serving size'),
                  subtitle: Text(
                    _hasServing
                        ? 'Serving will be offered when logging'
                        : 'Only logged by ${_isLiquid ? 'volume' : 'weight'}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  value: _hasServing,
                  onChanged: (v) {
                    setState(() {
                      _hasServing = v;
                      if (v && _isLiquid && !isEditing) {
                        // Offer a sensible default liquid serving.
                        _servingPreset = 'cup';
                        _servingQtyController.text = '1';
                        _recalcLiquidServing();
                      }
                    });
                  },
                ),
              ),
              if (_hasServing) ...[
                const SizedBox(height: 12),
                if (_isLiquid)
                  _buildLiquidServingSetup()
                else ...[
                  _buildFormInput(
                    'Serving size ($_unit)',
                    _portionSizeController,
                    numeric: true,
                  ),
                  _buildFormInput(
                    'Description (e.g. "1 bar", "1 slice")',
                    _portionDescController,
                  ),
                ],
              ],

              const SizedBox(height: 12),

              // Tags section
              Text(
                'Tags',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Add tags to help organize and find this food later',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),

              // Tag input field
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _tagController,
                      decoration: InputDecoration(
                        hintText: 'Enter a tag',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Theme.of(
                              context,
                            ).colorScheme.outline.withOpacity(0.2),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Theme.of(
                              context,
                            ).colorScheme.outline.withOpacity(0.2),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                      ),
                      onSubmitted: (value) => _addTag(value),
                      textInputAction: TextInputAction.done,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _addTag(_tagController.text),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      minimumSize: const Size(60, 56),
                    ),
                    child: const Icon(Icons.add),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Available tags (quick add)
              if (_availableTags.isNotEmpty) ...[
                Text(
                  'Quick Add',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      _availableTags
                          .where((tag) => !_selectedTags.contains(tag))
                          .map(
                            (tag) => GestureDetector(
                              onTap: () => _addTag(tag),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest
                                      .withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outline.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      tag,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.add,
                                      size: 14,
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                          .toList(),
                ),
                const SizedBox(height: 12),
              ],

              // Selected tags
              if (_selectedTags.isNotEmpty) ...[
                Text(
                  'Selected Tags',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      _selectedTags
                          .map(
                            (tag) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    tag,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onPrimary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  GestureDetector(
                                    onTap: () => _removeTag(tag),
                                    child: Icon(
                                      Icons.close,
                                      size: 14,
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                ),
                const SizedBox(height: 12),
              ],

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
                if (_hasServing)
                Container(
                  margin: const EdgeInsets.only(bottom: 16.0),
                  height: 50,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Stack(
                    children: [
                      // Animated selection indicator
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        left:
                            _usePortions
                                ? MediaQuery.of(context).size.width / 2 - 24
                                : 0,
                        right:
                            _usePortions
                                ? 0
                                : MediaQuery.of(context).size.width / 2 - 24,
                        top: 4,
                        bottom: 4,
                        child: Container(
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).colorScheme.primaryContainer,
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
                                      color:
                                          !_usePortions
                                              ? Theme.of(
                                                context,
                                              ).colorScheme.onPrimaryContainer
                                              : Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
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
                                      color:
                                          _usePortions
                                              ? Theme.of(
                                                context,
                                              ).colorScheme.onPrimaryContainer
                                              : Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
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
                  _buildFormInput(
                    'Number of portions',
                    _portionsController,
                    numeric: true,
                  )
                else
                  _buildFormInput(
                    'Amount eaten ($_unit)',
                    _amountController,
                    numeric: true,
                  ),

                // Show estimation of actual amount
                if (_usePortions &&
                    double.tryParse(_portionsController.text) != null &&
                    double.tryParse(_portionSizeController.text) != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: Text(
                      'Estimated amount: ${(double.parse(_portionsController.text) * double.parse(_portionSizeController.text)).toStringAsFixed(1)}$_unit',
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
                  disabled:
                      _nameController.text.trim().isEmpty ||
                      (_hasServing && _portionSizeController.text.isEmpty),
                ),
                if (widget.date != null)
                  _buildPrimaryButton(
                    'Add to Log',
                    _addLogExisting,
                    disabled:
                        (_usePortions && _portionsController.text.isEmpty) ||
                        (!_usePortions && _amountController.text.isEmpty),
                  ),
              ] else
                _buildPrimaryButton(
                  'Save${widget.date != null ? ' & Log Entry' : ''}',
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

  /// A compact, color-coded numeric field used for calories/macros so each
  /// nutrient is visually distinct at a glance.
  Widget _macroField(
    String label,
    TextEditingController controller,
    Color color, {
    required String suffix,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
          ],
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: '0',
            suffixText: suffix,
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              borderSide: BorderSide(color: color, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormInput(
    String label,
    TextEditingController controller, {
    bool numeric = false,
  }) {
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
            inputFormatters:
                numeric
                    ? [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
                    ]
                    : null,
            onChanged: (value) {
              setState(() {});
            },
            decoration: InputDecoration(
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              hintText: '',
              hintStyle: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
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

  Widget _buildPrimaryButton(
    String text,
    VoidCallback onPressed, {
    bool disabled = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18.0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: disabled ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            disabledBackgroundColor: Theme.of(
              context,
            ).colorScheme.primary.withOpacity(0.4),
            disabledForegroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            elevation: 5,
          ),
          child: Text(
            text,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
