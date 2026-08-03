import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/food.dart';
import '../models/imported_recipe.dart';
import '../models/parsed_recipe.dart';
import '../services/food_service.dart';
import '../services/imported_recipe_service.dart';
import '../services/inventory_matcher_service.dart';
import '../services/recipe_import_service.dart';
import '../services/video_resolvers/video_resolver.dart';
import '../theme/app_theme.dart';
import '../utils/num_format.dart';
import '../utils/spice_list.dart';
import '../widgets/recipe_video_player.dart';
import '../widgets/ui_kit.dart';
import 'imported_recipe_detail_screen.dart';
import 'settings_screen.dart';

enum _Phase { working, error, ready }

/// One editable ingredient row on the review screen: the parsed ingredient, the
/// inventory candidates it could map to, and the user's current selection.
class _IngredientRow {
  final ParsedIngredient parsed;
  final bool isSpice;
  final List<Food> options; // candidate inventory foods (dropdown)
  Food? selected; // null = skipped / not counted
  final TextEditingController amountController;

  _IngredientRow({
    required this.parsed,
    required this.isSpice,
    required this.options,
    required this.selected,
    required this.amountController,
  });

  double get amount => double.tryParse(amountController.text.trim()) ?? 0;
}

class RecipeImportScreen extends StatefulWidget {
  const RecipeImportScreen({super.key, required this.sharedUrl});

  final String sharedUrl;

  @override
  State<RecipeImportScreen> createState() => _RecipeImportScreenState();
}

class _RecipeImportScreenState extends State<RecipeImportScreen> {
  _Phase _phase = _Phase.working;
  String _status = 'Reading the shared link…';
  String _error = '';

  ResolvedVideo? _resolved;
  ParsedRecipe? _parsed;
  List<Food> _allFoods = [];

  final _nameController = TextEditingController();
  final _servingsController = TextEditingController(text: '1');
  final List<_IngredientRow> _rows = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _servingsController.dispose();
    for (final row in _rows) {
      row.amountController.dispose();
    }
    super.dispose();
  }

  Future<void> _run() async {
    setState(() {
      _phase = _Phase.working;
      _status = 'Reading the shared link…';
    });

    try {
      final resolved = await RecipeImportService.resolveLink(
        widget.sharedUrl,
        onProgress: (s) {
          if (mounted) setState(() => _status = s);
        },
      );
      _resolved = resolved;

      if (mounted) setState(() => _status = 'Understanding the recipe…');
      final parsed = await RecipeImportService.parseRecipe(resolved);
      _parsed = parsed;

      if (mounted) setState(() => _status = 'Matching your inventory…');
      _allFoods = await FoodService().getSimpleFoods();
      final matcher = InventoryMatcher(_allFoods);

      _buildRows(parsed, matcher);
      await _resolveUnmatchedWithAi(matcher);

      if (mounted) {
        _nameController.text = parsed.name;
        _servingsController.text = parsed.servings.toString();
        setState(() => _phase = _Phase.ready);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _phase = _Phase.error;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  void _buildRows(ParsedRecipe parsed, InventoryMatcher matcher) {
    _rows.clear();
    for (final ing in parsed.ingredients) {
      final isSpice = ing.isSpice || SpiceList.isSpice(ing.name);
      final match = isSpice
          ? IngredientMatch(ing.name, const [])
          : matcher.match(ing.name);

      final options = match.candidates.map((c) => c.food).toList();
      Food? selected;
      if (!isSpice) {
        // Pre-select for strong/weak matches; leave 'none' for the AI pass.
        if (match.confidence == MatchConfidence.strong ||
            match.confidence == MatchConfidence.weak) {
          selected = match.best?.food;
        }
      }

      final amountText = ing.amountGrams > 0 ? _trim(ing.amountGrams) : '';
      final controller = TextEditingController(text: amountText);
      controller.addListener(() {
        if (mounted) setState(() {});
      });

      _rows.add(
        _IngredientRow(
          parsed: ing,
          isSpice: isSpice,
          options: options,
          selected: selected,
          amountController: controller,
        ),
      );
    }
  }

  Future<void> _resolveUnmatchedWithAi(InventoryMatcher matcher) async {
    // Only ingredients with NO confident match get a (pruned) AI shortlist.
    final unmatched = <String, List<String>>{};
    for (final row in _rows) {
      if (row.isSpice || row.selected != null) continue;
      if (row.options.isNotEmpty) {
        unmatched[row.parsed.name] =
            row.options.map((f) => f.name).toList();
      }
    }
    if (unmatched.isEmpty) return;

    final picks = await RecipeImportService.suggestNearest(unmatched);
    if (picks.isEmpty) return;

    for (final row in _rows) {
      if (row.isSpice || row.selected != null) continue;
      final pickName = picks[row.parsed.name];
      if (pickName == null) continue;
      final food = _findFoodByName(row.options, pickName) ??
          _findFoodByName(_allFoods, pickName);
      if (food != null) {
        if (!row.options.any((f) => identical(f, food))) {
          row.options.insert(0, food);
        }
        row.selected = food;
      }
    }
  }

  Food? _findFoodByName(List<Food> pool, String name) {
    final lower = name.toLowerCase().trim();
    for (final f in pool) {
      if (f.name.toLowerCase().trim() == lower) return f;
    }
    return null;
  }

  // ---- Nutrition ------------------------------------------------------------

  Map<String, double> get _totals {
    double cal = 0, prot = 0, carb = 0, fat = 0;
    for (final row in _rows) {
      final food = row.selected;
      if (food == null || row.isSpice) continue;
      final amount = row.amount;
      cal += food.calories * amount / 100;
      prot += food.protein * amount / 100;
      carb += food.carbs * amount / 100;
      fat += food.fat * amount / 100;
    }
    return {'cal': cal, 'prot': prot, 'carb': carb, 'fat': fat};
  }

  int get _servings {
    final v = int.tryParse(_servingsController.text.trim()) ?? 1;
    return v < 1 ? 1 : v;
  }

  bool get _canSave {
    if (_nameController.text.trim().isEmpty) return false;
    return _rows.any(
      (r) => !r.isSpice && r.selected != null && r.amount > 0,
    );
  }

  String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  // ---- Build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PageAppBar(
        title: 'Import recipe',
        subtitle: switch (_phase) {
          _Phase.working => 'From a shared link',
          _Phase.error => 'Something went wrong',
          _Phase.ready => 'Review and save',
        },
      ),
      body: SafeArea(top: false, child: _buildBody()),
      bottomNavigationBar: _phase == _Phase.ready ? _buildSaveBar() : null,
    );
  }

  Widget _buildBody() {
    switch (_phase) {
      case _Phase.working:
        return _buildWorking();
      case _Phase.error:
        return _buildError();
      case _Phase.ready:
        return _buildReview();
    }
  }

  Widget _buildWorking() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppTheme.space20),
            Text(
              _status,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppTheme.space8),
            Text(
              'Downloading the video and reading the recipe. This can take a '
              'moment.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    final scheme = Theme.of(context).colorScheme;
    final needsKey = _error.toLowerCase().contains('api key');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 40, color: scheme.error),
            const SizedBox(height: AppTheme.space16),
            Text(
              needsKey ? 'AI key needed' : 'Could not import',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.space8),
            Text(
              _error,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: AppTheme.space20),
            if (needsKey)
              FilledButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SettingsScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.key_rounded),
                label: const Text('Open settings'),
              )
            else
              FilledButton.icon(
                onPressed: _run,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            const SizedBox(height: AppTheme.space8),
            OutlinedButton.icon(
              onPressed: _openOriginal,
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Open original link'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReview() {
    final resolved = _resolved;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.pagePadding,
        AppTheme.space8,
        AppTheme.pagePadding,
        AppTheme.space24,
      ),
      children: [
        if (resolved?.videoLocalPath != null) ...[
          RecipeVideoPlayer(videoPath: resolved!.videoLocalPath!),
          const SizedBox(height: AppTheme.space12),
        ] else ...[
          _buildNoVideoNotice(),
          const SizedBox(height: AppTheme.space12),
        ],
        OutlinedButton.icon(
          onPressed: _openOriginal,
          icon: const Icon(Icons.open_in_new_rounded, size: 18),
          label: const Text('Open original video'),
        ),
        const SizedBox(height: AppTheme.space16),
        TextField(
          controller: _nameController,
          onChanged: (_) => setState(() {}),
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Recipe name',
            prefixIcon: Icon(Icons.restaurant_menu_rounded),
          ),
        ),
        const SizedBox(height: AppTheme.space16),
        _buildNutritionSummary(),
        const SizedBox(height: AppTheme.space20),
        _buildServingsRow(),
        const SizedBox(height: AppTheme.space20),
        SectionHeader(
          title: 'Ingredients',
          action: Text(
            '${_rows.where((r) => !r.isSpice).length} to match',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
        Text(
          'Pick which inventory item each ingredient uses. Spices are assumed on '
          'hand and are not counted.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: AppTheme.space12),
        ..._rows.map(_buildIngredientRow),
        const SizedBox(height: AppTheme.space20),
        _buildInstructions(),
      ],
    );
  }

  Widget _buildNoVideoNotice() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppTheme.space12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: scheme.onSurfaceVariant),
          const SizedBox(width: AppTheme.space12),
          Expanded(
            child: Text(
              'The video could not be downloaded, but the recipe was read from '
              'the caption. Use the button below to open the original.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionSummary() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final totals = _totals;
    final servings = _servings;
    final perCal = totals['cal']! / servings;

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
                'Per serving (live)',
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
                    fmtNum(perCal),
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
            ],
          ),
        ),
        const SizedBox(height: AppTheme.space8),
        Row(
          children: [
            Expanded(
              child: _macroChip(
                'Protein',
                totals['prot']! / servings,
                scheme.primary,
              ),
            ),
            const SizedBox(width: AppTheme.space8),
            Expanded(
              child: _macroChip(
                'Carbs',
                totals['carb']! / servings,
                scheme.tertiary,
              ),
            ),
            const SizedBox(width: AppTheme.space8),
            Expanded(
              child: _macroChip('Fat', totals['fat']! / servings, scheme.secondary),
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

  Widget _buildServingsRow() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SectionCard(
      child: Row(
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
          SizedBox(
            width: 72,
            child: TextField(
              controller: _servingsController,
              onChanged: (_) => setState(() {}),
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(2),
              ],
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientRow(_IngredientRow row) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (row.isSpice) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppTheme.space8),
        child: SectionCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.space12,
            vertical: AppTheme.space12,
          ),
          child: Row(
            children: [
              Icon(Icons.grain_rounded, size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: AppTheme.space8),
              Expanded(
                child: Text(
                  row.parsed.display,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              Text(
                'Spice · not counted',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final selected = row.selected;
    final unit = selected?.unit ?? row.parsed.unit;
    final cal = selected != null ? selected.calories * row.amount / 100 : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space8),
      child: SectionCard(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.space12,
          AppTheme.space12,
          AppTheme.space12,
          AppTheme.space12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              row.parsed.display,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.space8),
            Row(
              children: [
                Expanded(child: _buildSelector(row)),
                const SizedBox(width: AppTheme.space8),
                SizedBox(
                  width: 96,
                  child: TextField(
                    controller: row.amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
                    ],
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: 'Amount',
                      suffixText: unit,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.space12,
                        vertical: AppTheme.space12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (selected == null)
                  Text(
                    'Not in inventory — pick a match or skip',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.error,
                    ),
                  )
                else
                  Text(
                    '${fmtNum(selected.calories)} kcal / 100 $unit',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                if (selected != null && row.amount > 0)
                  Text(
                    '${fmtNum(cal)} kcal',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelector(_IngredientRow row) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return DropdownButtonFormField<Food?>(
      value: row.selected,
      isExpanded: true,
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppTheme.space12,
          vertical: AppTheme.space12,
        ),
      ),
      hint: const Text('Select item'),
      items: [
        ...row.options.map(
          (food) => DropdownMenuItem<Food?>(
            value: food,
            child: Text(food.name, overflow: TextOverflow.ellipsis),
          ),
        ),
        const DropdownMenuItem<Food?>(
          value: null,
          child: Text('Skip (not counted)'),
        ),
      ],
      selectedItemBuilder: (context) => [
        ...row.options.map(
          (food) => Text(food.name, overflow: TextOverflow.ellipsis),
        ),
        Text(
          'Skip (not counted)',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
      ],
      onChanged: (value) => setState(() => row.selected = value),
    );
  }

  Widget _buildInstructions() {
    final parsed = _parsed;
    if (parsed == null || parsed.instructions.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Instructions', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppTheme.space12),
        ...parsed.instructions.asMap().entries.map((entry) {
          final index = entry.key;
          final text =
              entry.value.trim().replaceFirst(RegExp(r'^(step\s*)?\d+[.:]?\s*',
                  caseSensitive: false), '');
          return Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.space16),
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

  Widget _buildSaveBar() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final totals = _totals;

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
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${fmtNum(totals['cal']!)} kcal total · $_servings servings',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: (_saving || !_canSave) ? null : _save,
              icon: _saving
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(scheme.onPrimary),
                      ),
                    )
                  : const Icon(Icons.save_rounded, size: 18),
              label: Text(_saving ? 'Saving…' : 'Save recipe'),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Actions --------------------------------------------------------------

  Future<void> _openOriginal() async {
    final uri = Uri.tryParse(widget.sharedUrl);
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

  Future<void> _save() async {
    final parsed = _parsed;
    final resolved = _resolved;
    if (parsed == null || resolved == null) return;

    final components = <ImportedComponent>[
      for (final row in _rows)
        if (!row.isSpice && row.selected != null && row.amount > 0)
          ImportedComponent(food: row.selected!, amount: row.amount),
    ];

    if (components.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Match at least one ingredient to an inventory item.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final meta = ImportedRecipe(
        foodId: 0, // set on insert
        platform: resolved.platform.name,
        sourceUrl: resolved.sourceUrl,
        videoPath: resolved.videoLocalPath,
        thumbnailPath: resolved.thumbnailPath,
        description: parsed.description,
        instructions: parsed.instructions,
        servings: _servings,
        prepTimeMinutes: parsed.prepTimeMinutes,
        cookTimeMinutes: parsed.cookTimeMinutes,
        difficulty: parsed.difficulty,
        tags: parsed.tags,
      );

      final foodId = await ImportedRecipeService.saveImportedRecipe(
        name: _nameController.text.trim(),
        isLiquid: false,
        components: components,
        meta: meta,
      );

      final saved = await ImportedRecipeService.getByFoodId(foodId);
      if (!mounted) return;

      if (saved != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ImportedRecipeDetailScreen(recipe: saved),
          ),
        );
      } else {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save recipe: $e')),
        );
      }
    }
  }
}
