// lib/widgets/nutrition_summary_card.dart
import 'package:flutter/material.dart';

class NutritionSummaryCard extends StatelessWidget {
  final Map<String, double> nutritionData;
  final bool showWeight;
  
  const NutritionSummaryCard({
    Key? key, 
    required this.nutritionData,
    this.showWeight = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primaryContainer,
            Theme.of(context).colorScheme.secondaryContainer,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nutrition Summary',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${nutritionData['cal']!.toStringAsFixed(0)} kcal',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              if (showWeight) 
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${nutritionData['weight']?.toStringAsFixed(0) ?? '0'} g',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildMacroIndicator(
                context,
                'Protein',
                nutritionData['prot']!,
                Colors.green.shade600,
              ),
              _buildMacroIndicator(
                context,
                'Fat',
                nutritionData['fat']!,
                Colors.orange.shade600,
              ),
              _buildMacroIndicator(
                context,
                'Carbs',
                nutritionData['carb']!,
                Colors.blue.shade600,
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildMacroIndicator(
    BuildContext context, 
    String label, 
    double value, 
    Color color
    ) {
    // Check if value exceeds 150g
    final bool isExceeding = value > 150;
    final int displayValue = isExceeding ? 150 : value.round();
    
    return Expanded(
        child: Column(
        children: [
            Stack(
            alignment: Alignment.center,
            children: [
                Container(
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                    children: [
                    Flexible(
                        flex: displayValue,
                        child: Container(
                        decoration: BoxDecoration(
                            color: isExceeding ? Colors.red : color,
                            borderRadius: BorderRadius.circular(4),
                        ),
                        ),
                    ),
                    Flexible(flex: 150 - displayValue, child: Container()),
                    ],
                ),
                ),
                if (isExceeding)
                Positioned(
                    right: 8,
                    child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                    ),
                    child: const Center(
                        child: Text(
                        '!',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                        ),
                        ),
                    ),
                    ),
                ),
            ],
            ),
            const SizedBox(height: 4),
            Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
                Text(
                '$label: ${value.toStringAsFixed(1)}g',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isExceeding ? Colors.red : Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
                ),
                if (isExceeding)
                const SizedBox(width: 4),
                if (isExceeding)
                Tooltip(
                    message: 'Value exceeds recommended amount'
                ),
            ],
            ),
        ],
        ),
    );
    }
}