import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/food.dart';
import '../services/food_service.dart';
import '../services/database_service.dart';
import '../widgets/nutrition_summary_card.dart';

class AddCompoundScreen extends StatefulWidget {
  final Food? food;

  const AddCompoundScreen({super.key, this.food});

  @override
  State<AddCompoundScreen> createState() => _AddCompoundScreenState();
}

class _AddCompoundScreenState extends State<AddCompoundScreen> {
  final _nameController = TextEditingController();
  final _searchController = TextEditingController();
  final FoodService _foodService = FoodService();
  final Map<int, TextEditingController> _amountControllers = {};
  
  List<Food> catalog = [];
  List<Map<String, dynamic>> components = []; // {food, amount}
  
  bool get isEditing => widget.food != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _nameController.text = widget.food!.name;
      _loadExistingComponents();
    }
    _searchCatalog('');
  }

  Future<void> _loadExistingComponents() async {
    final db = await DatabaseService.instance.database;
    
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT f.*, c.amount 
      FROM components c 
      JOIN foods f ON f.id = c.componentId 
      WHERE c.recipeId = ?
    ''', [widget.food!.id]);
    
    if (maps.isNotEmpty) {
      setState(() {
        components = maps.map((row) {
          final food = Food.fromMap(row);
          final amount = row['amount'] as double;
          
          // Create controller for this component
          _amountControllers[food.id!] = TextEditingController(text: amount > 0 ? amount.toString() : '');
          
          return {
            'food': food,
            'amount': amount,
          };
        }).toList();
      });
    }
  }

  Future<void> _searchCatalog(String query) async {
    final foods = await _foodService.getSimpleFoods();
    
    setState(() {
      if (query.isEmpty) {
        catalog = foods;
      } else {
        catalog = foods.where((food) => 
          food.name.toLowerCase().contains(query.toLowerCase())).toList();
      }
    });
  }

  void _addComponent(Food food) {
    final exists = components.any((comp) => comp['food'].id == food.id);
    if (!exists) {
      // Create a controller for this component
      _amountControllers[food.id!] = TextEditingController(text: '0.0');
      
      setState(() {
        components.add({
          'food': food,
          'amount': 0.0,
        });
      });
    }
  }

  void _updateAmount(int foodId, String value) {
    setState(() {
      final index = components.indexWhere((comp) => comp['food'].id == foodId);
      if (index != -1) {
        components[index]['amount'] = double.tryParse(value) ?? 0.0;
      }
    });
  }

  void _removeComponent(int foodId) {
    setState(() {
      components.removeWhere((comp) => comp['food'].id == foodId);
    });
    
    // Dispose and remove the controller
    _amountControllers[foodId]?.dispose();
    _amountControllers.remove(foodId);
  }

  Map<String, double> get summary {
    if (components.isEmpty) {
      return {
        'weight': 0.0,
        'cal': 0.0,
        'fat': 0.0,
        'carb': 0.0,
        'prot': 0.0,
      };
    }

    double weight = 0, cal = 0, fat = 0, carb = 0, prot = 0;
    
    for (var comp in components) {
      if (comp['food'] == null) continue;
      final food = comp['food'] as Food;
      final amount = comp['amount'] as double;
      
      weight += amount;
      cal += food.calories * amount / 100;
      fat += food.fat * amount / 100;
      carb += food.carbs * amount / 100;
      prot += food.protein * amount / 100;
    }
    
    return {
      'weight': weight,
      'cal': cal,
      'fat': fat,
      'carb': carb,
      'prot': prot,
    };
  }

  bool get canSave {
    bool hasValidName = _nameController.text.trim().isNotEmpty;
    bool hasComponents = components.isNotEmpty;
    bool hasValidAmounts = components.every((comp) => 
      (comp['amount'] as double) > 0);
    
    return hasValidName && hasComponents && hasValidAmounts;
  }

  Future<void> _saveRecipe() async {
    if (!canSave) return;
    
    final db = await DatabaseService.instance.database;
    final totalWeight = summary['weight']!;
    final factor = totalWeight > 0 ? 100 / totalWeight : 0;
    
    final per100 = {
      'cal': summary['cal']! * factor,
      'fat': summary['fat']! * factor,
      'carb': summary['carb']! * factor,
      'prot': summary['prot']! * factor,
    };
    
    await db.transaction((txn) async {
      int? id = isEditing ? widget.food!.id : null;
      
      if (isEditing) {
        await txn.update(
          'foods',
          {
            'name': _nameController.text.trim(),
            'calories': per100['cal'],
            'fat': per100['fat'],
            'carbs': per100['carb'],
            'protein': per100['prot'],
            'defaultPortionSize': totalWeight, 
            'portionDescription': '1 serving', 
          },
          where: 'id = ?',
          whereArgs: [id],
        );
        
        await txn.delete(
          'components',
          where: 'recipeId = ?',
          whereArgs: [id],
        );
      } else {
        final result = await txn.insert(
          'foods',
          {
            'name': _nameController.text.trim(),
            'calories': per100['cal'],
            'fat': per100['fat'],
            'carbs': per100['carb'],
            'protein': per100['prot'],
            'type': 'compound',
            'defaultPortionSize': totalWeight, // Set portion size to total weight
            'portionDescription': '1 serving', // Default description
          },
        );
        
        id = result;
      }
      
      for (var comp in components) {
        await txn.insert(
          'components',
          {
            'recipeId': id,
            'componentId': (comp['food'] as Food).id,
            'amount': comp['amount'],
          },
        );
      }
    });
    
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    for (var controller in _amountControllers.values) {
      controller.dispose();
    }
    
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEditing ? 'Edit Recipe' : 'Add Recipe',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 24),
              
              // Name input
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Name',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _nameController,
                    onChanged: (value) {
                      setState(() {}); // This will refresh the UI and enable/disable save button
                    },
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                      hintText: 'Recipe name',
                      hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    style: TextStyle(
                      fontSize: 18,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Summary
              NutritionSummaryCard(
                nutritionData: {
                  'cal': summary['cal']!,
                  'prot': summary['prot']!,
                  'fat': summary['fat']!,
                  'carb': summary['carb']!,
                },
              ),
              const SizedBox(height: 20),
              
              // Component list
              if (components.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Text(
                    'No components yet',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: components.length,
                  itemBuilder: (context, index) {
                    if (components.isEmpty) return Container();
                    final component = components[index];
                    final food = component['food'] as Food;
                    final amount = component['amount'] as double;
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              food.name,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 80,
                            child: TextField(
                              key: ValueKey('weight_${food.id}'),
                              controller: _amountControllers[food.id!],
                              onChanged: (value) {
                                _updateAmount(food.id!, value);
                              },
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
                              ],
                              textAlign: TextAlign.center,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Theme.of(context).colorScheme.surface,
                                hintText: 'g',
                                hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                              style: TextStyle(
                                fontSize: 16,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          TextButton(
                            onPressed: () => _removeComponent(food.id!),
                            style: TextButton.styleFrom(
                              backgroundColor: const Color(0xFFFF4455),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(22),
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 6,
                                horizontal: 16,
                              ),
                            ),
                            child: const Text(
                              'Remove',
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
              
              const SizedBox(height: 24),
              Text(
                'Add Food',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              
              // Search input
              TextField(
                controller: _searchController,
                onChanged: _searchCatalog,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  hintText: 'Search simple foods…',
                  hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                style: TextStyle(
                  fontSize: 18,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              
              // Catalog
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: catalog.length,
                itemBuilder: (context, index) {
                  final food = catalog[index];
                  
                  return InkWell(
                    onTap: () => _addComponent(food),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            food.name,
                            style: const TextStyle(fontSize: 16),
                          ),
                          Text(
                            '＋',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 32),
              
              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: canSave ? _saveRecipe : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canSave ? Theme.of(context).colorScheme.primary : Colors.grey.shade300,
                    foregroundColor: canSave ? Colors.white : Colors.grey.shade500,
                    disabledBackgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.4),
                    disabledForegroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: 5,
                  ),
                  child: Text(
                    isEditing ? 'Save Changes' : 'Save Recipe',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}