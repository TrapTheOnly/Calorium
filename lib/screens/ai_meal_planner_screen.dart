import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/custom_recipe.dart';
import '../models/food.dart';
import '../services/custom_recipe_service.dart';
import '../services/food_service.dart';
import '../services/ingredient_scanner_service.dart';
import '../services/smart_meal_planner_service.dart';
import '../theme/app_theme.dart';
import '../utils/num_format.dart';
import '../widgets/custom_alert.dart';
import '../widgets/ui_kit.dart';
import 'custom_recipe_detail_screen.dart';
import 'custom_recipes_screen.dart';

/// How the user seeds the recipe generation.
enum RecipeInputMode { photo, inventory, describe }

class AiMealPlannerScreen extends StatefulWidget {
  const AiMealPlannerScreen({
    super.key,
    this.initialTargetMacros,
  });

  /// When provided (e.g. from the "close today's gap" flow), the screen opens
  /// in describe mode with these macro targets pre-filled.
  final Map<String, double>? initialTargetMacros;

  @override
  State<AiMealPlannerScreen> createState() => _AiMealPlannerScreenState();
}

class _AiMealPlannerScreenState extends State<AiMealPlannerScreen> {
  final ImagePicker _picker = ImagePicker();
  final FoodService _foodService = FoodService();

  int _step = 0; // 0 input · 1 preferences · 2 recipe · 3 saved
  late RecipeInputMode _mode;

  // Photo mode
  File? _scannedImage;
  Map<String, dynamic>? _scannedIngredients;
  bool _isScanning = false;

  // Inventory mode
  List<Food> _basics = [];
  bool _basicsLoading = false;
  final Set<int> _selectedBasics = {};
  final TextEditingController _basicsSearch = TextEditingController();

  // Describe mode
  final TextEditingController _descCtrl = TextEditingController();
  final TextEditingController _calCtrl = TextEditingController();
  final TextEditingController _proteinCtrl = TextEditingController();
  final TextEditingController _carbCtrl = TextEditingController();
  final TextEditingController _fatCtrl = TextEditingController();

  final Map<String, String> _userPreferences = {};

  Map<String, dynamic>? _mealRecommendation;
  CustomRecipe? _generatedRecipe;
  bool _isGenerating = false;
  bool _generateRequested = false;
  bool _isSaving = false;

  final List<String> _steps = ['Input', 'Preferences', 'Recipe', 'Saved'];

  @override
  void initState() {
    super.initState();
    final target = widget.initialTargetMacros;
    _mode = target != null ? RecipeInputMode.describe : RecipeInputMode.photo;
    if (target != null) {
      if ((target['calories'] ?? 0) > 0) {
        _calCtrl.text = target['calories']!.round().toString();
      }
      if ((target['protein'] ?? 0) > 0) {
        _proteinCtrl.text = target['protein']!.round().toString();
      }
      if ((target['carbs'] ?? 0) > 0) {
        _carbCtrl.text = target['carbs']!.round().toString();
      }
      if ((target['fat'] ?? 0) > 0) {
        _fatCtrl.text = target['fat']!.round().toString();
      }
    }
  }

  @override
  void dispose() {
    _basicsSearch.dispose();
    _descCtrl.dispose();
    _calCtrl.dispose();
    _proteinCtrl.dispose();
    _carbCtrl.dispose();
    _fatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PageAppBar(
        title: 'AI Recipe',
        subtitle: 'Generate a recipe your way',
        actions: [
          IconButton(
            icon: const Icon(Icons.restaurant_menu_rounded),
            onPressed: _navigateToCustomRecipes,
            tooltip: 'My recipes',
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _buildStepIndicator(),
            Expanded(child: _buildStep()),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.pagePadding,
        vertical: AppTheme.space12,
      ),
      child: Row(
        children: [
          for (int i = 0; i < _steps.length; i++) ...[
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i <= _step
                    ? scheme.primary
                    : scheme.surfaceContainerHighest,
              ),
              child: Center(
                child: i < _step
                    ? Icon(Icons.check_rounded,
                        size: 15, color: scheme.onPrimary)
                    : Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: i == _step
                              ? scheme.onPrimary
                              : scheme.onSurfaceVariant,
                        ),
                      ),
              ),
            ),
            if (i < _steps.length - 1)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  color: i < _step
                      ? scheme.primary
                      : scheme.surfaceContainerHighest,
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _buildInputStep();
      case 1:
        return _buildQuestionnaireStep();
      case 2:
        return _buildRecipeStep();
      default:
        return _buildSavedStep();
    }
  }

  // ---------------------------------------------------------------------------
  // Step 0 — input

  bool get _inputReady {
    switch (_mode) {
      case RecipeInputMode.photo:
        return _scannedIngredients != null;
      case RecipeInputMode.inventory:
        return _selectedBasics.isNotEmpty;
      case RecipeInputMode.describe:
        return _descCtrl.text.trim().isNotEmpty ||
            _calCtrl.text.trim().isNotEmpty ||
            _proteinCtrl.text.trim().isNotEmpty;
    }
  }

  Widget _buildInputStep() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.pagePadding,
        0,
        AppTheme.pagePadding,
        AppTheme.space24,
      ),
      children: [
        SegmentedButton<RecipeInputMode>(
          style: SegmentedButton.styleFrom(
            textStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            visualDensity: VisualDensity.compact,
          ),
          segments: const [
            ButtonSegment(
              value: RecipeInputMode.photo,
              icon: Icon(Icons.photo_camera_outlined, size: 18),
              label: Text('Photo', maxLines: 1),
            ),
            ButtonSegment(
              value: RecipeInputMode.inventory,
              icon: Icon(Icons.kitchen_outlined, size: 18),
              label: Text('Inventory', maxLines: 1),
            ),
            ButtonSegment(
              value: RecipeInputMode.describe,
              icon: Icon(Icons.edit_outlined, size: 18),
              label: Text('Describe', maxLines: 1),
            ),
          ],
          selected: {_mode},
          showSelectedIcon: false,
          onSelectionChanged: (s) {
            setState(() => _mode = s.first);
            if (_mode == RecipeInputMode.inventory && _basics.isEmpty) {
              _loadBasics();
            }
          },
        ),
        const SizedBox(height: AppTheme.space16),
        if (_mode == RecipeInputMode.photo) _photoInput(),
        if (_mode == RecipeInputMode.inventory) _inventoryInput(),
        if (_mode == RecipeInputMode.describe) _describeInput(),
        const SizedBox(height: AppTheme.space24),
        FilledButton(
          onPressed: _inputReady ? () => setState(() => _step = 1) : null,
          child: const Text('Continue'),
        ),
      ],
    );
  }

  Widget _photoInput() {
    final scheme = Theme.of(context).colorScheme;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Snap your fridge or ingredients',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'The AI identifies what you have and builds a recipe around it.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppTheme.space16),
          if (_scannedImage != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              child: Image.file(
                _scannedImage!,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: AppTheme.space12),
          ],
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed:
                      _isScanning ? null : () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Camera'),
                ),
              ),
              const SizedBox(width: AppTheme.space12),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed:
                      _isScanning ? null : () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Gallery'),
                ),
              ),
            ],
          ),
          if (_isScanning) ...[
            const SizedBox(height: AppTheme.space16),
            Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: AppTheme.space12),
                Text('Analyzing ingredients…',
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ],
          if (_scannedIngredients != null) ...[
            const SizedBox(height: AppTheme.space16),
            _scannedChips(),
          ],
        ],
      ),
    );
  }

  Widget _scannedChips() {
    final ingredients = (_scannedIngredients!['ingredients'] as List?) ?? [];
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Found ${ingredients.length} ingredients',
            style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: AppTheme.space8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: ingredients.map((ing) {
            return Chip(
              label: Text(ing['name']?.toString() ?? ''),
              backgroundColor: scheme.surfaceContainerHigh,
              side: BorderSide.none,
              visualDensity: VisualDensity.compact,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _inventoryInput() {
    final scheme = Theme.of(context).colorScheme;
    final query = _basicsSearch.text.trim().toLowerCase();
    final filtered = _basics
        .where((f) => query.isEmpty || f.name.toLowerCase().contains(query))
        .toList();

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pick from your basics',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Select the ingredients you have on hand.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppTheme.space12),
          TextField(
            controller: _basicsSearch,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'Search your basics…',
              isDense: true,
            ),
          ),
          const SizedBox(height: AppTheme.space12),
          if (_basicsLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppTheme.space16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_basics.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppTheme.space12),
              child: Text(
                'No basics yet. Add foods in the Foods tab first, or use '
                'Describe mode.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: filtered.take(60).map((f) {
                final selected = _selectedBasics.contains(f.id);
                return FilterChip(
                  label: Text(f.name),
                  selected: selected,
                  onSelected: (v) => setState(() {
                    if (v) {
                      _selectedBasics.add(f.id!);
                    } else {
                      _selectedBasics.remove(f.id!);
                    }
                  }),
                );
              }).toList(),
            ),
          if (_selectedBasics.isNotEmpty) ...[
            const SizedBox(height: AppTheme.space8),
            Text('${_selectedBasics.length} selected',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                )),
          ],
        ],
      ),
    );
  }

  Widget _describeInput() {
    return Column(
      children: [
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tell the AI what you want',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppTheme.space12),
              TextField(
                controller: _descCtrl,
                onChanged: (_) => setState(() {}),
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText:
                      'e.g. a quick high-protein dinner with chicken and rice',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.space12),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.track_changes_rounded,
                      size: 18, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: AppTheme.space8),
                  Text('Macro target (optional)',
                      style: Theme.of(context).textTheme.titleSmall),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Aim the recipe at specific macros — great for closing a gap.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppTheme.space12),
              Row(
                children: [
                  Expanded(child: _macroField(_calCtrl, 'kcal')),
                  const SizedBox(width: AppTheme.space8),
                  Expanded(child: _macroField(_proteinCtrl, 'Protein g')),
                ],
              ),
              const SizedBox(height: AppTheme.space8),
              Row(
                children: [
                  Expanded(child: _macroField(_carbCtrl, 'Carbs g')),
                  const SizedBox(width: AppTheme.space8),
                  Expanded(child: _macroField(_fatCtrl, 'Fat g')),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _macroField(TextEditingController c, String label) {
    return TextField(
      controller: c,
      keyboardType: TextInputType.number,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 1 — preferences

  Widget _buildQuestionnaireStep() {
    final questions = SmartMealPlannerService.getCustomizationQuestions();
    final titles = {
      'timeAvailable': 'How much time do you have?',
      'cookingSkill': 'Cooking skill level?',
      'mealTypePreference': 'What are you in the mood for?',
      'cuisinePreference': 'Cuisine preference?',
      'dietaryRestrictions': 'Dietary restrictions?',
    };
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.pagePadding,
              0,
              AppTheme.pagePadding,
              AppTheme.space16,
            ),
            children: questions.entries
                .map((e) => _questionCard(titles[e.key] ?? e.key, e.key, e.value))
                .toList(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.pagePadding,
            0,
            AppTheme.pagePadding,
            AppTheme.space16,
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _step = 0),
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: AppTheme.space12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _canGenerate()
                      ? () => setState(() => _step = 2)
                      : null,
                  child: const Text('Generate recipe'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _questionCard(String title, String key, List<String> options) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space12),
      child: SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppTheme.space8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: options.map((o) {
                final selected = _userPreferences[key] == o;
                return ChoiceChip(
                  label: Text(o),
                  selected: selected,
                  onSelected: (v) => setState(() {
                    if (v) {
                      _userPreferences[key] = o;
                    } else {
                      _userPreferences.remove(key);
                    }
                  }),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  bool _canGenerate() =>
      _userPreferences.containsKey('timeAvailable') &&
      _userPreferences.containsKey('cookingSkill');

  // ---------------------------------------------------------------------------
  // Step 2 — recipe

  Widget _buildRecipeStep() {
    if (_mealRecommendation != null) return _buildRecipeDisplay();
    if (!_isGenerating && !_generateRequested) {
      _generateRequested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _generate());
    }
    return _centeredLoader('Creating your recipe…',
        'Balancing your inputs, preferences and targets.');
  }

  Widget _centeredLoader(String title, String? subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: AppTheme.space16),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.space32,
              ),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecipeDisplay() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final recipe = _mealRecommendation!;
    final nutrition = recipe['nutrition'] as Map<String, dynamic>;
    final servings = (recipe['servings'] as num?)?.toInt() ?? 1;
    final target = _targetMacros();
    final matchesTarget = target != null &&
        (target['protein'] ?? 0) > 0 &&
        (nutrition['protein'] as num) >= (target['protein']! * 0.8);

    double perServing(String k) {
      final v = (nutrition[k] as num).toDouble();
      return servings > 0 ? v / servings : v;
    }

    final totalMinutes = ((recipe['prepTime'] ?? 0) as num).toInt() +
        ((recipe['cookTime'] ?? 0) as num).toInt();

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.pagePadding,
              0,
              AppTheme.pagePadding,
              AppTheme.space16,
            ),
            children: [
              Text(
                recipe['recipeName']?.toString() ?? 'Recipe',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppTheme.space8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _infoChip(Icons.schedule_rounded, '$totalMinutes min'),
                  _infoChip(Icons.restaurant_rounded, '$servings servings'),
                  _infoChip(Icons.signal_cellular_alt_rounded,
                      _cap(recipe['difficulty']?.toString() ?? 'easy')),
                  if (matchesTarget)
                    _infoChip(Icons.check_circle_rounded, 'Matches target',
                        color: scheme.primary),
                ],
              ),
              const SizedBox(height: AppTheme.space16),
              // Calorie hero + macro pills — the scannable summary.
              SectionCard(
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          fmtNum(perServing('calories')),
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: scheme.primary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text('kcal / serving',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            )),
                      ],
                    ),
                    const SizedBox(height: AppTheme.space16),
                    Row(
                      children: [
                        Expanded(
                          child: _macroPill('Protein',
                              perServing('protein'), scheme.primary),
                        ),
                        const SizedBox(width: AppTheme.space8),
                        Expanded(
                          child: _macroPill(
                              'Carbs', perServing('carbs'), scheme.tertiary),
                        ),
                        const SizedBox(width: AppTheme.space8),
                        Expanded(
                          child: _macroPill(
                              'Fat', perServing('fat'), scheme.secondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.space8),
                    Text(
                      'Whole recipe: ${fmtNum((nutrition['calories'] as num).toDouble())} kcal · '
                      '${fmtNum((nutrition['protein'] as num).toDouble())}P · '
                      '${fmtNum((nutrition['carbs'] as num).toDouble())}C · '
                      '${fmtNum((nutrition['fat'] as num).toDouble())}F',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (recipe['description'] != null) ...[
                const SizedBox(height: AppTheme.space12),
                Text(
                  recipe['description'].toString(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
              if (recipe['whyThisRecipe'] != null) ...[
                const SizedBox(height: AppTheme.space12),
                _ExpandableNote(text: recipe['whyThisRecipe'].toString()),
              ],
            ],
          ),
        ),
        _recipeActionBar(),
      ],
    );
  }

  Widget _recipeActionBar() {
    final scheme = Theme.of(context).colorScheme;
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: _isGenerating
                      ? null
                      : () => setState(() {
                            _mealRecommendation = null;
                            _generateRequested = false;
                          }),
                  child: const Text('Regenerate', maxLines: 1),
                ),
              ),
              const SizedBox(width: AppTheme.space12),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: _isSaving ? null : _saveRecipe,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.bookmark_add_outlined, size: 18),
                  label: const Text('Save', maxLines: 1),
                ),
              ),
            ],
          ),
          TextButton(
            onPressed: () => setState(() {
              _mealRecommendation = null;
              _generateRequested = false;
              _step = 0;
            }),
            child: const Text('Start over'),
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

  Widget _infoChip(IconData icon, String text, {Color? color}) {
    final scheme = Theme.of(context).colorScheme;
    final c = color ?? scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: c),
          const SizedBox(width: 5),
          Text(text,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: c)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 3 — saved

  Widget _buildSavedStep() {
    if (_isSaving || _generatedRecipe == null) {
      return _centeredLoader('Saving…', null);
    }
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(AppTheme.pagePadding),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_rounded, size: 56, color: scheme.primary),
          const SizedBox(height: AppTheme.space12),
          Text('Recipe saved',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              )),
          const SizedBox(height: 4),
          Text(
            '"${_generatedRecipe!.name}" is in your recipes.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppTheme.space20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      CustomRecipeDetailScreen(recipe: _generatedRecipe!),
                ),
              ),
              child: const Text('View full recipe'),
            ),
          ),
          const SizedBox(height: AppTheme.space8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _resetAndStartOver,
              child: const Text('Create another'),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Logic

  Future<void> _loadBasics() async {
    setState(() => _basicsLoading = true);
    try {
      final foods = await _foodService.getSimpleFoods();
      if (mounted) {
        setState(() {
          _basics = foods;
          _basicsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _basicsLoading = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _scannedImage = File(image.path);
          _isScanning = true;
        });
        final result =
            await IngredientScannerService.scanIngredients(_scannedImage!);
        if (mounted) {
          setState(() {
            _scannedIngredients = result;
            _isScanning = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isScanning = false);
      _showError('Failed to scan image: $e');
    }
  }

  Map<String, double>? _targetMacros() {
    double? parse(TextEditingController c) {
      final v = double.tryParse(c.text.trim());
      return (v != null && v > 0) ? v : null;
    }

    final cal = parse(_calCtrl);
    final p = parse(_proteinCtrl);
    final carb = parse(_carbCtrl);
    final fat = parse(_fatCtrl);
    if (cal == null && p == null && carb == null && fat == null) return null;
    return {
      if (cal != null) 'calories': cal,
      if (p != null) 'protein': p,
      if (carb != null) 'carbs': carb,
      if (fat != null) 'fat': fat,
    };
  }

  Future<void> _generate() async {
    setState(() => _isGenerating = true);
    try {
      List<Map<String, dynamic>>? ingredients;
      List<String>? pantry;
      String? freeText;

      switch (_mode) {
        case RecipeInputMode.photo:
          ingredients = (_scannedIngredients?['ingredients'] as List?)
              ?.cast<Map<String, dynamic>>();
          break;
        case RecipeInputMode.inventory:
          pantry = _basics
              .where((f) => _selectedBasics.contains(f.id))
              .map((f) => f.name)
              .toList();
          break;
        case RecipeInputMode.describe:
          freeText = _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim();
          break;
      }

      final result = await SmartMealPlannerService.generateMealRecommendation(
        availableIngredients: ingredients,
        pantryItems: pantry,
        freeText: freeText,
        targetMacros: _targetMacros(),
        userPreferences: _userPreferences,
      );

      if (result != null && mounted) {
        setState(() {
          _mealRecommendation = result;
          _isGenerating = false;
        });
      } else if (mounted) {
        setState(() {
          _isGenerating = false;
          _generateRequested = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _generateRequested = false;
          _mealRecommendation = null;
        });
        AlertHelper.showInfoAlert(
          context,
          title: 'Could not create recipe',
          message:
              'The AI could not build a recipe from these inputs. Try adjusting '
              'your ingredients, description, or preferences.',
          actionButtonText: 'Back',
          onActionPressed: () {
            Navigator.of(context).pop();
            setState(() => _step = 0);
          },
        );
      }
    }
  }

  Future<void> _saveRecipe() async {
    if (_mealRecommendation == null) return;
    setState(() {
      _isSaving = true;
      _step = 3;
    });
    try {
      final aiPrompt = 'Mode: ${_mode.name}. '
          'Preferences: ${_userPreferences.toString()}';
      final customRecipe = SmartMealPlannerService.convertToCustomRecipe(
        _mealRecommendation!,
        aiPrompt,
      );
      final recipeId = await CustomRecipeService.saveCustomRecipe(customRecipe);
      final saved = await CustomRecipeService.getRecipeById(recipeId);
      if (mounted) {
        setState(() {
          _generatedRecipe = saved;
          _isSaving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _step = 2;
        });
        _showError('Failed to save recipe: $e');
      }
    }
  }

  void _resetAndStartOver() {
    setState(() {
      _scannedImage = null;
      _scannedIngredients = null;
      _selectedBasics.clear();
      _descCtrl.clear();
      _userPreferences.clear();
      _mealRecommendation = null;
      _generatedRecipe = null;
      _generateRequested = false;
      _step = 0;
    });
  }

  void _navigateToCustomRecipes() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CustomRecipesScreen()),
    );
  }

  void _showError(String message) {
    AlertHelper.showErrorAlert(context, title: 'Error', message: message);
  }

  String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();
}

/// A "Why this recipe" note that stays compact (3 lines) with a Read more toggle
/// so the result screen doesn't become a wall of text.
class _ExpandableNote extends StatefulWidget {
  const _ExpandableNote({required this.text});
  final String text;

  @override
  State<_ExpandableNote> createState() => _ExpandableNoteState();
}

class _ExpandableNoteState extends State<_ExpandableNote> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.space12),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded,
                  size: 18, color: scheme.primary),
              const SizedBox(width: AppTheme.space8),
              Text('Why this recipe',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  )),
            ],
          ),
          const SizedBox(height: AppTheme.space8),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.topCenter,
            child: Text(
              widget.text,
              maxLines: _expanded ? null : 3,
              overflow: _expanded ? null : TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
            ),
          ),
          if (widget.text.length > 140)
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _expanded ? 'Show less' : 'Read more',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
