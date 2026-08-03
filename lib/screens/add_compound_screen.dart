import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/food.dart';
import '../services/food_service.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../utils/num_format.dart';
import '../widgets/ui_kit.dart';

class AddCompoundScreen extends StatefulWidget {
  final Food? food;

  const AddCompoundScreen({super.key, this.food});

  @override
  State<AddCompoundScreen> createState() => _AddCompoundScreenState();
}

class _AddCompoundScreenState extends State<AddCompoundScreen> {
  final _nameController = TextEditingController();
  final _searchController = TextEditingController();
  final _servingsController = TextEditingController(text: '1');
  final FoodService _foodService = FoodService();
  final Map<int, TextEditingController> _amountControllers = {};
  final Map<int, FocusNode> _amountFocus = {};

  List<Food> _catalog = [];
  List<Map<String, dynamic>> components = []; // {food, amount}
  bool _isLiquid = false; // recipe measured by volume (ml) instead of weight
  bool _attemptedSave = false; // gates inline validation until first save press

  bool get isEditing => widget.food != null;

  String get _unit => _isLiquid ? 'ml' : 'g';

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _nameController.text = widget.food!.name;
      _isLiquid = widget.food!.isLiquid;
      _loadExistingComponents();
    }
    _searchCatalog('');
  }

  Future<void> _loadExistingComponents() async {
    final db = await DatabaseService.instance.database;

    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT f.*, c.amount 
      FROM components c 
      JOIN foods f ON f.id = c.componentId 
      WHERE c.recipeId = ?
    ''', [widget.food!.id]);

    if (maps.isNotEmpty) {
      double totalWeight = 0;
      setState(() {
        components = maps.map((row) {
          final food = Food.fromMap(row);
          final amount = (row['amount'] as num).toDouble();
          totalWeight += amount;
          _amountControllers[food.id!] =
              TextEditingController(text: amount > 0 ? _trim(amount) : '');
          _amountFocus[food.id!] = FocusNode();
          return <String, dynamic>{'food': food, 'amount': amount};
        }).toList();

        // Recover the serving count from the stored per-serving portion.
        final portion = widget.food!.defaultPortionSize;
        if (portion > 0 && totalWeight > 0) {
          final servings = (totalWeight / portion).round().clamp(1, 999);
          _servingsController.text = servings.toString();
        }
      });
    }
  }

  Future<void> _searchCatalog(String query) async {
    final foods = await _foodService.getSimpleFoods();
    setState(() {
      _catalog = query.isEmpty
          ? foods
          : foods
              .where((f) => f.name.toLowerCase().contains(query.toLowerCase()))
              .toList();
    });
  }

  void _addComponent(Food food) {
    if (components.any((comp) => comp['food'].id == food.id)) return;
    _amountControllers[food.id!] = TextEditingController(text: '');
    final focus = FocusNode();
    _amountFocus[food.id!] = focus;
    setState(() {
      components.add({'food': food, 'amount': 0.0});
    });
    // Focus the new amount field so the user can type immediately.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (focus.context != null) focus.requestFocus();
    });
  }

  void _updateAmount(int foodId, String value) {
    setState(() {
      final index = components.indexWhere((comp) => comp['food'].id == foodId);
      if (index != -1) {
        components[index]['amount'] = double.tryParse(value) ?? 0.0;
      }
    });
  }

  void _removeComponent(int foodId) {
    setState(() {
      components.removeWhere((comp) => comp['food'].id == foodId);
    });
    _amountControllers[foodId]?.dispose();
    _amountControllers.remove(foodId);
    _amountFocus[foodId]?.dispose();
    _amountFocus.remove(foodId);
  }

  String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  int get _servings {
    final v = int.tryParse(_servingsController.text) ?? 1;
    return v < 1 ? 1 : v;
  }

  Map<String, double> get summary {
    double weight = 0, cal = 0, fat = 0, carb = 0, prot = 0;
    for (var comp in components) {
      final food = comp['food'] as Food?;
      if (food == null) continue;
      final amount = comp['amount'] as double;
      weight += amount;
      cal += food.calories * amount / 100;
      fat += food.fat * amount / 100;
      carb += food.carbs * amount / 100;
      prot += food.protein * amount / 100;
    }
    return {'weight': weight, 'cal': cal, 'fat': fat, 'carb': carb, 'prot': prot};
  }

  bool get canSave {
    final hasValidName = _nameController.text.trim().isNotEmpty;
    final hasComponents = components.isNotEmpty;
    final hasValidAmounts =
        components.every((comp) => (comp['amount'] as double) > 0);
    return hasValidName && hasComponents && hasValidAmounts;
  }

  void _onSavePressed() {
    if (!canSave) {
      setState(() => _attemptedSave = true);
      final String reason;
      if (_nameController.text.trim().isEmpty) {
        reason = 'Enter a recipe name';
      } else if (components.isEmpty) {
        reason = 'Add at least one ingredient';
      } else {
        reason = 'Enter an amount for every ingredient';
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(reason)));
      return;
    }
    _saveRecipe();
  }

  Future<void> _saveRecipe() async {
    if (!canSave) return;

    final db = await DatabaseService.instance.database;
    final totalWeight = summary['weight']!;
    final factor = totalWeight > 0 ? 100 / totalWeight : 0;
    final servings = _servings;

    final per100 = {
      'cal': summary['cal']! * factor,
      'fat': summary['fat']! * factor,
      'carb': summary['carb']! * factor,
      'prot': summary['prot']! * factor,
    };
    final perServing = totalWeight / servings;

    await db.transaction((txn) async {
      int? id = isEditing ? widget.food!.id : null;

      final values = {
        'name': _nameController.text.trim(),
        'calories': per100['cal'],
        'fat': per100['fat'],
        'carbs': per100['carb'],
        'protein': per100['prot'],
        'defaultPortionSize': perServing,
        'portionDescription': servings > 1 ? '1 serving' : 'whole recipe',
        'unit': _unit,
        'hasServing': 1,
      };

      if (isEditing) {
        await txn.update('foods', values, where: 'id = ?', whereArgs: [id]);
        await txn.delete('components', where: 'recipeId = ?', whereArgs: [id]);
      } else {
        values['type'] = 'compound';
        id = await txn.insert('foods', values);
      }

      for (var comp in components) {
        await txn.insert('components', {
          'recipeId': id,
          'componentId': (comp['food'] as Food).id,
          'amount': comp['amount'],
        });
      }
    });

    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    _servingsController.dispose();
    for (var controller in _amountControllers.values) {
      controller.dispose();
    }
    for (var node in _amountFocus.values) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasComponents = components.isNotEmpty;

    return Scaffold(
      appBar: PageAppBar(title: isEditing ? 'Edit recipe' : 'New recipe'),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.pagePadding,
            AppTheme.space8,
            AppTheme.pagePadding,
            AppTheme.space24,
          ),
          children: [
            TextField(
              controller: _nameController,
              onChanged: (_) => setState(() {}),
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Recipe name',
                hintText: 'e.g. Chicken & rice bowl',
                prefixIcon: Icon(Icons.layers_rounded),
              ),
            ),
            const SizedBox(height: AppTheme.space16),

            if (hasComponents) ...[
              _buildSummary(),
              const SizedBox(height: AppTheme.space16),
            ],

            _buildServingSetup(),
            const SizedBox(height: AppTheme.space20),

            SectionHeader(
              title: 'Ingredients',
              action: hasComponents
                  ? Text(
                      '${components.length} item${components.length == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    )
                  : null,
            ),
            if (!hasComponents)
              const EmptyStateView(
                icon: Icons.blender_outlined,
                title: 'No ingredients yet',
                message: 'Search below to add foods to this recipe.',
              )
            else
              ...components.map(_buildComponentRow),

            const SizedBox(height: AppTheme.space20),
            const SectionHeader(title: 'Add ingredients'),
            TextField(
              controller: _searchController,
              onChanged: _searchCatalog,
              decoration: InputDecoration(
                hintText: 'Search your basics…',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _searchController.clear();
                          _searchCatalog('');
                        },
                      )
                    : null,
              ),
            ),
            const SizedBox(height: AppTheme.space8),
            _buildCatalog(),

            const SizedBox(height: AppTheme.space24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _onSavePressed,
                child: Text(isEditing ? 'Save changes' : 'Save recipe'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = summary;
    final servings = _servings;
    final perServingCal = servings > 0 ? s['cal']! / servings : s['cal']!;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppTheme.space16),
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                servings > 1 ? 'Per serving' : 'Whole recipe',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    fmtNum(perServingCal),
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'kcal',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Makes $servings serving${servings == 1 ? '' : 's'} · '
                '${fmtNum(s['weight']!)} $_unit total',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.space8),
        Row(
          children: [
            Expanded(
              child: _macroChip(
                'Protein',
                servings > 0 ? s['prot']! / servings : s['prot']!,
                scheme.primary,
              ),
            ),
            const SizedBox(width: AppTheme.space8),
            Expanded(
              child: _macroChip(
                'Carbs',
                servings > 0 ? s['carb']! / servings : s['carb']!,
                scheme.tertiary,
              ),
            ),
            const SizedBox(width: AppTheme.space8),
            Expanded(
              child: _macroChip(
                'Fat',
                servings > 0 ? s['fat']! / servings : s['fat']!,
                scheme.secondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _macroChip(String label, double value, Color color) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppTheme.space12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Column(
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
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${fmtNum(value)} g',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServingSetup() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Measured by', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppTheme.space8),
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
            onSelectionChanged: (s) => setState(() => _isLiquid = s.first),
          ),
          const SizedBox(height: AppTheme.space16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Servings', style: theme.textTheme.titleMedium),
                    Text(
                      'Splits the recipe into equal portions',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              _Stepper(
                controller: _servingsController,
                onChanged: () => setState(() {}),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildComponentRow(Map<String, dynamic> comp) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final food = comp['food'] as Food;
    final amount = comp['amount'] as double;
    final cal = food.calories * amount / 100;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space8),
      child: SectionCard(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.space12,
          AppTheme.space8,
          AppTheme.space8,
          AppTheme.space12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row: name + remove.
            Row(
              children: [
                Icon(
                  food.isLiquid
                      ? Icons.local_drink_rounded
                      : Icons.restaurant_rounded,
                  size: 18,
                  color: scheme.primary,
                ),
                const SizedBox(width: AppTheme.space8),
                Expanded(
                  child: Text(
                    food.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _removeComponent(food.id!),
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.space8),
            // Detail row: amount field + contribution.
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 128,
                  child: TextField(
                    controller: _amountControllers[food.id!],
                    focusNode: _amountFocus[food.id!],
                    onChanged: (value) => _updateAmount(food.id!, value),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
                    ],
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: 'Amount',
                      hintText: '0',
                      suffixText: food.unit,
                      errorText: (_attemptedSave && amount <= 0)
                          ? 'Required'
                          : null,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.space12,
                        vertical: AppTheme.space12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        amount > 0 ? '${fmtNum(cal)} kcal' : '—',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${fmtNum(food.calories)} kcal / 100 ${food.unit}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCatalog() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // Hide already-added foods and cap the list to keep the page light.
    final addedIds = components.map((c) => (c['food'] as Food).id).toSet();
    final filtered =
        _catalog.where((f) => !addedIds.contains(f.id)).toList();
    final results = filtered.take(20).toList();

    if (results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.space16),
        child: Center(
          child: Text(
            _searchController.text.isNotEmpty
                ? 'No matching basics'
                : 'All your foods are in this recipe',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (int i = 0; i < results.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                InkWell(
                  onTap: () => _addComponent(results[i]),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.space12,
                      vertical: AppTheme.space12,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          results[i].isLiquid
                              ? Icons.local_drink_rounded
                              : Icons.restaurant_rounded,
                          size: 18,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: AppTheme.space12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                results[i].name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${fmtNum(results[i].calories)} kcal / 100 ${results[i].unit}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppTheme.space8),
                        Icon(Icons.add_circle_outline_rounded,
                            color: scheme.primary),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (filtered.length > results.length)
          Padding(
            padding: const EdgeInsets.only(top: AppTheme.space8, left: AppTheme.space4),
            child: Text(
              'Showing ${results.length} of ${filtered.length} — search to narrow',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

/// A compact +/- integer stepper with a directly-editable value field.
class _Stepper extends StatelessWidget {
  const _Stepper({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final VoidCallback onChanged;

  void _bump(int delta) {
    final current = int.tryParse(controller.text) ?? 1;
    final next = (current + delta).clamp(1, 999);
    controller.text = next.toString();
    controller.selection =
        TextSelection.collapsed(offset: controller.text.length);
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final current = int.tryParse(controller.text) ?? 1;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: current <= 1 ? null : () => _bump(-1),
            icon: const Icon(Icons.remove_rounded),
            visualDensity: VisualDensity.compact,
          ),
          SizedBox(
            width: 40,
            child: TextField(
              controller: controller,
              onChanged: (_) => onChanged(),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
              decoration: const InputDecoration(
                isCollapsed: true,
                filled: false,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          IconButton(
            onPressed: current >= 999 ? null : () => _bump(1),
            icon: const Icon(Icons.add_rounded),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
