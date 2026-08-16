import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/food.dart';
import '../models/imported_recipe.dart';
import '../models/log_entry.dart';
import '../services/food_service.dart';
import '../services/imported_recipe_service.dart';
import '../services/log_service.dart';
import '../theme/app_theme.dart';
import '../utils/fasting_prompt.dart';
import '../utils/num_format.dart';
import '../models/imported_ingredient_line.dart';
import '../widgets/custom_alert.dart';
import '../widgets/ui_kit.dart';
import 'recipe_import_screen.dart';

/// Detail view for a recipe imported from a shared video: shows the thumbnail,
/// live nutrition + inventory-linked ingredients + instructions, links to the
/// original, and logs servings to the date selected by the caller.
class ImportedRecipeDetailScreen extends StatefulWidget {
  const ImportedRecipeDetailScreen({
    super.key,
    required this.recipe,
    this.date,
  });

  final ImportedRecipe recipe;
  final String? date;

  @override
  State<ImportedRecipeDetailScreen> createState() =>
      _ImportedRecipeDetailScreenState();
}

class _ImportedRecipeDetailScreenState
    extends State<ImportedRecipeDetailScreen> {
  final LogService _logService = LogService();
  final TextEditingController _servingsController =
      TextEditingController(text: '1');

  late ImportedRecipe _recipe;
  Food? _food;
  List<ImportedIngredientLine> _lines = [];
  List<ImportedComponent> _components = [];
  bool _loading = true;
  bool _isLogging = false;
  final Set<int> _checked = {};

  @override
  void initState() {
    super.initState();
    _recipe = widget.recipe;
    _servingsController.addListener(() {
      if (mounted) setState(() {});
    });
    _load();
  }

  @override
  void dispose() {
    _servingsController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final foodId = _recipe.foodId;
    final food = await FoodService().getFoodById(foodId);
    final lines = await ImportedRecipeService.getLines(foodId);
    final components = lines.isEmpty
        ? await ImportedRecipeService.getComponents(foodId)
        : const <ImportedComponent>[];
    final refreshed = await ImportedRecipeService.getByFoodId(foodId);
    if (!mounted) return;
    setState(() {
      if (refreshed != null) _recipe = refreshed;
      _food = food;
      _lines = lines;
      _components = components;
      _checked.clear();
      _loading = false;
    });
  }

  int get _servings => _recipe.servings < 1 ? 1 : _recipe.servings;

  String get _logDate {
    final selected = widget.date?.trim();
    if (selected != null && selected.isNotEmpty) return selected;
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  bool get _loggingToToday {
    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    return _logDate == today;
  }

  Map<String, double> get _totals {
    double cal = 0, prot = 0, carb = 0, fat = 0, weight = 0;
    if (_lines.isNotEmpty) {
      for (final line in _lines) {
        if (!line.countsTowardNutrition) continue;
        weight += line.amountGrams;
        if (line.matchType == IngredientMatchType.inventory &&
            line.linkedFood != null) {
          final food = line.linkedFood!;
          cal += food.calories * line.amountGrams / 100;
          prot += food.protein * line.amountGrams / 100;
          carb += food.carbs * line.amountGrams / 100;
          fat += food.fat * line.amountGrams / 100;
        } else if (line.matchType == IngredientMatchType.estimated &&
            line.estimate != null) {
          final estimate = line.estimate!;
          cal += estimate.calories * line.amountGrams / 100;
          prot += estimate.protein * line.amountGrams / 100;
          carb += estimate.carbs * line.amountGrams / 100;
          fat += estimate.fat * line.amountGrams / 100;
        }
      }
    } else {
      for (final c in _components) {
        weight += c.amount;
        cal += c.food.calories * c.amount / 100;
        prot += c.food.protein * c.amount / 100;
        carb += c.food.carbs * c.amount / 100;
        fat += c.food.fat * c.amount / 100;
      }
    }
    return {
      'cal': cal,
      'prot': prot,
      'carb': carb,
      'fat': fat,
      'weight': weight,
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final recipe = _recipe;

    return Scaffold(
      appBar: PageAppBar(
        title: recipe.name.isNotEmpty ? recipe.name : 'Imported recipe',
        subtitle: '${recipe.totalTimeMinutes} min · '
            '${_capitalize(recipe.difficulty)}',
        actions: [
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: _openEdit,
          ),
          IconButton(
            tooltip: 'Delete',
            icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AppTheme.pagePadding,
                        AppTheme.space8,
                        AppTheme.pagePadding,
                        AppTheme.space16,
                      ),
                      children: [
                        if (recipe.hasThumbnail) ...[
                          _buildThumbnail(recipe.thumbnailPath!),
                          const SizedBox(height: AppTheme.space12),
                        ],
                        OutlinedButton.icon(
                          onPressed: _openOriginal,
                          icon: const Icon(Icons.open_in_new_rounded, size: 18),
                          label: const Text('Open original video'),
                        ),
                        const SizedBox(height: AppTheme.space16),
                        _buildNutritionCard(),
                        if (recipe.description.trim().isNotEmpty) ...[
                          const SizedBox(height: AppTheme.space16),
                          Text(
                            recipe.description.trim(),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  height: 1.4,
                                ),
                          ),
                        ],
                        const SizedBox(height: AppTheme.space24),
                        _buildIngredients(),
                        const SizedBox(height: AppTheme.space24),
                        _buildInstructions(),
                      ],
                    ),
                  ),
                  _buildLogBar(),
                ],
              ),
      ),
    );
  }

  Widget _buildThumbnail(String path) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Image.file(
          File(path),
          fit: BoxFit.cover,
          errorBuilder: (context, _, __) => Container(
            color: scheme.surfaceContainerHigh,
            child: Center(
              child: Icon(Icons.image_not_supported_rounded,
                  color: scheme.onSurfaceVariant),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNutritionCard() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final totals = _totals;
    final servings = _servings;
    final calPer = totals['cal']! / servings;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                fmtNum(calPer),
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'kcal / serving',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space16),
          Row(
            children: [
              Expanded(
                child: _macroPill(
                    'Protein', totals['prot']! / servings, scheme.primary),
              ),
              const SizedBox(width: AppTheme.space8),
              Expanded(
                child: _macroPill(
                    'Carbs', totals['carb']! / servings, scheme.tertiary),
              ),
              const SizedBox(width: AppTheme.space8),
              Expanded(
                child: _macroPill(
                    'Fat', totals['fat']! / servings, scheme.secondary),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space8),
          Text(
            'Whole recipe: ${fmtNum(totals['cal']!)} kcal · '
            '${fmtNum(totals['prot']!)}P · ${fmtNum(totals['carb']!)}C · '
            '${fmtNum(totals['fat']!)}F · makes $servings',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIngredients() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final count = _lines.isNotEmpty ? _lines.length : _components.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Mark as you cook', style: theme.textTheme.titleMedium),
            const SizedBox(width: AppTheme.space8),
            Text(
              '$count',
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.space12),
        if (count == 0)
          Text(
            'No ingredients saved for this recipe.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          )
        else if (_lines.isNotEmpty)
          ..._lines.asMap().entries.map((entry) {
            final index = entry.key;
            final line = entry.value;
            return _cookAlongRow(
              index: index,
              title: line.amountGrams > 0
                  ? '${line.parsedName} — ${fmtNum(line.amountGrams)} ${line.unit}'
                  : line.parsedName,
              subtitle: _lineSubtitle(line),
              calories: _lineCalories(line),
            );
          })
        else
          ..._components.asMap().entries.map((entry) {
            final index = entry.key;
            final c = entry.value;
            return _cookAlongRow(
              index: index,
              title: '${c.food.name} — ${fmtNum(c.amount)} ${c.food.unit}',
              subtitle: 'using ${c.food.name}',
              calories: c.food.calories * c.amount / 100,
            );
          }),
      ],
    );
  }

  String? _lineSubtitle(ImportedIngredientLine line) {
    switch (line.matchType) {
      case IngredientMatchType.inventory:
        final name = line.linkedFood?.name;
        return name == null || name.isEmpty ? null : 'using $name';
      case IngredientMatchType.estimated:
        return 'estimated';
      case IngredientMatchType.skipped:
        return 'skipped';
      case IngredientMatchType.spice:
        return 'spice · not counted';
    }
  }

  double? _lineCalories(ImportedIngredientLine line) {
    if (!line.countsTowardNutrition) return null;
    if (line.matchType == IngredientMatchType.inventory &&
        line.linkedFood != null) {
      return line.linkedFood!.calories * line.amountGrams / 100;
    }
    if (line.matchType == IngredientMatchType.estimated &&
        line.estimate != null) {
      return line.estimate!.calories * line.amountGrams / 100;
    }
    return null;
  }

  Widget _cookAlongRow({
    required int index,
    required String title,
    String? subtitle,
    double? calories,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final checked = _checked.contains(index);
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      onTap: () => setState(() {
        if (checked) {
          _checked.remove(index);
        } else {
          _checked.add(index);
        }
      }),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              checked
                  ? Icons.check_box_rounded
                  : Icons.check_box_outline_blank_rounded,
              size: 22,
              color: checked ? scheme.primary : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppTheme.space8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      decoration: checked ? TextDecoration.lineThrough : null,
                      color: checked
                          ? scheme.onSurfaceVariant
                          : scheme.onSurface,
                    ),
                  ),
                  if (subtitle != null && subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            if (calories != null)
              Text(
                '${fmtNum(calories)} kcal',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructions() {
    final recipe = _recipe;
    if (recipe.instructions.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Instructions', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppTheme.space12),
        ...recipe.instructions.asMap().entries.map((entry) {
          final index = entry.key;
          final text = entry.value.trim().replaceFirst(
                RegExp(r'^(step\s*)?\d+[.:]?\s*', caseSensitive: false),
                '',
              );
          return Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.space20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.space12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      text,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildLogBar() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final servings = double.tryParse(_servingsController.text.trim());
    final valid = servings != null && servings > 0;
    final perServingCal = _totals['cal']! / _servings;
    final previewCal = valid ? perServingCal * servings : null;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppTheme.pagePadding,
        AppTheme.space12,
        AppTheme.pagePadding,
        AppTheme.space12,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: TextField(
              controller: _servingsController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'Servings',
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: AppTheme.space12),
          Expanded(
            child: Text(
              previewCal != null ? '${fmtNum(previewCal)} kcal' : '—',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color:
                    previewCal != null ? scheme.onSurface : scheme.onSurfaceVariant,
              ),
            ),
          ),
          FilledButton.icon(
            onPressed: (_isLogging || !valid || _food == null) ? null : _log,
            icon: _isLogging
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(scheme.onPrimary),
                    ),
                  )
                : const Icon(Icons.add_rounded, size: 18),
            label: Text(
              _isLogging
                  ? 'Logging…'
                  : _loggingToToday
                      ? 'Add to today'
                      : 'Add to selected day',
            ),
          ),
        ],
      ),
    );
  }

  Widget _macroPill(String label, double value, Color color) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppTheme.space12,
        horizontal: AppTheme.space8,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Column(
        children: [
          Text(
            '${fmtNum(value)}g',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  Future<void> _openOriginal() async {
    final uri = Uri.tryParse(_recipe.sourceUrl);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the link.')),
        );
      }
    }
  }

  Future<void> _log() async {
    final food = _food;
    final servings = double.tryParse(_servingsController.text.trim());
    if (food == null || servings == null || servings <= 0) return;

    setState(() => _isLogging = true);
    try {
      final portionSize =
          food.defaultPortionSize > 0 ? food.defaultPortionSize : 100.0;
      final amount = portionSize * servings;
      final entry = LogEntry(
        foodId: food.id!,
        amount: amount,
        date: _logDate,
        portions: servings,
      );

      await _logService.insertLogEntry(entry);
      if (!mounted) return;

      await FastingPrompt.showIfNeeded(
        context,
        loggedAt: entry.loggedAt,
        mealName: _recipe.name,
      );
      if (!mounted) return;

      setState(() => _isLogging = false);
      AlertHelper.showSuccessAlert(
        context,
        title: 'Recipe logged',
        message: _loggingToToday
            ? '$servings serving(s) of ${_recipe.name} added to today.'
            : '$servings serving(s) of ${_recipe.name} added to $_logDate.',
        actionButtonText: 'View Log',
        onActionPressed: () {
          Navigator.of(context).pop();
          Navigator.of(context).popUntil((route) => route.isFirst);
        },
      );
      _servingsController.text = '1';
    } catch (e) {
      if (mounted) {
        setState(() => _isLogging = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to log recipe: $e')),
        );
      }
    }
  }

  Future<void> _openEdit() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecipeImportScreen(
          sharedUrl: _recipe.sourceUrl,
          existing: _recipe,
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _loading = true);
    await _load();
  }

  Future<void> _confirmDelete() async {
    final confirm =
        await AlertHelper.showDeleteConfirmation(context, _recipe.name);
    if (!confirm) return;
    try {
      await ImportedRecipeService.deleteByFoodId(_recipe.foodId);
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recipe deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete recipe: $e')),
        );
      }
    }
  }
}
