// lib/widgets/nutrition_summary_card.dart
import 'package:flutter/material.dart';
import '../services/settings_service.dart';

class NutritionSummaryCard extends StatefulWidget {
  final Map<String, double> nutritionData;
  final VoidCallback? onSetTargetsTap;

  const NutritionSummaryCard({
    Key? key,
    required this.nutritionData,
    this.onSetTargetsTap,
  }) : super(key: key);

  @override
  _NutritionSummaryCardState createState() => _NutritionSummaryCardState();
}

class _NutritionSummaryCardState extends State<NutritionSummaryCard> {
  late Map<String, double> _nutritionData;
  late VoidCallback? _onSetTargetsTap;
  double _dailyCalorieTarget = 0;
  double _dailyProteinTarget = 0;
  double _dailyFatTarget = 0;
  double _dailyCarbTarget = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _nutritionData = widget.nutritionData;
    _onSetTargetsTap = widget.onSetTargetsTap;
    _loadTargets();
  }

  Future<void> _loadTargets() async {
    final calorieTarget = await SettingsService.getCalorieTarget();
    final macroTargets = await SettingsService.getMacroTargets();
    
    if (mounted) {
      setState(() {
        _dailyCalorieTarget = calorieTarget ?? 0;
        if (macroTargets != null) {
          _dailyProteinTarget = macroTargets['protein'] ?? 0;
          _dailyFatTarget = macroTargets['fat'] ?? 0;
          _dailyCarbTarget = macroTargets['carbs'] ?? 0;
        }
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Container(
          height: 150,
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final hasTargets = _dailyCalorieTarget > 0 && 
                      _dailyProteinTarget > 0 && 
                      _dailyFatTarget > 0 && 
                      _dailyCarbTarget > 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.analytics_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Today\'s Progress',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                if (!_isLoading && !hasTargets)
                  TextButton(
                    onPressed: _onSetTargetsTap,
                    child: Text(
                      'Set Targets',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (hasTargets) ...[
              _buildNutrientBar(
                context,
                'Calories',
                _nutritionData['cal'] ?? 0,
                _dailyCalorieTarget,
                'kcal',
                Icons.local_fire_department,
                Colors.orange,
              ),
              const SizedBox(height: 12),
              _buildNutrientBar(
                context,
                'Protein',
                _nutritionData['prot'] ?? 0,
                _dailyProteinTarget,
                'g',
                Icons.fitness_center,
                Colors.red,
              ),
              const SizedBox(height: 12),
              _buildNutrientBar(
                context,
                'Carbs',
                _nutritionData['carb'] ?? 0,
                _dailyCarbTarget,
                'g',
                Icons.grain,
                Colors.amber,
              ),
              const SizedBox(height: 12),
              _buildNutrientBar(
                context,
                'Fat',
                _nutritionData['fat'] ?? 0,
                _dailyFatTarget,
                'g',
                Icons.opacity,
                Colors.purple,
              ),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNutrientItem(
                    context,
                    'Calories',
                    '${_nutritionData['cal']?.toStringAsFixed(0) ?? '0'} kcal',
                    Icons.local_fire_department,
                    Colors.orange,
                  ),
                  _buildNutrientItem(
                    context,
                    'Protein',
                    '${_nutritionData['prot']?.toStringAsFixed(1) ?? '0'}g',
                    Icons.fitness_center,
                    Colors.red,
                  ),
                  _buildNutrientItem(
                    context,
                    'Carbs',
                    '${_nutritionData['carb']?.toStringAsFixed(1) ?? '0'}g',
                    Icons.grain,
                    Colors.amber,
                  ),
                  _buildNutrientItem(
                    context,
                    'Fat',
                    '${_nutritionData['fat']?.toStringAsFixed(1) ?? '0'}g',
                    Icons.opacity,
                    Colors.purple,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNutrientBar(
    BuildContext context,
    String label,
    double current,
    double target,
    String unit,
    IconData icon,
    Color color,
  ) {
    final progress = (current / target).clamp(0.0, 1.0);
    final percentage = (progress * 100).round();
    
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            Text(
              '${current.toStringAsFixed(current < 10 ? 1 : 0)}/${target.toStringAsFixed(0)}$unit',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            FractionallySizedBox(
              widthFactor: progress,
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '$percentage%',
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNutrientItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}