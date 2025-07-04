// lib/widgets/nutrition_summary_card.dart
import 'package:flutter/material.dart';
import '../services/settings_service.dart';

class NutritionSummaryCard extends StatefulWidget {
  final Map<String, double> nutritionData;
  final VoidCallback? onSetTargetsTap;

  const NutritionSummaryCard({
    super.key,
    required this.nutritionData,
    this.onSetTargetsTap,
  });

  @override
  _NutritionSummaryCardState createState() => _NutritionSummaryCardState();
}

class _NutritionSummaryCardState extends State<NutritionSummaryCard> {
  double _dailyCalorieTarget = 0;
  double _dailyProteinTarget = 0;
  double _dailyFatTarget = 0;
  double _dailyCarbTarget = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTargets();
  }

  @override
  void didUpdateWidget(NutritionSummaryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload targets when nutrition data changes to ensure consistency
    if (oldWidget.nutritionData != widget.nutritionData) {
      _loadTargets();
    }
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
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 0),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: SizedBox(
            height: 150,
            child: const Center(child: CircularProgressIndicator()),
          ),
        ),
      );
    }

    final hasTargets = _dailyCalorieTarget > 0 && 
                      _dailyProteinTarget > 0 && 
                      _dailyFatTarget > 0 && 
                      _dailyCarbTarget > 0;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 0),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.analytics_outlined,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Today\'s Progress',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  if (!hasTargets)
                    TextButton(
                      onPressed: widget.onSetTargetsTap,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        'Set Targets',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              if (hasTargets) ...[
                _buildNutrientBar(
                  context,
                  'Calories',
                  widget.nutritionData['cal'] ?? 0,
                  _dailyCalorieTarget,
                  'kcal',
                  Icons.local_fire_department,
                  Colors.orange,
                ),
                const SizedBox(height: 16),
                _buildNutrientBar(
                  context,
                  'Protein',
                  widget.nutritionData['prot'] ?? 0,
                  _dailyProteinTarget,
                  'g',
                  Icons.fitness_center,
                  Colors.red,
                ),
                const SizedBox(height: 16),
                _buildNutrientBar(
                  context,
                  'Carbs',
                  widget.nutritionData['carb'] ?? 0,
                  _dailyCarbTarget,
                  'g',
                  Icons.grain,
                  Colors.amber,
                ),
                const SizedBox(height: 16),
                _buildNutrientBar(
                  context,
                  'Fat',
                  widget.nutritionData['fat'] ?? 0,
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
                      widget.nutritionData['cal']?.toStringAsFixed(0) ?? '0',
                      'kcal',
                      Icons.local_fire_department,
                      Colors.orange,
                    ),
                    _buildNutrientItem(
                      context,
                      'Protein',
                      widget.nutritionData['prot']?.toStringAsFixed(1) ?? '0.0',
                      'g',
                      Icons.fitness_center,
                      Colors.red,
                    ),
                    _buildNutrientItem(
                      context,
                      'Carbs',
                      widget.nutritionData['carb']?.toStringAsFixed(1) ?? '0.0',
                      'g',
                      Icons.grain,
                      Colors.amber,
                    ),
                    _buildNutrientItem(
                      context,
                      'Fat',
                      widget.nutritionData['fat']?.toStringAsFixed(1) ?? '0.0',
                      'g',
                      Icons.opacity,
                      Colors.purple,
                    ),
                  ],
                ),
              ],
            ],
          ),
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
    final progress = target > 0 ? (current / target).clamp(0.0, 1.2) : 0.0;
    final percentage = target > 0 ? (progress * 100).round() : 0;
    final isOverTarget = progress > 1.0;
    
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            Text(
              '${current.toStringAsFixed(current < 10 ? 1 : 0)}/${target.toStringAsFixed(0)}$unit',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isOverTarget 
                  ? Colors.red.shade600 
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Stack(
          children: [
            Container(
              height: 10,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            FractionallySizedBox(
              widthFactor: progress.clamp(0.0, 1.0),
              child: Container(
                height: 10,
                decoration: BoxDecoration(
                  color: isOverTarget ? Colors.red.shade400 : color,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
            if (isOverTarget)
              FractionallySizedBox(
                widthFactor: 1.0,
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.red.shade400,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$percentage%',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isOverTarget 
                  ? Colors.red.shade600 
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (isOverTarget)
              Text(
                'Over target',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.red.shade600,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildNutrientItem(
    BuildContext context,
    String label,
    String value,
    String unit,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                TextSpan(
                  text: unit,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}