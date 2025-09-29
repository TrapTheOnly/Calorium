import 'package:flutter/material.dart';
import '../models/food.dart';
import '../models/custom_recipe.dart';
import '../services/food_service.dart';
import '../services/custom_recipe_service.dart';
import '../widgets/custom_alert.dart';
import 'add_food_screen.dart';
import 'add_compound_screen.dart';
import 'log_entry_screen.dart';
import 'barcode_scanner_screen.dart';
import 'ai_meal_planner_screen.dart';
import 'custom_recipe_detail_screen.dart';

class InventoryScreen extends StatefulWidget {
  final String? date;

  const InventoryScreen({super.key, this.date});

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
      
      if (mounted) {
        setState(() {
          _allCompoundFoods = foods;
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
    _simpleSearchController.dispose();
    _compoundSearchController.dispose();
    _recipesSearchController.dispose();
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
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Search and manage your food database',
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
                  Tab(text: 'Simple'),
                  Tab(text: 'Compound'),
                  Tab(text: 'AI Recipes'),
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
            
            // Bottom Action Buttons
            const SizedBox(height: 16),
            _buildAnimatedButtons(),
            const SizedBox(height: 24),
          ],
        ),
      ),
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
              hintText: 'Search simple foods...',
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
                ? 'No simple foods match your search'
                : 'No simple foods',
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
              hintText: 'Search compound foods...',
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
                ? 'No compound foods match your search'
                : 'No compound foods',
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
              size: 64,
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
                  ? 'Add your first simple food to get started'
                  : !isSimple && _compoundSearchController.text.isEmpty
                      ? 'Add your first compound food to get started'
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
              size: 64,
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
    return Container(
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
                    'id': recipe.foodId,
                    'name': recipe.name,
                    'calories': recipe.calories / recipe.servings,
                    'fat': recipe.fat / recipe.servings,
                    'carbs': recipe.carbs / recipe.servings,
                    'protein': recipe.protein / recipe.servings,
                    'defaultPortionSize': recipe.defaultPortionSize,
                    'portionDescription': recipe.portionDescription,
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
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  // Recipe icon with difficulty indicator
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _getDifficultyColor(recipe.difficulty).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.auto_awesome,
                      color: _getDifficultyColor(recipe.difficulty),
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
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                            if (recipe.isFavorite)
                              Icon(
                                Icons.favorite,
                                color: Colors.red,
                                size: 16,
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${(recipe.calories / recipe.servings).round()} cal per ${recipe.portionDescription} • ${_capitalizeFirst(recipe.difficulty)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${recipe.prepTimeMinutes + recipe.cookTimeMinutes} min total • ${recipe.servings} servings',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Delete button
                  IconButton(
                    onPressed: () async {
                      final bool confirm = await AlertHelper.showDeleteConfirmation(context, recipe.name);
                      
                      if (confirm && recipe.id != null) {
                        try {
                          await CustomRecipeService.deleteCustomRecipe(recipe.id!);
                          _loadCustomRecipes();
                          _loadAvailableRecipeTags();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Recipe deleted')),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error deleting recipe: ${e.toString()}')),
                          );
                        }
                      }
                    },
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
              
              // Tags for recipes
              if (recipe.tags.isNotEmpty) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: recipe.tags.map((tag) => Container(
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
            ? Theme.of(context).colorScheme.surfaceContainerHighest
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
              size: 64,
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
                  ? 'Add your first simple food to get started'
                  : !isSimple && _compoundSearchController.text.isEmpty
                      ? 'Add your first compound food to get started'
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
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          itemCount: foods.length,
          itemBuilder: (context, index) {
            final food = foods[index];
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
                child: _buildFoodCard(food, isSimple, onRefresh),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFoodCard(Food food, bool isSimple, Function() onRefresh) {
    return Container(
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
  }
}