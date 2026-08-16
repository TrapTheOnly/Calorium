import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/food.dart';
import '../models/imported_ingredient_line.dart';
import '../models/imported_recipe.dart';
import '../models/parsed_recipe.dart';
import '../services/food_service.dart';
import '../services/imported_recipe_service.dart';
import '../services/ingredient_estimate_service.dart';
import '../services/inventory_matcher_service.dart';
import '../services/recipe_import_service.dart';
import '../services/video_resolvers/video_resolver.dart';
import '../theme/app_theme.dart';
import '../utils/num_format.dart';
import '../utils/spice_list.dart';
import '../widgets/custom_alert.dart';
import '../widgets/ui_kit.dart';
import 'imported_recipe_detail_screen.dart';
import 'settings_screen.dart';

enum _Phase { working, error, ready }

/// One editable ingredient row on the review screen: the parsed ingredient, the
/// inventory candidates it could map to, and the user's current selection.
class _IngredientRow {
  final ParsedIngredient parsed;
  bool isSpice;
  final List<Food> options;
  Food? selected;
  EstimatedMacros? estimate;
  bool suggested = false;
  bool estimating = false;
  final TextEditingController amountController;

  _IngredientRow({
    required this.parsed,
    required this.isSpice,
    required this.options,
    required this.selected,
    required this.amountController,
    this.estimate,
  });

  double get amount => double.tryParse(amountController.text.trim()) ?? 0;

  IngredientMatchType get matchType {
    if (isSpice) return IngredientMatchType.spice;
    if (selected != null) return IngredientMatchType.inventory;
    if (estimate != null) return IngredientMatchType.estimated;
    return IngredientMatchType.skipped;
  }

  bool get countsTowardNutrition =>
      !isSpice &&
      amount > 0 &&
      (selected != null || estimate != null);
}

class RecipeImportScreen extends StatefulWidget {
  const RecipeImportScreen({
    super.key,
    required this.sharedUrl,
    this.existing,
    this.pastedCaption,
  });

  final String sharedUrl;
  final ImportedRecipe? existing;
  final String? pastedCaption;

  @override
  State<RecipeImportScreen> createState() => _RecipeImportScreenState();
}

class _RecipeImportScreenState extends State<RecipeImportScreen> {
  _Phase _phase = _Phase.working;
  String _status = 'Reading the caption and thumbnail…';
  String _error = '';

  ResolvedVideo? _resolved;
  ParsedRecipe? _parsed;
  List<Food> _allFoods = [];

  final _nameController = TextEditingController();
  final _servingsController = TextEditingController(text: '1');
  final _instructionsController = TextEditingController();
  final _captionPasteController = TextEditingController();
  final List<_IngredientRow> _rows = [];
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final pasted = widget.pastedCaption?.trim();
    if (pasted != null && pasted.isNotEmpty) {
      _captionPasteController.text = pasted;
    }
    _run();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _servingsController.dispose();
    _instructionsController.dispose();
    _captionPasteController.dispose();
    for (final row in _rows) {
      row.amountController.dispose();
    }
    super.dispose();
  }

  Future<void> _run({String? captionOverride}) async {
    setState(() {
      _phase = _Phase.working;
      _status = _isEditing
          ? 'Loading recipe…'
          : 'Reading the caption and thumbnail…';
      _error = '';
    });

    try {
      if (_isEditing) {
        await _loadExisting();
        return;
      }
      await _importFromLink(captionOverride: captionOverride);
    } catch (e) {
      if (mounted) {
        setState(() {
          _phase = _Phase.error;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _importFromLink({String? captionOverride}) async {
    final pasted = (captionOverride ?? widget.pastedCaption)?.trim();
    final reuseResolved = _resolved != null &&
        pasted != null &&
        pasted.isNotEmpty;

    final ResolvedVideo resolved;
    if (reuseResolved) {
      resolved = _resolved!;
    } else {
      final fetched = await RecipeImportService.resolveLink(
        widget.sharedUrl,
        onProgress: (s) {
          if (mounted) setState(() => _status = _friendlyStatus(s));
        },
      );
      resolved = fetched;
      _resolved = fetched;
    }

    if (mounted) setState(() => _status = 'Understanding the recipe…');

    final override = (!resolved.hasUsableText &&
            pasted != null &&
            pasted.isNotEmpty)
        ? pasted
        : (captionOverride?.trim().isNotEmpty == true
            ? captionOverride!.trim()
            : null);

    final parsed = await RecipeImportService.parseRecipe(
      resolved,
      captionOverride: override,
    );
    _parsed = parsed;

    if (mounted) setState(() => _status = 'Matching your inventory…');
    _allFoods = await FoodService().getSimpleFoods();
    final matcher = InventoryMatcher(_allFoods);

    _buildRows(parsed, matcher);
    try {
      await _resolveUnmatchedWithAi(matcher);
    } catch (_) {
      // Review still opens if the optional AI shortlist fails.
    }

    if (!mounted) return;
    _nameController.text = parsed.name;
    _servingsController.text = parsed.servings.toString();
    _instructionsController.text = parsed.instructions.join('\n');
    setState(() => _phase = _Phase.ready);
  }

  Future<void> _loadExisting() async {
    final existing = widget.existing!;
    _allFoods = await FoodService().getSimpleFoods();
    final matcher = InventoryMatcher(_allFoods);

    var lines = await ImportedRecipeService.getLines(existing.foodId);
    if (lines.isEmpty) {
      final components =
          await ImportedRecipeService.getComponents(existing.foodId);
      lines = [
        for (final c in components)
          ImportedIngredientLine(
            parsedName: c.food.name,
            amountGrams: c.amount,
            unit: c.food.unit,
            matchType: IngredientMatchType.inventory,
            linkedFood: c.food,
          ),
      ];
    }

    _resolved = ResolvedVideo(
      platform: _platformFrom(existing.platform),
      sourceUrl: existing.sourceUrl.isNotEmpty
          ? existing.sourceUrl
          : widget.sharedUrl,
      caption: existing.description,
      videoLocalPath: existing.videoPath,
      thumbnailPath: existing.thumbnailPath,
    );

    final ingredients = [
      for (final line in lines) _parsedFromLine(line),
    ];
    _parsed = ParsedRecipe(
      isRecipe: true,
      name: existing.name,
      description: existing.description,
      servings: existing.servings,
      prepTimeMinutes: existing.prepTimeMinutes,
      cookTimeMinutes: existing.cookTimeMinutes,
      difficulty: existing.difficulty,
      tags: existing.tags,
      ingredients: ingredients,
      instructions: existing.instructions,
    );

    _buildRowsFromLines(lines, matcher);

    if (!mounted) return;
    _nameController.text = existing.name;
    _servingsController.text = existing.servings.toString();
    _instructionsController.text = existing.instructions.join('\n');
    setState(() => _phase = _Phase.ready);
  }

  ParsedIngredient _parsedFromLine(ImportedIngredientLine line) {
    return ParsedIngredient(
      name: line.parsedName,
      amountText: line.amountText,
      amountGrams: line.amountGrams,
      unit: line.unit,
      isSpice: line.isSpice,
      notes: line.notes,
    );
  }

  VideoPlatform _platformFrom(String name) {
    return VideoPlatform.values.firstWhere(
      (p) => p.name == name,
      orElse: () => VideoPlatform.unknown,
    );
  }

  String _friendlyStatus(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('download') && lower.contains('video')) {
      return 'Reading the caption and thumbnail…';
    }
    return raw;
  }

  void _disposeRows() {
    for (final row in _rows) {
      row.amountController.dispose();
    }
    _rows.clear();
  }

  TextEditingController _amountController(String text) {
    final controller = TextEditingController(text: text);
    controller.addListener(() {
      if (mounted) setState(() {});
    });
    return controller;
  }

  void _buildRows(ParsedRecipe parsed, InventoryMatcher matcher) {
    _disposeRows();
    for (final ing in parsed.ingredients) {
      final isSpice = ing.isSpice || SpiceList.isSpice(ing.name);
      final match = isSpice
          ? IngredientMatch(ing.name, const [])
          : matcher.match(ing.name);

      final options = match.candidates.map((c) => c.food).toList();
      Food? selected;
      if (!isSpice && match.confidence == MatchConfidence.strong) {
        selected = match.best?.food;
      }

      final amountText = ing.amountGrams > 0 ? _trim(ing.amountGrams) : '';
      _rows.add(
        _IngredientRow(
          parsed: ing,
          isSpice: isSpice,
          options: options,
          selected: selected,
          amountController: _amountController(amountText),
        ),
      );
    }
  }

  void _buildRowsFromLines(
    List<ImportedIngredientLine> lines,
    InventoryMatcher matcher,
  ) {
    _disposeRows();
    for (final line in lines) {
      final parsed = _parsedFromLine(line);
      final isSpice = line.matchType == IngredientMatchType.spice ||
          line.isSpice;
      final match = matcher.match(line.parsedName);
      final options = match.candidates.map((c) => c.food).toList();

      Food? selected;
      EstimatedMacros? estimate = line.estimate;
      if (line.matchType == IngredientMatchType.inventory &&
          line.linkedFood != null &&
          line.linkedFood!.type != 'estimate') {
        final food = line.linkedFood!;
        selected = food;
        _ensureOption(options, food);
      } else if (line.matchType == IngredientMatchType.estimated) {
        estimate = line.estimate;
        selected = null;
      }

      final amountText =
          line.amountGrams > 0 ? _trim(line.amountGrams) : '';
      _rows.add(
        _IngredientRow(
          parsed: parsed,
          isSpice: isSpice,
          options: options,
          selected: selected,
          estimate: estimate,
          amountController: _amountController(amountText),
        ),
      );
    }
  }

  void _ensureOption(List<Food> options, Food food) {
    if (!options.any((f) => f.id != null && f.id == food.id)) {
      options.insert(0, food);
    }
  }

  void _fillOptionsIfNeeded(_IngredientRow row) {
    if (row.options.isNotEmpty || _allFoods.isEmpty) return;
    final match = InventoryMatcher(_allFoods).match(row.parsed.name);
    row.options.addAll(match.candidates.map((c) => c.food));
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
      if (food == null) continue;
      _ensureOption(row.options, food);
      // Keep AI fill for the options list. Do not treat a suggestion as
      // confirmed unless the local matcher already rates it strong and the
      // pick is an exact inventory name.
      final rematch = matcher.match(row.parsed.name);
      final exactStrong = rematch.confidence == MatchConfidence.strong &&
          rematch.best != null &&
          rematch.best!.food.name.toLowerCase().trim() ==
              food.name.toLowerCase().trim();
      if (exactStrong) {
        row.selected = food;
      } else {
        row.suggested = true;
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

  Food? _dropdownValue(_IngredientRow row) {
    final selected = row.selected;
    if (selected == null) return null;
    for (final food in row.options) {
      if (food.id != null && food.id == selected.id) return food;
    }
    return selected;
  }

  // ---- Nutrition ------------------------------------------------------------

  Map<String, double> get _totals {
    double cal = 0, prot = 0, carb = 0, fat = 0;
    for (final row in _rows) {
      if (!row.countsTowardNutrition) continue;
      final amount = row.amount;
      if (row.selected != null) {
        final food = row.selected!;
        cal += food.calories * amount / 100;
        prot += food.protein * amount / 100;
        carb += food.carbs * amount / 100;
        fat += food.fat * amount / 100;
      } else if (row.estimate != null) {
        final estimate = row.estimate!;
        cal += estimate.calories * amount / 100;
        prot += estimate.protein * amount / 100;
        carb += estimate.carbs * amount / 100;
        fat += estimate.fat * amount / 100;
      }
    }
    return {'cal': cal, 'prot': prot, 'carb': carb, 'fat': fat};
  }

  int get _servings {
    final v = int.tryParse(_servingsController.text.trim()) ?? 1;
    return v < 1 ? 1 : v;
  }

  List<String> get _instructionLines => _instructionsController.text
      .split(RegExp(r'\n+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  int get _unmatchedCount => _rows
      .where(
        (r) =>
            !r.isSpice &&
            r.selected == null &&
            r.estimate == null,
      )
      .length;

  bool get _canSave {
    if (_nameController.text.trim().isEmpty) return false;
    return _rows.any((r) => r.countsTowardNutrition);
  }

  String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  // ---- Build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PageAppBar(
        title: _isEditing ? 'Edit recipe' : 'Import recipe',
        subtitle: switch (_phase) {
          _Phase.working =>
            _isEditing ? 'Loading saved mappings' : 'From a shared link',
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
              'Reading the caption and thumbnail. This can take a moment.',
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
      child: SingleChildScrollView(
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
            if (!needsKey) ...[
              const SizedBox(height: AppTheme.space20),
              TextField(
                controller: _captionPasteController,
                minLines: 4,
                maxLines: 8,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Paste the recipe caption',
                  hintText:
                      'Ingredients and steps from the video description',
                  alignLabelWithHint: true,
                ),
              ),
            ],
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
                onPressed: () {
                  final pasted = _captionPasteController.text.trim();
                  _run(captionOverride: pasted.isEmpty ? null : pasted);
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
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
        if (resolved?.thumbnailPath != null) ...[
          _buildThumbnail(resolved!.thumbnailPath!),
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
            _unmatchedCount == 0
                ? '${_rows.where((r) => !r.isSpice).length} matched'
                : '$_unmatchedCount unmatched',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
        Text(
          'Match each ingredient to inventory, estimate nutrition, or skip. '
          'Spices are not counted unless you choose to include them.',
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
              'No preview image was available, but the recipe was read from '
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

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }

  Widget _buildIngredientRow(_IngredientRow row) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final canToggleSpice = row.parsed.isSpice ||
        SpiceList.isSpice(row.parsed.name) ||
        row.isSpice;

    if (row.isSpice) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppTheme.space8),
        child: SectionCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.space12,
            vertical: AppTheme.space12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.grain_rounded,
                      size: 18, color: scheme.onSurfaceVariant),
                  const SizedBox(width: AppTheme.space8),
                  Expanded(
                    child: Text(
                      row.parsed.name,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  _statusChip('Spice', scheme.onSurfaceVariant),
                ],
              ),
              if (row.parsed.display != row.parsed.name) ...[
                const SizedBox(height: 4),
                Text(
                  row.parsed.display,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(() {
                    row.isSpice = false;
                    row.selected = null;
                    row.estimate = null;
                    _fillOptionsIfNeeded(row);
                  }),
                  child: const Text('Count this ingredient'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final selected = row.selected;
    final unit = selected?.unit ?? row.parsed.unit;
    final cal = _rowCalories(row);

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
            Row(
              children: [
                Expanded(
                  child: Text(
                    row.parsed.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _matchStatusChip(row),
              ],
            ),
            if (row.parsed.display != row.parsed.name) ...[
              const SizedBox(height: 2),
              Text(
                row.parsed.display,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            if (row.suggested && row.selected == null) ...[
              const SizedBox(height: 6),
              _statusChip('Suggested', scheme.secondary),
            ],
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
            const SizedBox(height: 4),
            Wrap(
              spacing: AppTheme.space8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: () => _searchInventory(row),
                  icon: const Icon(Icons.search_rounded, size: 18),
                  label: const Text('Search inventory…'),
                ),
                if (row.selected == null && row.estimate == null)
                  TextButton.icon(
                    onPressed: row.estimating ? null : () => _estimateRow(row),
                    icon: row.estimating
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome_rounded, size: 18),
                    label: Text(
                      row.estimating ? 'Estimating…' : 'Estimate nutrition',
                    ),
                  )
                else if (row.estimate != null && row.selected == null)
                  TextButton(
                    onPressed: () => setState(() => row.estimate = null),
                    child: const Text('Clear estimate'),
                  ),
                if (canToggleSpice)
                  TextButton(
                    onPressed: () => setState(() {
                      row.isSpice = true;
                      row.selected = null;
                      row.estimate = null;
                      row.suggested = false;
                    }),
                    child: const Text('Treat as spice'),
                  ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: _rowHelperText(row, unit)),
                if (cal != null && row.amount > 0)
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

  Widget _matchStatusChip(_IngredientRow row) {
    final scheme = Theme.of(context).colorScheme;
    switch (row.matchType) {
      case IngredientMatchType.inventory:
        return _statusChip('Inventory', scheme.primary);
      case IngredientMatchType.estimated:
        return _statusChip('Estimated', scheme.tertiary);
      case IngredientMatchType.skipped:
        return _statusChip('Skipped', scheme.error);
      case IngredientMatchType.spice:
        return _statusChip('Spice', scheme.onSurfaceVariant);
    }
  }

  Widget _rowHelperText(_IngredientRow row, String unit) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (row.estimate != null && row.selected == null) {
      return Text(
        'Estimated · not in inventory',
        style: theme.textTheme.labelSmall?.copyWith(color: scheme.tertiary),
      );
    }
    if (row.selected == null) {
      return Text(
        'Not in inventory — match, estimate, or skip',
        style: theme.textTheme.labelSmall?.copyWith(color: scheme.error),
      );
    }
    return Text(
      '${fmtNum(row.selected!.calories)} kcal / 100 $unit',
      style: theme.textTheme.labelSmall?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
    );
  }

  double? _rowCalories(_IngredientRow row) {
    if (!row.countsTowardNutrition) return null;
    if (row.selected != null) {
      return row.selected!.calories * row.amount / 100;
    }
    if (row.estimate != null) {
      return row.estimate!.calories * row.amount / 100;
    }
    return null;
  }

  Widget _buildSelector(_IngredientRow row) {
    final scheme = Theme.of(context).colorScheme;
    final value = _dropdownValue(row);

    return DropdownButtonFormField<Food?>(
      value: value,
      isExpanded: true,
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppTheme.space12,
          vertical: AppTheme.space12,
        ),
      ),
      hint: Text(
        row.estimate != null ? 'Estimated' : 'Select item',
      ),
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
          row.estimate != null ? 'Estimated' : 'Skip (not counted)',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
      ],
      onChanged: (next) => setState(() {
        row.selected = next;
        row.estimate = null;
        if (next != null) {
          row.suggested = false;
        }
      }),
    );
  }

  Widget _buildInstructions() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Instructions', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppTheme.space12),
        TextField(
          controller: _instructionsController,
          minLines: 4,
          maxLines: 12,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'One step per line',
            alignLabelWithHint: true,
          ),
        ),
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
              label: Text(_saving
                  ? 'Saving…'
                  : (_isEditing ? 'Save changes' : 'Save recipe')),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Actions --------------------------------------------------------------

  Future<void> _searchInventory(_IngredientRow row) async {
    final food = await showModalBottomSheet<Food>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => const _InventorySearchSheet(),
    );
    if (food == null || !mounted) return;
    setState(() {
      _ensureOption(row.options, food);
      row.selected = row.options.firstWhere(
        (f) => f.id != null && f.id == food.id,
        orElse: () => food,
      );
      row.estimate = null;
      row.suggested = false;
    });
  }

  Future<void> _estimateRow(_IngredientRow row) async {
    setState(() => row.estimating = true);
    try {
      // Matching agent provides IngredientEstimateService.
      final macros = await IngredientEstimateService.estimate(
        row.parsed.name,
        unit: row.parsed.unit,
      );
      if (!mounted) return;
      setState(() {
        row.estimate = macros;
        row.selected = null;
        row.suggested = false;
        row.estimating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => row.estimating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _openOriginal() async {
    final url = _resolved?.sourceUrl ?? widget.sharedUrl;
    final uri = Uri.tryParse(url);
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

  List<ImportedIngredientLine> _buildLines() {
    return [
      for (final row in _rows)
        ImportedIngredientLine(
          parsedName: row.parsed.name,
          amountText: row.parsed.amountText,
          amountGrams: row.amount,
          unit: row.selected?.unit ?? row.parsed.unit,
          isSpice: row.isSpice,
          notes: row.parsed.notes,
          matchType: row.matchType,
          linkedFood: row.selected,
          estimate: row.estimate,
        ),
    ];
  }

  ImportedRecipe _buildMeta({required int foodId}) {
    final parsed = _parsed;
    final resolved = _resolved;
    final existing = widget.existing;
    return (existing ??
            ImportedRecipe(
              foodId: foodId,
              platform: resolved?.platform.name ?? '',
              sourceUrl: resolved?.sourceUrl ?? widget.sharedUrl,
              videoPath: resolved?.videoLocalPath,
              thumbnailPath: resolved?.thumbnailPath,
              description: parsed?.description ?? '',
              instructions: const [],
              servings: _servings,
              prepTimeMinutes: parsed?.prepTimeMinutes ?? 0,
              cookTimeMinutes: parsed?.cookTimeMinutes ?? 0,
              difficulty: parsed?.difficulty ?? 'medium',
              tags: parsed?.tags ?? const [],
            ))
        .copyWith(
          foodId: foodId,
          platform: resolved?.platform.name ?? existing?.platform,
          sourceUrl: resolved?.sourceUrl ??
              (existing?.sourceUrl.isNotEmpty == true
                  ? existing!.sourceUrl
                  : widget.sharedUrl),
          videoPath: resolved?.videoLocalPath ?? existing?.videoPath,
          thumbnailPath: resolved?.thumbnailPath ?? existing?.thumbnailPath,
          description: parsed?.description ?? existing?.description,
          instructions: _instructionLines,
          servings: _servings,
          prepTimeMinutes:
              parsed?.prepTimeMinutes ?? existing?.prepTimeMinutes,
          cookTimeMinutes:
              parsed?.cookTimeMinutes ?? existing?.cookTimeMinutes,
          difficulty: parsed?.difficulty ?? existing?.difficulty,
          tags: parsed?.tags ?? existing?.tags,
        );
  }

  Future<void> _save() async {
    if (!_canSave) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Name the recipe and count at least one ingredient.',
          ),
        ),
      );
      return;
    }

    final unmatched = _unmatchedCount;
    if (unmatched > 0) {
      final confirmed = await AlertHelper.showConfirmationAlert(
        context,
        title: 'Save with unmatched ingredients?',
        message: unmatched == 1
            ? '1 ingredient is still unmatched. It will be saved as skipped '
                'so you can match or estimate it later.'
            : '$unmatched ingredients are still unmatched. They will be saved '
                'as skipped so you can match or estimate them later.',
        confirmButtonText: 'Save anyway',
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() => _saving = true);

    try {
      final lines = _buildLines();
      final existing = widget.existing;
      late final int foodId;

      if (existing != null) {
        foodId = existing.foodId;
        await ImportedRecipeService.updateImportedRecipe(
          foodId: foodId,
          name: _nameController.text.trim(),
          isLiquid: false,
          lines: lines,
          meta: _buildMeta(foodId: foodId),
        );
      } else {
        foodId = await ImportedRecipeService.saveImportedRecipe(
          name: _nameController.text.trim(),
          isLiquid: false,
          lines: lines,
          meta: _buildMeta(foodId: 0),
        );
      }

      final saved = await ImportedRecipeService.getByFoodId(foodId);
      if (!mounted) return;

      if (existing != null) {
        Navigator.pop(context, true);
        return;
      }

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

class _InventorySearchSheet extends StatefulWidget {
  const _InventorySearchSheet();

  @override
  State<_InventorySearchSheet> createState() => _InventorySearchSheetState();
}

class _InventorySearchSheetState extends State<_InventorySearchSheet> {
  final _searchController = TextEditingController();
  final _foodService = FoodService();
  List<Food> _results = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _search('');
    _searchController.addListener(() => _search(_searchController.text));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    final trimmed = query.trim();
    final foods = trimmed.isEmpty
        ? await _foodService.getSimpleFoods()
        : await _foodService.searchSimpleFoods(trimmed);
    if (!mounted) return;
    setState(() {
      _results = foods;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final height = MediaQuery.of(context).size.height * 0.75;

    return SafeArea(
      child: SizedBox(
        height: height,
        child: Padding(
          padding: EdgeInsets.only(
            left: AppTheme.pagePadding,
            right: AppTheme.pagePadding,
            top: AppTheme.space8,
            bottom: MediaQuery.of(context).viewInsets.bottom + AppTheme.space16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Search inventory', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppTheme.space12),
              TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search basics…',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: AppTheme.space12),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _results.isEmpty
                        ? Center(
                            child: Text(
                              'No foods match that search',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: _results.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final food = _results[index];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(
                                  food.isLiquid
                                      ? Icons.local_drink_rounded
                                      : Icons.restaurant_rounded,
                                  color: scheme.primary,
                                ),
                                title: Text(food.name),
                                subtitle: Text(
                                  '${fmtNum(food.calories)} kcal / 100 ${food.unit}',
                                ),
                                onTap: () => Navigator.pop(context, food),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
