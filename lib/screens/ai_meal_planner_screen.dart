import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/ingredient_scanner_service.dart';
import '../services/smart_meal_planner_service.dart';
import '../services/custom_recipe_service.dart';
import '../models/custom_recipe.dart';
import '../widgets/custom_alert.dart';
import 'custom_recipe_detail_screen.dart';
import 'custom_recipes_screen.dart';

class AiMealPlannerScreen extends StatefulWidget {
  const AiMealPlannerScreen({Key? key}) : super(key: key);

  @override
  State<AiMealPlannerScreen> createState() => _AiMealPlannerScreenState();
}

class _AiMealPlannerScreenState extends State<AiMealPlannerScreen> {
  final ImagePicker _picker = ImagePicker();
  
  // State management
  File? _scannedImage;
  Map<String, dynamic>? _scannedIngredients;
  Map<String, String> _userPreferences = {};
  Map<String, dynamic>? _mealRecommendation;
  CustomRecipe? _generatedRecipe;
  
  bool _isScanning = false;
  bool _isGenerating = false;
  bool _isSaving = false;
  int _currentStep = 0;

  final List<String> _steps = [
    'Scan Ingredients',
    'Answer Questions',
    'Get Recipe',
    'Save & Cook!'
  ];

  @override
  Widget build(BuildContext context) {
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
        title: Text(
          'AI Meal Planner',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onBackground,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.restaurant_menu,
              color: Theme.of(context).colorScheme.primary,
            ),
            onPressed: _navigateToCustomRecipes,
            tooltip: 'My Custom Recipes',
          ),
          IconButton(
            icon: Icon(Icons.home_outlined, color: Theme.of(context).colorScheme.primary, size: 28),
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStepIndicator(),
          Expanded(
            child: _buildCurrentStepContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: List.generate(_steps.length, (index) {
          final isCompleted = index < _currentStep;
          final isCurrent = index == _currentStep;
          
          return Expanded(
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted 
                        ? Theme.of(context).colorScheme.primary
                        : isCurrent 
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outline.withOpacity(0.3),
                  ),
                  child: Center(
                    child: isCompleted
                        ? Icon(
                            Icons.check, 
                            color: Theme.of(context).colorScheme.onPrimary, 
                            size: 16,
                          )
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: isCurrent 
                                  ? Theme.of(context).colorScheme.onPrimary 
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                  ),
                ),
                if (index < _steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: isCompleted 
                          ? Theme.of(context).colorScheme.primary 
                          : Theme.of(context).colorScheme.outline.withOpacity(0.3),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildIngredientScanStep();
      case 1:
        return _buildQuestionnaireStep();
      case 2:
        return _buildRecipeGenerationStep();
      case 3:
        return _buildSaveRecipeStep();
      default:
        return const Center(child: Text('Invalid step'));
    }
  }

  Widget _buildIngredientScanStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const Text(
            'Let\'s see what you have to work with!',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            'Take a photo of your fridge, pantry, or ingredients laid out on your counter. Our AI will identify what you have available.',
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          
          if (_scannedImage != null) ...[
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.3)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(_scannedImage!, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 16),
          ],

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isScanning ? null : () => _pickImage(ImageSource.camera),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Take Photo'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isScanning ? null : () => _pickImage(ImageSource.gallery),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    foregroundColor: Theme.of(context).colorScheme.onSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Choose Photo'),
                ),
              ),
            ],
          ),

          if (_isScanning) ...[
            const SizedBox(height: 24),
            CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Analyzing your ingredients...',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onBackground,
              ),
            ),
          ],

          if (_scannedIngredients != null) ...[
            const SizedBox(height: 24),
            _buildIngredientsPreview(),
          ],
        ],
      ),
    );
  }

  Widget _buildIngredientsPreview() {
    final ingredients = _scannedIngredients!['ingredients'] as List;
    final suggestions = _scannedIngredients!['suggestions'] as List;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Found ${ingredients.length} ingredients:',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'The percentages show our AI\'s confidence in identifying each ingredient.',
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 12),
        // Category color legend
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  'Category Colors:',
                  style: TextStyle(
                    fontSize: 12, 
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Properly distribute legend items across the width
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(child: _buildCategoryLegend('P', 'Produce', Colors.green)),
                  Expanded(child: _buildCategoryLegend('M', 'Protein', Colors.red)),
                  Expanded(child: _buildCategoryLegend('G', 'Grain', Colors.orange)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(child: _buildCategoryLegend('D', 'Dairy', Colors.blue)),
                  Expanded(child: _buildCategoryLegend('P', 'Pantry', Colors.purple)),
                  Expanded(child: _buildCategoryLegend('S', 'Spice', Colors.brown)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Ingredients list - not scrollable, just laid out normally
        ...ingredients.map((ingredient) => Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getCategoryColor(ingredient['category']),
              child: Text(
                ingredient['category'][0].toUpperCase(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(ingredient['name']),
            subtitle: Text('${ingredient['quantity']} • ${ingredient['freshness']} condition'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: ingredient['confidence'] > 0.8 ? Colors.green : Colors.orange,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${(ingredient['confidence'] * 100).round()}%',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        )).toList(),
        
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Text(
            'AI Suggestions:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Based on your available ingredients, here are some cooking suggestions:',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 12),
          // Suggestions list - not scrollable, just laid out normally
          ...suggestions.map((suggestion) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    suggestion,
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
        
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => setState(() => _currentStep = 1),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Continue to Questions'),
          ),
        ),
        const SizedBox(height: 24), // Add some bottom padding
      ],
    );
  }

  Widget _buildCategoryLegend(String letter, String category, Color color) {
    return Container(
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                letter,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              category,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionnaireStep() {
    final questions = SmartMealPlannerService.getCustomizationQuestions();
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'A few quick questions to personalize your meal:',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              children: questions.entries.map((entry) {
                return _buildQuestionCard(entry.key, entry.value);
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _canProceedToGeneration() 
                  ? () => setState(() => _currentStep = 2)
                  : null,
              child: const Text('Generate My Meal'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(String questionKey, List<String> options) {
    final questionTitles = {
      'timeAvailable': 'How much time do you have?',
      'cookingSkill': 'What\'s your cooking skill level?',
      'mealTypePreference': 'What type of meal are you in the mood for?',
      'cuisinePreference': 'Any cuisine preference?',
      'dietaryRestrictions': 'Dietary restrictions?',
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              questionTitles[questionKey] ?? questionKey,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options.map((option) {
                final isSelected = _userPreferences[questionKey] == option;
                return FilterChip(
                  label: Text(option),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _userPreferences[questionKey] = option;
                      } else {
                        _userPreferences.remove(questionKey);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipeGenerationStep() {
    if (_isGenerating) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Creating your perfect meal...',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onBackground,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Our AI is analyzing your ingredients, preferences, and nutritional needs',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    if (_mealRecommendation == null) {
      // Auto-start generation when step loads
      WidgetsBinding.instance.addPostFrameCallback((_) => _generateMealRecommendation());
      
      return Center(
        child: CircularProgressIndicator(
          color: Theme.of(context).colorScheme.primary,
        ),
      );
    }

    return _buildRecipeDisplay();
  }

  Widget _buildRecipeDisplay() {
    if (_mealRecommendation == null) return const SizedBox();

    final recipe = _mealRecommendation!;
    final nutrition = recipe['nutrition'];
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            recipe['recipeName'],
            style: TextStyle(
              fontSize: 24, 
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onBackground,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            recipe['description'],
            style: TextStyle(
              fontSize: 16, 
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          
          // Recipe info chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildInfoChip(Icons.schedule, '${recipe['prepTime'] + recipe['cookTime']} min'),
                const SizedBox(width: 8),
                _buildInfoChip(Icons.restaurant, '${recipe['servings']} servings'),
                const SizedBox(width: 8),
                _buildInfoChip(Icons.signal_cellular_alt, recipe['difficulty']),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Nutrition info
          Container(
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
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nutrition (Total Recipe)', 
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildNutritionItem('Calories', '${nutrition['calories']}'),
                      _buildNutritionItem('Protein', '${nutrition['protein']}g'),
                      _buildNutritionItem('Carbs', '${nutrition['carbs']}g'),
                      _buildNutritionItem('Fat', '${nutrition['fat']}g'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Why this recipe explanation
          if (recipe['whyThisRecipe'] != null) ...[
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.lightbulb, 
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Why This Recipe?', 
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      recipe['whyThisRecipe'],
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          const Spacer(),
          
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => setState(() => _currentStep = 0),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                    foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Start Over'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => setState(() => _currentStep = 3),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Save Recipe'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSaveRecipeStep() {
    if (_isSaving) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Saving your recipe...',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onBackground,
              ),
            ),
          ],
        ),
      );
    }

    if (_generatedRecipe == null) {
      // Auto-save when step loads
      WidgetsBinding.instance.addPostFrameCallback((_) => _saveRecipe());
      
      return Center(
        child: CircularProgressIndicator(
          color: Theme.of(context).colorScheme.primary,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle,
            size: 80,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            'Recipe Saved Successfully!',
            style: TextStyle(
              fontSize: 24, 
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onBackground,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Your "${_generatedRecipe!.name}" recipe has been saved to your custom recipes.',
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => CustomRecipeDetailScreen(recipe: _generatedRecipe!),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('View Full Recipe'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _navigateToCustomRecipes,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                    foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('View All Recipes'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _resetAndStartOver,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                    foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Create Another Recipe'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon, 
            size: 16, 
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            text, 
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
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
        
        await _scanIngredients();
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick image: $e');
    }
  }

  Future<void> _scanIngredients() async {
    if (_scannedImage == null) return;
    
    try {
      final result = await IngredientScannerService.scanIngredients(_scannedImage!);
      
      setState(() {
        _scannedIngredients = result;
        _isScanning = false;
      });
    } catch (e) {
      setState(() => _isScanning = false);
      _showErrorSnackBar('Failed to scan ingredients: $e');
    }
  }

  Future<void> _generateMealRecommendation() async {
    if (_scannedIngredients == null) return;
    
    setState(() => _isGenerating = true);
    
    try {
      final ingredients = (_scannedIngredients!['ingredients'] as List)
          .cast<Map<String, dynamic>>();
      
      final result = await SmartMealPlannerService.generateMealRecommendation(
        availableIngredients: ingredients,
        userPreferences: _userPreferences,
      );
      
      setState(() {
        _mealRecommendation = result;
        _isGenerating = false;
      });
    } catch (e) {
      setState(() => _isGenerating = false);
      _showErrorSnackBar('Failed to generate meal recommendation: $e');
    }
  }

  Future<void> _saveRecipe() async {
    if (_mealRecommendation == null) return;
    
    setState(() => _isSaving = true);
    
    try {
      final aiPrompt = 'Ingredients: ${(_scannedIngredients!['ingredients'] as List).map((i) => i['name']).join(', ')}. Preferences: ${_userPreferences.toString()}';
      
      final customRecipe = SmartMealPlannerService.convertToCustomRecipe(
        _mealRecommendation!,
        aiPrompt,
      );
      
      final recipeId = await CustomRecipeService.saveCustomRecipe(customRecipe);
      final savedRecipe = await CustomRecipeService.getRecipeById(recipeId);
      
      setState(() {
        _generatedRecipe = savedRecipe;
        _isSaving = false;
      });
    } catch (e) {
      setState(() => _isSaving = false);
      _showErrorSnackBar('Failed to save recipe: $e');
    }
  }

  bool _canProceedToGeneration() {
    final requiredQuestions = ['timeAvailable', 'cookingSkill'];
    return requiredQuestions.every((q) => _userPreferences.containsKey(q));
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'produce':
        return Colors.green;
      case 'protein':
        return Colors.red;
      case 'grain':
        return Colors.orange;
      case 'dairy':
        return Colors.blue;
      case 'pantry':
        return Colors.purple;
      case 'spice':
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }

  void _resetAndStartOver() {
    setState(() {
      _scannedImage = null;
      _scannedIngredients = null;
      _userPreferences.clear();
      _mealRecommendation = null;
      _generatedRecipe = null;
      _currentStep = 0;
    });
  }

  void _navigateToCustomRecipes() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const CustomRecipesScreen(),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    AlertHelper.showErrorAlert(
      context,
      title: 'Error',
      message: message,
    );
  }
}