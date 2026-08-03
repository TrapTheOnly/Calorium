import 'package:flutter/material.dart';
import '../models/custom_recipe.dart';
import '../services/custom_recipe_service.dart';
import '../services/log_service.dart';
import '../theme/app_theme.dart';
import '../utils/fasting_prompt.dart';
import '../utils/num_format.dart';
import '../models/log_entry.dart';
import '../widgets/custom_alert.dart';
import '../widgets/ui_kit.dart';

class CustomRecipeDetailScreen extends StatefulWidget {
  final CustomRecipe recipe;

  const CustomRecipeDetailScreen({super.key, required this.recipe});

  @override
  State<CustomRecipeDetailScreen> createState() =>
      _CustomRecipeDetailScreenState();
}

class _CustomRecipeDetailScreenState extends State<CustomRecipeDetailScreen> {
  late CustomRecipe _recipe;
  final LogService _logService = LogService();
  final TextEditingController _servingsController = TextEditingController();
  final TextEditingController _newTagController = TextEditingController();
  bool _isLogging = false;
  bool _showAllIngredients = false;
  bool _detailsExpanded = false;
  String _tempDifficulty = '';
  final Set<int> _checkedIngredients = {};

  static const int _kIngredientPreview = 8;

  @override
  void initState() {
    super.initState();
    _recipe = widget.recipe;
    _servingsController.text = '1';
    _tempDifficulty = _recipe.difficulty;
    _servingsController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _servingsController.dispose();
    _newTagController.dispose();
    super.dispose();
  }

  double get _recipeServings =>
      _recipe.servings == 0 ? 1.0 : _recipe.servings.toDouble();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final totalMin = _recipe.totalTimeMinutes;
    final difficulty = _capitalizeFirst(_recipe.difficulty);

    return Scaffold(
      appBar: PageAppBar(
        title: _recipe.name,
        subtitle: '$totalMin min · $difficulty',
        actions: [
          IconButton(
            icon: Icon(
              _recipe.isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _recipe.isFavorite ? scheme.primary : null,
            ),
            tooltip: 'Favorite',
            onPressed: _toggleFavorite,
          ),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
            tooltip: 'Delete',
            onPressed: _showDeleteConfirmation,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
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
                  _buildNutritionCard(),
                  if (_recipe.description.trim().isNotEmpty) ...[
                    const SizedBox(height: AppTheme.space16),
                    _ExpandableDescription(text: _recipe.description.trim()),
                  ],
                  const SizedBox(height: AppTheme.space16),
                  _buildMetaRow(),
                  const SizedBox(height: AppTheme.space24),
                  _buildIngredients(),
                  const SizedBox(height: AppTheme.space24),
                  _buildInstructions(),
                  const SizedBox(height: AppTheme.space16),
                  _buildDetailsTile(),
                ],
              ),
            ),
            _buildLogBar(),
          ],
        ),
      ),
    );
  }

  // ---- Nutrition (above the fold) ------------------------------------------

  Widget _buildNutritionCard() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final calPer = _recipe.calories / _recipeServings;
    final protPer = _recipe.protein / _recipeServings;
    final carbPer = _recipe.carbs / _recipeServings;
    final fatPer = _recipe.fat / _recipeServings;

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
              Expanded(child: _macroPill('Protein', protPer, scheme.primary)),
              const SizedBox(width: AppTheme.space8),
              Expanded(child: _macroPill('Carbs', carbPer, scheme.tertiary)),
              const SizedBox(width: AppTheme.space8),
              Expanded(child: _macroPill('Fat', fatPer, scheme.secondary)),
            ],
          ),
          const SizedBox(height: AppTheme.space8),
          Text(
            'Whole recipe: ${fmtNum(_recipe.calories)} kcal · '
            '${fmtNum(_recipe.protein)}P · ${fmtNum(_recipe.carbs)}C · '
            '${fmtNum(_recipe.fat)}F',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaRow() {
    // Max 3 chips — time/difficulty already peek in the AppBar subtitle;
    // servings is the one fact cooking needs at a glance. Prep/cook live
    // under Details to avoid repeating the same numbers.
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _infoChip(Icons.restaurant_rounded, '${_recipe.servings} servings'),
        _infoChip(
          Icons.signal_cellular_alt_rounded,
          _capitalizeFirst(_recipe.difficulty),
          color: _difficultyColor(_recipe.difficulty),
        ),
        if (_recipe.prepTimeMinutes > 0 || _recipe.cookTimeMinutes > 0)
          _infoChip(
            Icons.soup_kitchen_outlined,
            'Prep ${_recipe.prepTimeMinutes}m · Cook ${_recipe.cookTimeMinutes}m',
          ),
      ],
    );
  }

  // ---- Ingredients ---------------------------------------------------------

  Widget _buildIngredients() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final all = _recipe.ingredients;
    final showAll = _showAllIngredients || all.length <= _kIngredientPreview;
    final visible = showAll ? all : all.take(_kIngredientPreview).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Ingredients', style: theme.textTheme.titleMedium),
            const SizedBox(width: AppTheme.space8),
            Text(
              '${all.length}',
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.space12),
        ...visible.asMap().entries.map((entry) {
          // Map visible index back to the real ingredient index so check
          // state survives "Show all".
          final realIndex = entry.key;
          final ingredient =
              entry.value.replaceAll(RegExp(r'\(\s*\)'), '').trim();
          final checked = _checkedIngredients.contains(realIndex);
          final isLast = entry.key == visible.length - 1 && showAll;
          return Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : AppTheme.space4),
            child: InkWell(
              onTap: () => setState(() {
                if (checked) {
                  _checkedIngredients.remove(realIndex);
                } else {
                  _checkedIngredients.add(realIndex);
                }
              }),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      checked
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                      size: 22,
                      color: checked
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppTheme.space8),
                    Expanded(
                      child: Text(
                        ingredient,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.4,
                          decoration: checked
                              ? TextDecoration.lineThrough
                              : null,
                          color: checked
                              ? scheme.onSurfaceVariant
                              : scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        if (!showAll)
          TextButton(
            onPressed: () => setState(() => _showAllIngredients = true),
            child: Text('Show all (${all.length})'),
          ),
      ],
    );
  }

  // ---- Instructions --------------------------------------------------------

  Widget _buildInstructions() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Instructions', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppTheme.space12),
        ..._recipe.instructions.asMap().entries.map((entry) {
          final index = entry.key;
          final instruction =
              entry.value.trim().replaceFirst(RegExp(r'^\d+\.?\s*'), '');
          final isLast = index == _recipe.instructions.length - 1;
          return Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : AppTheme.space20),
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
                      instruction,
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

  // ---- Collapsed details (tags) --------------------------------------------

  Widget _buildDetailsTile() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => _detailsExpanded = !_detailsExpanded),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.space12,
            vertical: AppTheme.space8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Details & tags', style: theme.textTheme.titleSmall),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _detailsExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox(width: double.infinity),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: AppTheme.space8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text('Difficulty',
                            style: theme.textTheme.bodyMedium),
                        trailing: Text(
                          _capitalizeFirst(_recipe.difficulty),
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: _difficultyColor(_recipe.difficulty),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onTap: _showDifficultyEditor,
                      ),
                      if (_recipe.tags.isEmpty)
                        Text(
                          'No tags yet.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _recipe.tags.map((tag) {
                            return Container(
                              padding: const EdgeInsets.only(
                                left: 12,
                                right: 6,
                                top: 6,
                                bottom: 6,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.secondaryContainer,
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusPill),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    tag,
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                      color: scheme.onSecondaryContainer,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  GestureDetector(
                                    onTap: () => _removeTag(tag),
                                    child: Icon(
                                      Icons.close_rounded,
                                      size: 15,
                                      color: scheme.onSecondaryContainer,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      TextButton.icon(
                        onPressed: _showAddTagDialog,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Add tag'),
                      ),
                    ],
                  ),
                ),
                crossFadeState: _detailsExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 180),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Pinned log bar ------------------------------------------------------

  Widget _buildLogBar() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final servings = double.tryParse(_servingsController.text.trim());
    final valid = servings != null && servings > 0;
    final previewCal =
        valid ? (_recipe.calories / _recipeServings) * servings : null;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.5),
          ),
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
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppTheme.space12),
          Expanded(
            child: Text(
              previewCal != null
                  ? '${fmtNum(previewCal)} kcal'
                  : '—',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: previewCal != null
                    ? scheme.onSurface
                    : scheme.onSurfaceVariant,
              ),
            ),
          ),
          FilledButton.icon(
            onPressed: (_isLogging || !valid) ? null : _logRecipe,
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
            label: Text(_isLogging ? 'Logging…' : 'Add to today'),
          ),
        ],
      ),
    );
  }

  // ---- Small widgets -------------------------------------------------------

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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final c = color ?? scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: c),
          const SizedBox(width: 5),
          Text(
            text,
            style: theme.textTheme.labelMedium?.copyWith(
              color: c,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  Color _difficultyColor(String difficulty) {
    final scheme = Theme.of(context).colorScheme;
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return scheme.tertiary;
      case 'medium':
        return scheme.secondary;
      case 'hard':
        return scheme.error;
      default:
        return scheme.onSurfaceVariant;
    }
  }

  void _showErrorSnackBar(String message) {
    AlertHelper.showErrorAlert(context, title: 'Error', message: message);
  }

  Future<void> _toggleFavorite() async {
    try {
      await CustomRecipeService.toggleFavorite(_recipe.id!);
      setState(() {
        _recipe = _recipe.copyWith(isFavorite: !_recipe.isFavorite);
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _recipe.isFavorite
                ? 'Added to favorites'
                : 'Removed from favorites',
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      _showErrorSnackBar('Failed to update favorite status');
    }
  }

  Future<void> _logRecipe() async {
    final servingsText = _servingsController.text.trim();
    if (servingsText.isEmpty) {
      _showErrorSnackBar('Please enter number of servings');
      return;
    }

    final servings = double.tryParse(servingsText);
    if (servings == null || servings <= 0) {
      _showErrorSnackBar('Please enter a valid number of servings');
      return;
    }

    if (_recipe.foodId == null) {
      _showErrorSnackBar('Recipe not properly linked to food database');
      return;
    }

    setState(() => _isLogging = true);

    try {
      final now = DateTime.now();
      final logEntry = LogEntry(
        foodId: _recipe.foodId!,
        // One serving == 100 nominal units for recipe foods, so N servings is
        // stored as amount = 100 * N. Readers use perServingCal * amount / 100,
        // which then correctly yields perServingCal * N.
        amount: 100.0 * servings,
        date:
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
        portions: servings,
        foodName: _recipe.name,
        calories: _recipe.calories / _recipeServings,
        protein: _recipe.protein / _recipeServings,
        carbs: _recipe.carbs / _recipeServings,
        fat: _recipe.fat / _recipeServings,
      );

      await _logService.insertLogEntry(logEntry);

      if (!mounted) return;

      await FastingPrompt.showIfNeeded(
        context,
        loggedAt: logEntry.loggedAt,
        mealName: _recipe.name,
      );

      if (!mounted) return;

      setState(() => _isLogging = false);

      AlertHelper.showSuccessAlert(
        context,
        title: 'Recipe logged',
        message:
            '$servings serving(s) of ${_recipe.name} added to today\'s log.',
        actionButtonText: 'View Today',
        onActionPressed: () {
          Navigator.of(context).pop();
          Navigator.of(context).popUntil((route) => route.isFirst);
        },
      );

      _servingsController.text = '1';
    } catch (e) {
      setState(() => _isLogging = false);
      _showErrorSnackBar('Failed to log recipe: $e');
    }
  }

  void _showDeleteConfirmation() async {
    final bool confirm = await AlertHelper.showConfirmationAlert(
          context,
          title: 'Delete Recipe',
          message:
              'Are you sure you want to delete "${_recipe.name}"? This action cannot be undone.',
          confirmButtonText: 'Delete',
          type: AlertType.error,
        ) ??
        false;

    if (confirm) await _deleteRecipe();
  }

  Future<void> _deleteRecipe() async {
    try {
      await CustomRecipeService.deleteCustomRecipe(_recipe.id!);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recipe deleted')),
        );
      }
    } catch (e) {
      _showErrorSnackBar('Failed to delete recipe: $e');
    }
  }

  void _showDifficultyEditor() {
    AlertHelper.showCustomDialog<void>(
      context,
      title: 'Edit Difficulty',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Select recipe difficulty:'),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _tempDifficulty,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: ['easy', 'medium', 'hard'].map((difficulty) {
              return DropdownMenuItem(
                value: difficulty,
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _difficultyColor(difficulty),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(_capitalizeFirst(difficulty)),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _tempDifficulty = value);
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () async {
            try {
              final updatedRecipe =
                  _recipe.copyWith(difficulty: _tempDifficulty);
              await CustomRecipeService.updateCustomRecipe(updatedRecipe);
              setState(() => _recipe = updatedRecipe);
              if (!mounted) return;
              Navigator.of(context).pop();
            } catch (e) {
              Navigator.of(context).pop();
              _showErrorSnackBar('Failed to update difficulty: $e');
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _showAddTagDialog() {
    _newTagController.clear();
    AlertHelper.showCustomDialog<void>(
      context,
      title: 'Add Tag',
      content: TextField(
        controller: _newTagController,
        decoration: const InputDecoration(
          labelText: 'Enter new tag',
          hintText: 'e.g., breakfast, vegetarian, quick',
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _addTag, child: const Text('Add')),
      ],
    );
  }

  void _addTag() async {
    final newTag = _newTagController.text.trim().toLowerCase();
    if (newTag.isNotEmpty && !_recipe.tags.contains(newTag)) {
      try {
        final updatedRecipe = _recipe.copyWith(tags: [..._recipe.tags, newTag]);
        await CustomRecipeService.updateCustomRecipe(updatedRecipe);
        setState(() => _recipe = updatedRecipe);
        _newTagController.clear();
        if (!mounted) return;
        Navigator.of(context).pop();
      } catch (e) {
        Navigator.of(context).pop();
        _showErrorSnackBar('Failed to add tag: $e');
      }
    } else if (_recipe.tags.contains(newTag)) {
      AlertHelper.showErrorAlert(
        context,
        title: 'Duplicate Tag',
        message: 'This tag already exists for this recipe.',
      );
    }
  }

  void _removeTag(String tag) async {
    try {
      final updatedRecipe = _recipe.copyWith(
        tags: _recipe.tags.where((t) => t != tag).toList(),
      );
      await CustomRecipeService.updateCustomRecipe(updatedRecipe);
      setState(() => _recipe = updatedRecipe);
    } catch (e) {
      _showErrorSnackBar('Failed to remove tag: $e');
    }
  }
}

/// Clamped description with Read more — keeps the first viewport scannable.
class _ExpandableDescription extends StatefulWidget {
  const _ExpandableDescription({required this.text});
  final String text;

  @override
  State<_ExpandableDescription> createState() => _ExpandableDescriptionState();
}

class _ExpandableDescriptionState extends State<_ExpandableDescription> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.topCenter,
          child: Text(
            widget.text,
            maxLines: _expanded ? null : 3,
            overflow: _expanded ? null : TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ),
        if (widget.text.length > 120)
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
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
    );
  }
}
