import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/food.dart';
import '../models/custom_recipe.dart';
import '../services/food_service.dart';
import '../services/custom_recipe_service.dart';
import 'add_food_screen.dart';
import 'add_compound_screen.dart';
import 'log_entry_screen.dart';
import 'barcode_scanner_screen.dart';
import 'ai_meal_planner_screen.dart';
import 'custom_recipe_detail_screen.dart';

class InventoryScreen extends StatefulWidget {
  final String? date;

  const InventoryScreen({Key? key, this.date}) : super(key: key);

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FoodService _foodService = FoodService();
  
  // Separate data for each tab
  List<Food> _simpleFoods = [];
  List<Food> _compoundFoods = [];
  List<CustomRecipe> _customRecipes = [];
  
  // Track loading state
  bool _isLoadingSimple = false;
  bool _isLoadingCompound = false;
  bool _isLoadingRecipes = false;
  
  @override
  void initState() {
    super.initState();
    // 3 tabs now: Simple, Compound, AI Recipes
    _tabController = TabController(length: 3, vsync: this);
    
    // Listen for tab changes
    _tabController.addListener(_handleTabChange);
    
    // Load initial data for first tab
    _loadSimpleFoods();
  }
  
  void _handleTabChange() {
    // Only process after the animation completes
    if (!_tabController.indexIsChanging) {
      switch (_tabController.index) {
        case 0:
          if (_simpleFoods.isEmpty && !_isLoadingSimple) {
            _loadSimpleFoods();
          }
          break;
        case 1:
          if (_compoundFoods.isEmpty && !_isLoadingCompound) {
            _loadCompoundFoods();
          }
          break;
        case 2:
          if (_customRecipes.isEmpty && !_isLoadingRecipes) {
            _loadCustomRecipes();
          }
          break;
      }
    }
  }
  
  Future<void> _loadSimpleFoods() async {
    if (_isLoadingSimple) return;
    
    setState(() {
      _isLoadingSimple = true;
    });
    
    try {
      final foods = await _foodService.getSimpleFoods();
      
      if (mounted) {
        setState(() {
          _simpleFoods = foods;
          _isLoadingSimple = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingSimple = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading simple foods: ${e.toString()}')),
        );
      }
    }
  }
  
  Future<void> _loadCompoundFoods() async {
    if (_isLoadingCompound) return;
    
    setState(() {
      _isLoadingCompound = true;
    });
    
    try {
      final foods = await _foodService.getCompoundFoods();
      
      if (mounted) {
        setState(() {
          _compoundFoods = foods;
          _isLoadingCompound = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingCompound = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading compound foods: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _loadCustomRecipes() async {
    if (_isLoadingRecipes) return;
    
    setState(() {
      _isLoadingRecipes = true;
    });
    
    try {
      final recipes = await CustomRecipeService.getAllCustomRecipes();
      
      if (mounted) {
        setState(() {
          _customRecipes = recipes;
          _isLoadingRecipes = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingRecipes = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading custom recipes: ${e.toString()}')),
        );
      }
    }
  }
  
  Future<void> _deleteFood(int id, bool isSimple, String foodName) async {
    final bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Food'),
        content: Text('Are you sure you want to delete "$foodName"?\n\nThis cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ?? false;
    
    if (confirm) {
      try {
        await _foodService.deleteFood(id);
        
        // Refresh the correct list
        if (isSimple) {
          _loadSimpleFoods();
        } else {
          _loadCompoundFoods();
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Food deleted')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting food: ${e.toString()}')),
        );
      }
    }
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

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

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
        actions: [
          IconButton(
            icon: Icon(Icons.home_outlined, color: Theme.of(context).colorScheme.primary, size: 28),
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Inventory',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onBackground,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Manage your food database and AI recipes',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Modern Tab Bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24.0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: Theme.of(context).colorScheme.onPrimary,
                unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
                labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 14),
                splashBorderRadius: BorderRadius.circular(12),
                indicator: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                padding: const EdgeInsets.all(4),
                tabs: const [
                  Tab(text: 'Simple'),
                  Tab(text: 'Compound'),
                  Tab(text: 'AI Recipes'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Tab content
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // Simple foods tab
                        _buildFoodsList(
                          foods: _simpleFoods,
                          isLoading: _isLoadingSimple,
                          isSimple: true,
                          onRefresh: _loadSimpleFoods,
                        ),
                        
                        // Compound foods tab
                        _buildFoodsList(
                          foods: _compoundFoods,
                          isLoading: _isLoadingCompound,
                          isSimple: false,
                          onRefresh: _loadCompoundFoods,
                        ),

                        // AI Recipes tab
                        _buildRecipesList(),
                      ],
                    ),
                  ),
                  
                  // Bottom Action Buttons
                  const SizedBox(height: 16),
                  _buildAnimatedButtons(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFoodsList({
    required List<Food> foods,
    required bool isLoading,
    required bool isSimple,
    required Function() onRefresh,
  }) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    if (foods.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSimple ? Icons.restaurant : Icons.layers,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No ${isSimple ? 'simple' : 'compound'} foods',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first ${isSimple ? 'simple' : 'compound'} food to get started',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        itemCount: foods.length,
        itemBuilder: (context, index) {
          final food = foods[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
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
            child: InkWell(
              onTap: () {
                if (widget.date != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LogEntryScreen(
                        food: {
                          'id': food.id!,
                          'name': food.name,
                          'calories': food.calories,
                          'fat': food.fat,
                          'carbs': food.carbs,
                          'protein': food.protein,
                          'defaultPortionSize': food.defaultPortionSize,
                          'portionDescription': food.portionDescription,
                        },
                        date: widget.date!,
                      ),
                    ),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => food.type == 'simple'
                          ? AddFoodScreen(food: food)
                          : AddCompoundScreen(food: food),
                    ),
                  ).then((_) => onRefresh());
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Food icon
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isSimple ? Icons.restaurant : Icons.layers,
                        color: Theme.of(context).colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    // Food details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            food.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${food.calories.round()} cal per ${food.portionDescription}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Delete button
                    IconButton(
                      onPressed: () => _deleteFood(food.id!, isSimple, food.name),
                      icon: Icon(
                        Icons.delete_outline,
                        color: Colors.red.withOpacity(0.7),
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.red.withOpacity(0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecipesList() {
    if (_isLoadingRecipes) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    if (_customRecipes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_awesome,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No AI recipes yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first AI-generated recipe using the meal planner',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AiMealPlannerScreen()),
              ).then((_) => _loadCustomRecipes()),
              icon: const Icon(Icons.add),
              label: const Text('Create First Recipe'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: () async => _loadCustomRecipes(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        itemCount: _customRecipes.length,
        itemBuilder: (context, index) {
          final recipe = _customRecipes[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
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
            child: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CustomRecipeDetailScreen(recipe: recipe),
                ),
              ).then((_) => _loadCustomRecipes()),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Recipe icon
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.auto_awesome,
                            color: Theme.of(context).colorScheme.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        
                        // Recipe details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      recipe.name,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                  if (recipe.isFavorite)
                                    Icon(
                                      Icons.favorite,
                                      color: Theme.of(context).colorScheme.primary,
                                      size: 18,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                recipe.description,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Recipe info chips
                    Row(
                      children: [
                        _buildInfoChip(Icons.schedule, '${recipe.totalTimeMinutes}m'),
                        const SizedBox(width: 8),
                        _buildInfoChip(Icons.restaurant, '${recipe.servings}'),
                        const SizedBox(width: 8),
                        _buildInfoChip(
                          Icons.signal_cellular_alt,
                          _capitalizeFirst(recipe.difficulty),
                          color: _getDifficultyColor(recipe.difficulty),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${recipe.calories.round()} cal',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (color ?? Theme.of(context).colorScheme.outline).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (color ?? Theme.of(context).colorScheme.outline).withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon, 
            size: 12, 
            color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAnimatedButtons() {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, child) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: _buildTabSpecificButtons(),
        );
      },
    );
  }

  Widget _buildTabSpecificButtons() {
    switch (_tabController.index) {
      case 0: // Simple foods
        return Row(
          children: [
            Expanded(
              child: _buildActionButton(
                'Add Food',
                Icons.add_circle_outline,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AddFoodScreen()),
                  ).then((_) => _loadSimpleFoods());
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                'Scan Barcode',
                Icons.qr_code_scanner,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const BarcodeScannerScreen()),
                  ).then((refreshNeeded) {
                    if (refreshNeeded == true) {
                      _loadSimpleFoods();
                    }
                  });
                },
                isSecondary: true,
              ),
            ),
          ],
        );
      case 1: // Compound foods
        return _buildActionButton(
          'Add Compound Food',
          Icons.layers,
          () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddCompoundScreen()),
            ).then((_) => _loadCompoundFoods());
          },
        );
      case 2: // AI Recipes
        return _buildActionButton(
          'Create AI Recipe',
          Icons.auto_awesome,
          () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AiMealPlannerScreen()),
            ).then((_) => _loadCustomRecipes());
          },
        );
      default:
        return Container();
    }
  }
  
  Widget _buildActionButton(String text, IconData icon, VoidCallback onTap, {bool isSecondary = false}) {
    return ElevatedButton.icon(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: isSecondary 
            ? Theme.of(context).colorScheme.surfaceVariant
            : Theme.of(context).colorScheme.primary,
        foregroundColor: isSecondary 
            ? Theme.of(context).colorScheme.onSurfaceVariant
            : Theme.of(context).colorScheme.onPrimary,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        minimumSize: const Size.fromHeight(56),
        elevation: isSecondary ? 0 : 2,
      ),
      icon: Icon(icon, size: 20),
      label: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
    );
  }
}