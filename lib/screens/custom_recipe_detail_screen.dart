import 'package:flutter/material.dart';
import '../models/custom_recipe.dart';
import '../services/custom_recipe_service.dart';
import '../services/log_service.dart';
import '../models/log_entry.dart';
import '../widgets/custom_alert.dart';

class CustomRecipeDetailScreen extends StatefulWidget {
  final CustomRecipe recipe;

  const CustomRecipeDetailScreen({super.key, required this.recipe});

  @override
  State<CustomRecipeDetailScreen> createState() => _CustomRecipeDetailScreenState();
}

class _CustomRecipeDetailScreenState extends State<CustomRecipeDetailScreen> {
  late CustomRecipe _recipe;
  final LogService _logService = LogService();
  final TextEditingController _servingsController = TextEditingController();
  final TextEditingController _newTagController = TextEditingController();
  bool _isLogging = false;
  final bool _isEditingDifficulty = false;
  String _tempDifficulty = '';

  @override
  void initState() {
    super.initState();
    _recipe = widget.recipe;
    _servingsController.text = '1';
    _tempDifficulty = _recipe.difficulty;
  }

  @override
  void dispose() {
    _servingsController.dispose();
    _newTagController.dispose();
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
        title: Text(
          _recipe.name,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _recipe.isFavorite ? Icons.favorite : Icons.favorite_border,
              color: Theme.of(context).colorScheme.primary,
            ),
            onPressed: _toggleFavorite,
          ),
          IconButton(
            icon: Icon(
              Icons.delete,
              color: Colors.red,
            ),
            onPressed: _showDeleteConfirmation,
          ),
          IconButton(
            icon: Icon(Icons.home_outlined, color: Theme.of(context).colorScheme.primary, size: 28),
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRecipeHeader(),
            const SizedBox(height: 24),
            _buildNutritionCard(),
            const SizedBox(height: 24),
            _buildIngredientsSection(),
            const SizedBox(height: 24),
            _buildInstructionsSection(),
            const SizedBox(height: 24),
            _buildTagsSection(),
            const SizedBox(height: 24),
            _buildLogToJournalSection(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipeHeader() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _recipe.name,
              style: TextStyle(
                fontSize: 24, 
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _recipe.description,
              style: TextStyle(
                fontSize: 16, 
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            // First row of chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildInfoChip(Icons.schedule, 'Prep: ${_recipe.prepTimeMinutes}m'),
                _buildInfoChip(Icons.timer, 'Cook: ${_recipe.cookTimeMinutes}m'),
                _buildInfoChip(Icons.restaurant, '${_recipe.servings} servings'),
              ],
            ),
            const SizedBox(height: 8),
            // Second row of chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                GestureDetector(
                  onTap: () => _showDifficultyEditor(),
                  child: _buildInfoChip(
                    Icons.signal_cellular_alt,
                    _capitalizeFirst(_recipe.difficulty),
                    color: _getDifficultyColor(_recipe.difficulty),
                    isEditable: true,
                  ),
                ),
                _buildInfoChip(Icons.access_time, 'Total: ${_recipe.totalTimeMinutes}m'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionCard() {
    // Calculate per serving nutrition (recipe stores total nutrition)
    final caloriesPerServing = _recipe.calories / _recipe.servings;
    final proteinPerServing = _recipe.protein / _recipe.servings;
    final carbsPerServing = _recipe.carbs / _recipe.servings;
    final fatPerServing = _recipe.fat / _recipe.servings;
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nutrition Information',
              style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            
            // Total Recipe Nutrition
            Text(
              'Total Recipe (${_recipe.servings} servings)',
              style: TextStyle(
                fontSize: 14, 
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNutritionItem('Calories', '${_recipe.calories.round()}'),
                _buildNutritionItem('Protein', '${_recipe.protein.round()}g'),
                _buildNutritionItem('Carbs', '${_recipe.carbs.round()}g'),
                _buildNutritionItem('Fat', '${_recipe.fat.round()}g'),
              ],
            ),
            
            const SizedBox(height: 12),
            Divider(color: Theme.of(context).colorScheme.outline.withOpacity(0.2)),
            const SizedBox(height: 12),
            
            // Per Serving Nutrition
            Text(
              'Per Serving',
              style: TextStyle(
                fontSize: 14, 
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNutritionItem('Calories', '${caloriesPerServing.round()}'),
                _buildNutritionItem('Protein', '${proteinPerServing.round()}g'),
                _buildNutritionItem('Carbs', '${carbsPerServing.round()}g'),
                _buildNutritionItem('Fat', '${fatPerServing.round()}g'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIngredientsSection() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ingredients',
              style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recipe.ingredients.length,
              itemBuilder: (context, index) {
                String ingredient = _recipe.ingredients[index];
                
                // Clean up ingredient text - remove empty parentheses
                ingredient = ingredient.replaceAll(RegExp(r'\(\s*\)'), '').trim();
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        margin: const EdgeInsets.only(top: 2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Theme.of(context).colorScheme.primary),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          ingredient,
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionsSection() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Instructions',
              style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recipe.instructions.length,
              itemBuilder: (context, index) {
                String instruction = _recipe.instructions[index];
                
                // Check if instruction already starts with a number (from AI)
                bool hasNumberPrefix = RegExp(r'^\d+\.?\s').hasMatch(instruction.trim());
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Only show number circle if instruction doesn't already have a number
                      if (!hasNumberPrefix) ...[
                        Container(
                          width: 28,
                          height: 28,
                          margin: const EdgeInsets.only(top: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Text(
                          instruction,
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagsSection() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tags',
                  style: TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                IconButton(
                  onPressed: _showAddTagDialog,
                  icon: Icon(
                    Icons.add,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  tooltip: 'Add Tag',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Tags help organize and filter your recipes. Popular tags: breakfast, lunch, dinner',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 12),
            if (_recipe.tags.isEmpty)
              Text(
                'No tags added yet. Tap + to add tags for easier recipe organization.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _recipe.tags.map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          tag,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => _removeTag(tag),
                          child: Icon(
                            Icons.close,
                            size: 16,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogToJournalSection() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Log to Food Journal',
              style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Track this recipe in your daily nutrition log',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _servingsController,
                    decoration: InputDecoration(
                      labelText: 'Servings',
                      hintText: 'e.g., 1.5',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _isLogging ? null : _logRecipe,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: _isLogging
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        )
                      : const Icon(Icons.add),
                  label: Text(_isLogging ? 'Logging...' : 'Log Food'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, {Color? color, bool isEditable = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: (color ?? Theme.of(context).colorScheme.outline).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (color ?? Theme.of(context).colorScheme.outline).withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon, 
            size: 16, 
            color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: color != null ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold, 
            fontSize: 16,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12, 
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'hard':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _showErrorSnackBar(String message) {
    AlertHelper.showErrorAlert(
      context,
      title: 'Error',
      message: message,
    );
  }

  Future<void> _toggleFavorite() async {
    try {
      await CustomRecipeService.toggleFavorite(_recipe.id!);
      setState(() {
        _recipe = _recipe.copyWith(isFavorite: !_recipe.isFavorite);
      });
      
      AlertHelper.showSuccessAlert(
        context,
        title: _recipe.isFavorite ? 'Added to Favorites' : 'Removed from Favorites',
        message: _recipe.isFavorite 
            ? 'Recipe has been added to your favorites'
            : 'Recipe has been removed from your favorites',
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
        foodId: _recipe.foodId!,  // Use the linked food ID
        amount: 100.0, // Use 100g as base amount for custom recipes
        date: '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
        portions: servings, // Use portions field for servings
        foodName: _recipe.name,
        calories: _recipe.calories / _recipe.servings, // Per serving calories
        protein: _recipe.protein / _recipe.servings,
        carbs: _recipe.carbs / _recipe.servings,
        fat: _recipe.fat / _recipe.servings,
      );

      await _logService.insertLogEntry(logEntry);

      setState(() => _isLogging = false);
      
      // Show success message with navigation option
      AlertHelper.showSuccessAlert(
        context,
        title: 'Recipe Logged Successfully!',
        message: '$servings serving(s) of ${_recipe.name} logged to your daily nutrition.',
        actionButtonText: 'View Today',
        onActionPressed: () {
          Navigator.of(context).pop(); // Close the alert
          Navigator.of(context).popUntil((route) => route.isFirst);
        },
      );

      _servingsController.text = '1'; // Reset to default
    } catch (e) {
      setState(() => _isLogging = false);
      _showErrorSnackBar('Failed to log recipe: $e');
    }
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Recipe'),
        content: Text('Are you sure you want to delete "${_recipe.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _deleteRecipe();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteRecipe() async {
    try {
      await CustomRecipeService.deleteCustomRecipe(_recipe.id!);
      
      if (mounted) {
        Navigator.of(context).pop();
        AlertHelper.showSuccessAlert(
          context,
          title: 'Recipe Deleted',
          message: 'Recipe has been deleted successfully',
        );
      }
    } catch (e) {
      _showErrorSnackBar('Failed to delete recipe: $e');
    }
  }

  void _showDifficultyEditor() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Difficulty'),
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
                          color: _getDifficultyColor(difficulty),
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
                  setState(() {
                    _tempDifficulty = value;
                  });
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
                final updatedRecipe = _recipe.copyWith(difficulty: _tempDifficulty);
                await CustomRecipeService.updateCustomRecipe(updatedRecipe);
                setState(() {
                  _recipe = updatedRecipe;
                });
                Navigator.of(context).pop();
                AlertHelper.showSuccessAlert(
                  context,
                  title: 'Difficulty Updated',
                  message: 'Recipe difficulty has been updated to ${_capitalizeFirst(_tempDifficulty)}.',
                );
              } catch (e) {
                Navigator.of(context).pop();
                _showErrorSnackBar('Failed to update difficulty: $e');
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddTagDialog() {
    _newTagController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Tag'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _newTagController,
              decoration: const InputDecoration(
                labelText: 'Enter new tag',
                hintText: 'e.g., breakfast, vegetarian, quick',
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Popular tags: breakfast, lunch, dinner',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: _addTag,
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _addTag() async {
    final newTag = _newTagController.text.trim().toLowerCase();
    if (newTag.isNotEmpty && !_recipe.tags.contains(newTag)) {
      try {
        final updatedRecipe = _recipe.copyWith(tags: [..._recipe.tags, newTag]);
        await CustomRecipeService.updateCustomRecipe(updatedRecipe);
        setState(() {
          _recipe = updatedRecipe;
        });
        _newTagController.clear();
        Navigator.of(context).pop();
        AlertHelper.showSuccessAlert(
          context,
          title: 'Tag Added',
          message: 'Tag "$newTag" has been added to the recipe.',
        );
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
      final updatedRecipe = _recipe.copyWith(tags: _recipe.tags.where((t) => t != tag).toList());
      await CustomRecipeService.updateCustomRecipe(updatedRecipe);
      setState(() {
        _recipe = updatedRecipe;
      });
      AlertHelper.showSuccessAlert(
        context,
        title: 'Tag Removed',
        message: 'Tag "$tag" has been removed from the recipe.',
      );
    } catch (e) {
      _showErrorSnackBar('Failed to remove tag: $e');
    }
  }
}