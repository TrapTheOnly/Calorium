import 'package:flutter/material.dart';
import '../models/food.dart';
import '../models/custom_recipe.dart';
import '../services/food_service.dart';
import '../services/custom_recipe_service.dart';
import '../services/imported_recipe_service.dart';
import '../utils/app_layout.dart';
import '../theme/app_theme.dart';
import '../utils/num_format.dart';
import '../widgets/custom_alert.dart';
import '../widgets/ui_kit.dart';
import 'add_food_screen.dart';
import 'add_compound_screen.dart';
import 'log_entry_screen.dart';
import 'barcode_scanner_screen.dart';
import 'ai_meal_planner_screen.dart';
import 'ai_quick_add_screen.dart';
import 'custom_recipe_detail_screen.dart';
import 'imported_recipe_detail_screen.dart';

class InventoryScreen extends StatefulWidget {
  final String? date;
  final bool asTabRoot;

  const InventoryScreen({super.key, this.date, this.asTabRoot = false});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FoodService _foodService = FoodService();
  
  // Search controllers
  final TextEditingController _simpleSearchController = TextEditingController();
  final TextEditingController _compoundSearchController = TextEditingController();
  final TextEditingController _recipesSearchController = TextEditingController();
  
  // Data for each tab
  List<Food> _allSimpleFoods = [];
  List<Food> _filteredSimpleFoods = [];
  List<Food> _allCompoundFoods = [];
  List<Food> _filteredCompoundFoods = [];
  // Compound food ids that were imported from a shared video (get a video badge
  // and open the imported-recipe detail screen instead of the recipe editor).
  Set<int> _importedFoodIds = {};
  List<CustomRecipe> _allCustomRecipes = [];
  List<CustomRecipe> _filteredCustomRecipes = [];
  
  // Tag management for simple foods
  List<String> _availableTags = [];
  final List<String> _selectedTags = [];
  
  // Tag management for AI recipes
  List<String> _availableRecipeTags = [];
  final List<String> _selectedRecipeTags = [];
  
  // Track loading state
  bool _isLoadingSimple = false;
  bool _isLoadingCompound = false;
  bool _isLoadingRecipes = false;
  bool _isLoadingTags = false;
  bool _isLoadingRecipeTags = false;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Listen for tab changes
    _tabController.addListener(_handleTabChange);
    
    // Add search listeners
    _simpleSearchController.addListener(_onSimpleSearchChanged);
    _compoundSearchController.addListener(_onCompoundSearchChanged);
    _recipesSearchController.addListener(_onRecipesSearchChanged);
    
    // Load initial data for first tab
    _loadSimpleFoods();
    _loadAvailableTags();
  }
  
  void _handleTabChange() {
    if (!_tabController.indexIsChanging) {
      switch (_tabController.index) {
        case 0:
          if (_allSimpleFoods.isEmpty && !_isLoadingSimple) {
            _loadSimpleFoods();
            _loadAvailableTags();
          }
          break;
        case 1:
          if (_allCompoundFoods.isEmpty && !_isLoadingCompound) {
            _loadCompoundFoods();
          }
          break;
        case 2:
          if (_allCustomRecipes.isEmpty && !_isLoadingRecipes) {
            _loadCustomRecipes();
            _loadAvailableRecipeTags();
          }
          break;
      }
    }
  }
  
  void _onSimpleSearchChanged() {
    _filterSimpleFoods();
  }
  
  void _onCompoundSearchChanged() {
    _filterCompoundFoods();
  }
  
  void _onRecipesSearchChanged() {
    _filterCustomRecipes();
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
          _allSimpleFoods = foods;
          _isLoadingSimple = false;
        });
        _filterSimpleFoods();
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
      final importedIds = await ImportedRecipeService.getImportedFoodIds();

      if (mounted) {
        setState(() {
          _allCompoundFoods = foods;
          _importedFoodIds = importedIds;
          _isLoadingCompound = false;
        });
        _filterCompoundFoods();
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
          _allCustomRecipes = recipes;
          _isLoadingRecipes = false;
        });
        _filterCustomRecipes();
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
  
  Future<void> _loadAvailableTags() async {
    if (_isLoadingTags) return;
    
    setState(() {
      _isLoadingTags = true;
    });
    
    try {
      final tags = await _foodService.getAllSimpleFoodTags();
      
      if (mounted) {
        setState(() {
          _availableTags = tags;
          _isLoadingTags = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingTags = false;
        });
      }
    }
  }
  
  Future<void> _loadAvailableRecipeTags() async {
    if (_isLoadingRecipeTags) return;
    
    setState(() {
      _isLoadingRecipeTags = true;
    });
    
    try {
      final tags = await CustomRecipeService.getAllCustomRecipeTags();
      
      if (mounted) {
        setState(() {
          _availableRecipeTags = tags;
          _isLoadingRecipeTags = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingRecipeTags = false;
        });
      }
    }
  }
  
  void _filterSimpleFoods() {
    final query = _simpleSearchController.text.toLowerCase();
    
    setState(() {
      _filteredSimpleFoods = _allSimpleFoods.where((food) {
        final matchesSearch = query.isEmpty || food.name.toLowerCase().contains(query);
        final matchesTags = _selectedTags.isEmpty || _selectedTags.every((tag) => food.tags.contains(tag));
        return matchesSearch && matchesTags;
      }).toList();
    });
  }
  
  void _filterCompoundFoods() {
    final query = _compoundSearchController.text.toLowerCase();
    
    setState(() {
      _filteredCompoundFoods = _allCompoundFoods.where((food) {
        return query.isEmpty || food.name.toLowerCase().contains(query);
      }).toList();
    });
  }
  
  void _filterCustomRecipes() {
    final query = _recipesSearchController.text.toLowerCase();
    
    setState(() {
      _filteredCustomRecipes = _allCustomRecipes.where((recipe) {
        final matchesSearch = query.isEmpty || 
               recipe.name.toLowerCase().contains(query) ||
               recipe.description.toLowerCase().contains(query) ||
               recipe.ingredients.join(' ').toLowerCase().contains(query);
        final matchesTags = _selectedRecipeTags.isEmpty || _selectedRecipeTags.every((tag) => recipe.tags.contains(tag));
        return matchesSearch && matchesTags;
      }).toList();
    });
  }
  
  void _toggleTag(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
    });
    _filterSimpleFoods();
  }
  
  void _clearAllTags() {
    setState(() {
      _selectedTags.clear();
    });
    _filterSimpleFoods();
  }
  
  void _toggleRecipeTag(String tag) {
    setState(() {
      if (_selectedRecipeTags.contains(tag)) {
        _selectedRecipeTags.remove(tag);
      } else {
        _selectedRecipeTags.add(tag);
      }
    });
    _filterCustomRecipes();
  }
  
  void _clearAllRecipeTags() {
    setState(() {
      _selectedRecipeTags.clear();
    });
    _filterCustomRecipes();
  }
  
  Future<void> _openImportedRecipe(Food food, Function() onRefresh) async {
    final recipe = await ImportedRecipeService.getByFoodId(food.id!);
    if (!mounted) return;
    if (recipe == null) {
      // Metadata missing — fall back to the standard recipe editor.
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => AddCompoundScreen(food: food)),
      ).then((_) => onRefresh());
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImportedRecipeDetailScreen(recipe: recipe),
      ),
    ).then((_) => onRefresh());
  }

  Future<void> _deleteImportedRecipe(Food food, Function() onRefresh) async {
    final confirm = await AlertHelper.showDeleteConfirmation(context, food.name);
    if (!confirm) return;
    try {
      await ImportedRecipeService.deleteByFoodId(food.id!);
      onRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recipe deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting recipe: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _deleteFood(int id, bool isSimple, String foodName) async {
    final bool confirm = await AlertHelper.showDeleteConfirmation(context, foodName);
    
    if (confirm) {
      try {
        await _foodService.deleteFood(id);
        
        // Refresh the correct list
        if (isSimple) {
          _loadSimpleFoods();
          _loadAvailableTags(); // Refresh tags as well
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

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _simpleSearchController.dispose();
    _compoundSearchController.dispose();
    _recipesSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: PageAppBar(
        title: 'Foods',
        subtitle: widget.date != null
            ? 'Pick a food to log'
            : 'Search and manage your food database',
        automaticallyImplyLeading: !widget.asTabRoot,
      ),
      floatingActionButton: widget.date != null ? null : _buildFab(),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            // Modern Tab Bar
            Container(
              margin: const EdgeInsets.symmetric(
                horizontal: AppLayout.pagePadding,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
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
                  Tab(text: 'Basics'),
                  Tab(text: 'Recipes'),
                  Tab(text: 'AI'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Tab content
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                  // Simple foods tab with search and tags
                  _buildSimpleFoodsTab(),
                  
                  // Compound foods tab with search
                  _buildCompoundFoodsTab(),

                  // AI Recipes tab with search
                  _buildRecipesTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A hovering, tab-aware action button (bottom-right), replacing the old
  /// full-width bottom buttons. On the Simple tab it also exposes a secondary
  /// "Scan barcode" action stacked above the primary button.
  Widget _buildFab() {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, _) {
        switch (_tabController.index) {
          case 0:
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.small(
                  heroTag: 'inv_ai',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        // No date -> inventory-only mode.
                        builder: (context) => const AiQuickAddScreen(),
                      ),
                    ).then((refreshNeeded) {
                      if (refreshNeeded == true) _loadSimpleFoods();
                    });
                  },
                  backgroundColor:
                      Theme.of(context).colorScheme.tertiaryContainer,
                  foregroundColor:
                      Theme.of(context).colorScheme.onTertiaryContainer,
                  child: const Icon(Icons.auto_awesome_rounded),
                ),
                const SizedBox(height: 12),
                FloatingActionButton.small(
                  heroTag: 'inv_scan',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const BarcodeScannerScreen(),
                      ),
                    ).then((refreshNeeded) {
                      if (refreshNeeded == true) _loadSimpleFoods();
                    });
                  },
                  backgroundColor:
                      Theme.of(context).colorScheme.secondaryContainer,
                  foregroundColor:
                      Theme.of(context).colorScheme.onSecondaryContainer,
                  child: const Icon(Icons.qr_code_scanner_rounded),
                ),
                const SizedBox(height: 12),
                FloatingActionButton.extended(
                  heroTag: 'inv_add',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddFoodScreen(),
                      ),
                    ).then((_) => _loadSimpleFoods());
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add food'),
                ),
              ],
            );
          case 1:
            return FloatingActionButton.extended(
              heroTag: 'inv_add',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddCompoundScreen(),
                  ),
                ).then((_) => _loadCompoundFoods());
              },
              icon: const Icon(Icons.layers_rounded),
              label: const Text('Add recipe'),
            );
          case 2:
            return FloatingActionButton.extended(
              heroTag: 'inv_add',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AiMealPlannerScreen(),
                  ),
                ).then((_) => _loadCustomRecipes());
              },
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('New AI recipe'),
            );
          default:
            return const SizedBox.shrink();
        }
      },
    );
  }

  Widget _buildSimpleFoodsTab() {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: TextField(
            controller: _simpleSearchController,
            decoration: InputDecoration(
              hintText: 'Search basics...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _simpleSearchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _simpleSearchController.clear();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Theme.of(context).colorScheme.outline.withOpacity(0.2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Theme.of(context).colorScheme.outline.withOpacity(0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Tags section
        if (_availableTags.isNotEmpty) ...[
          Container(
            height: 38, // Fixed height to match Clear All button
            padding: const EdgeInsets.only(left: 24.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Clear all button if tags are selected
                if (_selectedTags.isNotEmpty) ...[
                  GestureDetector(
                    onTap: _clearAllTags,
                    child: Container(
                      height: 30, // Fixed height
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.clear_all, size: 14, color: Colors.red),
                          const SizedBox(width: 4),
                          Text(
                            'Clear All',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                
                // Tag chips with stable positioning
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _availableTags.map((tag) {
                        final isSelected = _selectedTags.contains(tag);
                        
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: GestureDetector(
                            onTap: () => _toggleTag(tag),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              height: 30, // Fixed height to match Clear All
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: isSelected 
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: isSelected 
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.outline.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    tag,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isSelected 
                                          ? Theme.of(context).colorScheme.onPrimary
                                          : Theme.of(context).colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (isSelected) ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.close,
                                      size: 14,
                                      color: Theme.of(context).colorScheme.onPrimary,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        
        // Food list with animations
        Expanded(
          child: _buildAnimatedFoodsList(
            foods: _filteredSimpleFoods,
                          isLoading: _isLoadingSimple,
                          isSimple: true,
            onRefresh: () {
              _loadSimpleFoods();
              _loadAvailableTags();
            },
            emptyMessage: _simpleSearchController.text.isNotEmpty || _selectedTags.isNotEmpty
                ? 'No basics match your search'
                : 'No basics yet',
          ),
        ),
      ],
    );
  }

  Widget _buildCompoundFoodsTab() {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: TextField(
            controller: _compoundSearchController,
            decoration: InputDecoration(
              hintText: 'Search recipes...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _compoundSearchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _compoundSearchController.clear();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Theme.of(context).colorScheme.outline.withOpacity(0.2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Theme.of(context).colorScheme.outline.withOpacity(0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
            ),
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Food list with animations
        Expanded(
          child: _buildAnimatedFoodsList(
            foods: _filteredCompoundFoods,
                          isLoading: _isLoadingCompound,
                          isSimple: false,
                          onRefresh: _loadCompoundFoods,
            emptyMessage: _compoundSearchController.text.isNotEmpty
                ? 'No recipes match your search'
                : 'No recipes yet',
          ),
        ),
      ],
    );
  }

  Widget _buildRecipesTab() {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: TextField(
            controller: _recipesSearchController,
            decoration: InputDecoration(
              hintText: 'Search AI recipes...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _recipesSearchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _recipesSearchController.clear();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Theme.of(context).colorScheme.outline.withOpacity(0.2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Theme.of(context).colorScheme.outline.withOpacity(0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
            ),
          ),
        ),
        
                  const SizedBox(height: 16),
        
        // Tags section for recipes
        if (_availableRecipeTags.isNotEmpty) ...[
          Container(
            height: 38, // Fixed height to match Clear All button
            padding: const EdgeInsets.only(left: 24.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Clear all button if tags are selected
                if (_selectedRecipeTags.isNotEmpty) ...[
                  GestureDetector(
                    onTap: _clearAllRecipeTags,
                    child: Container(
                      height: 30, // Fixed height
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.clear_all, size: 14, color: Colors.red),
                          const SizedBox(width: 4),
                          Text(
                            'Clear All',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                ],
              ),
            ),
                  ),
                  const SizedBox(width: 8),
                ],
                
                // Tag chips with stable positioning
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _availableRecipeTags.map((tag) {
                        final isSelected = _selectedRecipeTags.contains(tag);
                        
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: GestureDetector(
                            onTap: () => _toggleRecipeTag(tag),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              height: 30, // Fixed height to match Clear All
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: isSelected 
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: isSelected 
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.outline.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    tag,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isSelected 
                                          ? Theme.of(context).colorScheme.onPrimary
                                          : Theme.of(context).colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (isSelected) ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.close,
                                      size: 14,
                                      color: Theme.of(context).colorScheme.onPrimary,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        
        // Recipes list with animations
        Expanded(
          child: _buildAnimatedRecipesList(),
        ),
      ],
    );
  }
  
  Widget _buildFoodsList({
    required List<Food> foods,
    required bool isLoading,
    required bool isSimple,
    required Function() onRefresh,
    required String emptyMessage,
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
              size: 40,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isSimple && (_simpleSearchController.text.isEmpty && _selectedTags.isEmpty)
                  ? 'Add your first food to get started'
                  : !isSimple && _compoundSearchController.text.isEmpty
                      ? 'Add your first recipe to get started'
                      : 'Try adjusting your search or filters',
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
                          'unit': food.unit,
                          'hasServing': food.hasServing,
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
                  ).then((_) {
                    onRefresh();
                    if (isSimple) _loadAvailableTags();
                  });
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
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
                            '${fmtNum(food.calories)} cal per ${food.portionDescription}',
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
                    
                    // Tags for simple foods
                    if (isSimple && food.tags.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: food.tags.map((tag) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              tag,
                              style: TextStyle(
                                fontSize: 10,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          )).toList(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAnimatedRecipesList() {
    if (_isLoadingRecipes) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    if (_filteredCustomRecipes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_awesome,
              size: 40,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              _recipesSearchController.text.isNotEmpty || _selectedRecipeTags.isNotEmpty
                  ? 'No AI recipes match your search'
                  : 'No AI recipes yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _recipesSearchController.text.isNotEmpty || _selectedRecipeTags.isNotEmpty
                  ? 'Try adjusting your search or filters'
                  : 'Create your first AI-generated recipe using the meal planner',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _recipesSearchController.text.isNotEmpty || _selectedRecipeTags.isNotEmpty
                  ? () {
                      _recipesSearchController.clear();
                      _clearAllRecipeTags();
                    }
                  : () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AiMealPlannerScreen()),
                      ).then((_) {
                        _loadCustomRecipes();
                        _loadAvailableRecipeTags();
                      }),
              icon: Icon(_recipesSearchController.text.isNotEmpty || _selectedRecipeTags.isNotEmpty ? Icons.clear : Icons.add),
              label: Text(_recipesSearchController.text.isNotEmpty || _selectedRecipeTags.isNotEmpty ? 'Clear Search & Filters' : 'Create First Recipe'),
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
      onRefresh: () async {
        _loadCustomRecipes();
        _loadAvailableRecipeTags();
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeInOutCubic,
        switchOutCurve: Curves.easeInOutCubic,
        transitionBuilder: (Widget child, Animation<double> animation) {
          return SlideTransition(
            position: animation.drive(
              Tween(
                begin: const Offset(0.0, 0.1),
                end: Offset.zero,
              ).chain(CurveTween(curve: Curves.easeOutCubic)),
            ),
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          );
        },
      child: ListView.builder(
          key: ValueKey(_filteredCustomRecipes.length), // Key changes when list changes
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
          itemCount: _filteredCustomRecipes.length,
        itemBuilder: (context, index) {
            final recipe = _filteredCustomRecipes[index];
            return TweenAnimationBuilder<double>(
              duration: Duration(milliseconds: 200 + (index * 50)), // Staggered animation
              tween: Tween(begin: 0.0, end: 1.0),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: Opacity(
                    opacity: value,
                    child: child,
                  ),
                );
              },
              child: Container(
            margin: const EdgeInsets.only(bottom: 12),
                child: _buildRecipeCard(recipe),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRecipeCard(CustomRecipe recipe) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final servings = recipe.servings == 0 ? 1 : recipe.servings;
    final totalMin = recipe.prepTimeMinutes + recipe.cookTimeMinutes;
    final ingredientPeek = recipe.ingredients
        .take(2)
        .map((i) => i.replaceAll(RegExp(r'\(\s*\)'), '').trim())
        .where((i) => i.isNotEmpty)
        .join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          if (widget.date != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => LogEntryScreen(
                  food: {
                    'id': recipe.foodId,
                    'name': recipe.name,
                  'calories': recipe.calories / servings,
                  'fat': recipe.fat / servings,
                  'carbs': recipe.carbs / servings,
                  'protein': recipe.protein / servings,
                  // Recipe serving == 100 nominal units; pin this here so the
                  // serving multiplier is always 100 regardless of any stale
                  // stored portion size (older AI recipes stored garbage here).
                  'defaultPortionSize': 100.0,
                  'portionDescription': recipe.portionDescription,
                  'unit': 'g',
                  'hasServing': true,
                  },
                  date: widget.date!,
                ),
              ),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CustomRecipeDetailScreen(recipe: recipe),
              ),
            ).then((_) {
              _loadCustomRecipes();
              _loadAvailableRecipeTags();
            });
          }
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: scheme.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            recipe.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (recipe.isFavorite) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.favorite,
                              color: scheme.primary, size: 14),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${fmtWhole(recipe.calories / servings)} kcal · '
                      'P ${fmtWhole(recipe.protein / servings)} · '
                      'C ${fmtWhole(recipe.carbs / servings)} · '
                      'F ${fmtWhole(recipe.fat / servings)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$totalMin min · ${recipe.servings} servings · '
                      '${_capitalizeFirst(recipe.difficulty)}'
                      '${ingredientPeek.isNotEmpty ? ' · $ingredientPeek' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                icon: Icon(Icons.more_vert_rounded,
                    size: 20, color: scheme.onSurfaceVariant),
                onSelected: (v) {
                  if (v == 'delete') _deleteRecipe(recipe);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteRecipe(CustomRecipe recipe) async {
    final bool confirm =
        await AlertHelper.showDeleteConfirmation(context, recipe.name);
    if (confirm && recipe.id != null) {
      try {
        await CustomRecipeService.deleteCustomRecipe(recipe.id!);
        _loadCustomRecipes();
        _loadAvailableRecipeTags();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Recipe deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting recipe: ${e.toString()}')),
          );
        }
      }
    }
  }

  Widget _buildAnimatedFoodsList({
    required List<Food> foods,
    required bool isLoading,
    required bool isSimple,
    required Function() onRefresh,
    required String emptyMessage,
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
              size: 40,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isSimple && (_simpleSearchController.text.isEmpty && _selectedTags.isEmpty)
                  ? 'Add your first food to get started'
                  : !isSimple && _compoundSearchController.text.isEmpty
                      ? 'Add your first recipe to get started'
                      : 'Try adjusting your search or filters',
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
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeInOutCubic,
        switchOutCurve: Curves.easeInOutCubic,
        transitionBuilder: (Widget child, Animation<double> animation) {
          return SlideTransition(
            position: animation.drive(
              Tween(
                begin: const Offset(0.0, 0.1),
                end: Offset.zero,
              ).chain(CurveTween(curve: Curves.easeOutCubic)),
            ),
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          );
        },
        child: ListView.builder(
          key: ValueKey(foods.length), // Key changes when list changes
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
          itemCount: foods.length,
          itemBuilder: (context, index) {
            final food = foods[index];
            return TweenAnimationBuilder<double>(
              duration: Duration(
                milliseconds: 150 + (index.clamp(0, 8) * 30),
              ),
              tween: Tween(begin: 0.0, end: 1.0),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, 12 * (1 - value)),
                  child: Opacity(opacity: value, child: child),
                );
              },
              child: _buildFoodCard(food, isSimple, onRefresh),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFoodCard(Food food, bool isSimple, Function() onRefresh) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final perLabel = food.hasServing
        ? food.portionDescription
        : '100${food.unit}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      clipBehavior: Clip.antiAlias,
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
                    'unit': food.unit,
                    'hasServing': food.hasServing,
                  },
                  date: widget.date!,
                ),
              ),
            );
          } else if (!isSimple && _importedFoodIds.contains(food.id)) {
            _openImportedRecipe(food, onRefresh);
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => food.type == 'simple'
                    ? AddFoodScreen(food: food)
                    : AddCompoundScreen(food: food),
              ),
            ).then((_) {
              onRefresh();
              if (isSimple) _loadAvailableTags();
            });
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(
                  (!isSimple && _importedFoodIds.contains(food.id))
                      ? Icons.play_circle_fill_rounded
                      : food.isLiquid
                          ? Icons.local_drink_rounded
                          : (isSimple ? Icons.restaurant : Icons.layers),
                  color: scheme.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      food.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${fmtWhole(food.calories)} kcal · per $perLabel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (isSimple && food.tags.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: food.tags
                            .take(3)
                            .map((tag) => _miniTag(tag))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),
              _macroPill('P', food.protein, scheme.primary),
              const SizedBox(width: 6),
              _macroPill('C', food.carbs, scheme.tertiary),
              const SizedBox(width: 6),
              _macroPill('F', food.fat, scheme.secondary),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  if (!isSimple && _importedFoodIds.contains(food.id)) {
                    _deleteImportedRecipe(food, onRefresh);
                  } else {
                    _deleteFood(food.id!, isSimple, food.name);
                  }
                },
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniTag(String tag) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        tag,
        style: TextStyle(
          fontSize: 10,
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _macroPill(String label, double value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          fmtWhole(value),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}