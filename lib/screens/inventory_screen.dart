import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/food.dart';
import '../services/food_service.dart';
import 'add_food_screen.dart';
import 'add_compound_screen.dart';
import 'log_entry_screen.dart';
import 'barcode_scanner_screen.dart';

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
  
  // Track loading state
  bool _isLoadingSimple = false;
  bool _isLoadingCompound = false;
  
  @override
  void initState() {
    super.initState();
    // Reduced to 2 tabs
    _tabController = TabController(length: 2, vsync: this);
    
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
  
  Future<void> _deleteFood(int id, bool isSimple) async {
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Inventory',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onBackground,
                ),
              ),
              const SizedBox(height: 24),
              
              TabBar(
                controller: _tabController,
                labelColor: Theme.of(context).colorScheme.onPrimary,
                unselectedLabelColor: Theme.of(context).colorScheme.onSurface,
                labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
                splashBorderRadius: BorderRadius.circular(24),
                indicator: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(24),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 4),
                tabs: const [
                  Tab(text: 'Simple'),
                  Tab(text: 'Compound'),
                ],
              ),
              const SizedBox(height: 18),
              
              // Tab content with animated buttons
              Expanded(
                child: Stack(
                  children: [
                    TabBarView(
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
                      ],
                    ),
                    
                    // Bottom Action Buttons
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 24,
                      child: _buildAnimatedButtons(),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
            Text(
              'No items',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        itemCount: foods.length,
        itemBuilder: (context, index) {
          final food = foods[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
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
                    child: Text(
                      food.name,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _deleteFood(food.id!, isSimple),
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFFF4455),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 16,
                    ),
                  ),
                  child: const Text(
                    'Del',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildAnimatedButtons() {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, child) {
        // Calculate animation values for tab transitions
        final screenWidth = MediaQuery.of(context).size.width;
        return Stack(
          children: [
            Transform.translate(
              offset: Offset((_tabController.index - 0) * screenWidth, 0),
              child: Opacity(
                opacity: _calculateButtonOpacity(0),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        'Add',
                        Icons.add_circle_outline,
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const AddFoodScreen()),
                          ).then((_) => _loadSimpleFoods());
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildActionButton(
                        'Scan Barcode',
                        Icons.qr_code_outlined,
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const BarcodeScannerScreen()),
                          ).then((refreshNeeded) {
                            if (refreshNeeded == true) {
                              print('Refreshing inventory after barcode scan');
                              _loadSimpleFoods();
                            }
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Compound tab button
            Transform.translate(
              offset: Offset((_tabController.index - 1) * screenWidth, 0),
              child: Opacity(
                opacity: _calculateButtonOpacity(1),
                child: _buildActionButton(
                  'Add Compound',
                  Icons.add_circle_outline,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AddCompoundScreen()),
                    ).then((_) => _loadCompoundFoods());
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
  
  // Calculate button opacity based on tab position and animation value
  double _calculateButtonOpacity(int tabIndex) {
    // If this is the current tab, show fully
    if (_tabController.index == tabIndex) return 1.0;
    
    // If animation is in progress, calculate based on animation value
    if (_tabController.animation != null) {
      final animationValue = _tabController.animation!.value;
      final distance = (animationValue - tabIndex).abs();
      
      // Only show when tab is close to being active
      if (distance < 1.0) {
        return 1.0 - distance;
      }
    }
    
    return 0.0; // Hide otherwise
  }
  
  Widget _buildActionButton(String text, IconData icon, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        minimumSize: const Size.fromHeight(56),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }
}