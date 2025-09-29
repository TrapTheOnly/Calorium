import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../models/health_data.dart';

class EnhancedNutritionSummaryCard extends StatefulWidget {
  final Map<String, double> nutritionData;
  final HealthData? healthData;
  final VoidCallback? onSetTargetsTap;
  final VoidCallback? onHealthPermissionTap;

  const EnhancedNutritionSummaryCard({
    super.key,
    required this.nutritionData,
    this.healthData,
    this.onSetTargetsTap,
    this.onHealthPermissionTap,
  });

  @override
  _EnhancedNutritionSummaryCardState createState() => _EnhancedNutritionSummaryCardState();
}

class _EnhancedNutritionSummaryCardState extends State<EnhancedNutritionSummaryCard> {
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
  void didUpdateWidget(EnhancedNutritionSummaryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
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

    final caloriesIntake = widget.nutritionData['cal'] ?? 0;
    final caloriesBurned = widget.healthData?.totalCaloriesBurned ?? 0;
    final netCalories = caloriesIntake - caloriesBurned;
    final hasHealthData = widget.healthData != null && caloriesBurned > 0;

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
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      hasHealthData ? Icons.trending_up_rounded : Icons.analytics_outlined,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasHealthData ? 'Smart Progress' : 'Today\'s Progress',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        if (hasHealthData) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                '${widget.healthData!.totalSteps} steps',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ),
                              Text(
                                ' • ',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ),
                              Text(
                                '${widget.healthData!.totalWorkoutTime.round()} min active',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
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
              
              // Request health permissions if not available
              if (widget.onHealthPermissionTap != null) ...[
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: widget.onHealthPermissionTap,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.blue.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.health_and_safety_rounded,
                          color: Colors.blue,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Connect Health Data for smart tracking',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.blue,
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Main nutrition content
              if (hasTargets) ...[
                // Net Calories Display
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      hasHealthData ? 'Net Calories' : 'Calories',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      hasHealthData 
                        ? '${netCalories.round()}/${_dailyCalorieTarget.round()}kcal'
                        : '${caloriesIntake.round()}/${_dailyCalorieTarget.round()}kcal',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                // Dual-layer calorie progress bar
                _buildDualLayerCalorieBar(context, caloriesIntake, caloriesBurned, netCalories, _dailyCalorieTarget, hasHealthData),
                
                const SizedBox(height: 20),

                // Macronutrients - full width vertical cards
                _buildVerticalMacroCards(context),
              ] else ...[
                // No targets set message
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.track_changes,
                        size: 32,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Set your daily targets to track progress',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDualLayerCalorieBar(
    BuildContext context,
    double intake,
    double burned,
    double net,
    double target,
    bool hasHealthData,
  ) {
    final intakeProgress = target > 0 ? (intake / target).clamp(0.0, 1.0) : 0.0;
    final netProgress = target > 0 ? (net / target).clamp(0.0, 1.0) : 0.0;
    
    final displayProgress = hasHealthData ? netProgress : intakeProgress;
    final percentage = target > 0 ? (displayProgress * 100).round() : 0;

    return Column(
      children: [
        // Progress bar with three clear layers
        Container(
          height: 16,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.4),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                // Background: Full target bar (100%)
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                // Layer 1: Intake progress (main color)
                FractionallySizedBox(
                  widthFactor: intakeProgress,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                // Layer 2: Net calories overlay (different color on top)
                if (hasHealthData)
                  FractionallySizedBox(
                    widthFactor: netProgress,
                    child: Container(
                      decoration: BoxDecoration(
                        color: netProgress > 1.0 
                          ? Colors.red
                          : Colors.green.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Clear legend and values
        if (hasHealthData) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left side - Progress percentage
              Text(
                '$percentage% of target',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              // Right side - Burned calories
              Text(
                'Burned: ${burned.round()} kcal',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              // Intake legend
              Container(
                width: 12,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Intake: ${intake.round()} kcal',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(width: 16),
              // Net legend
              Container(
                width: 12,
                height: 4,
                decoration: BoxDecoration(
                  color: netProgress > 1.0 
                    ? Colors.red
                    : Colors.green.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Net: ${net.round()} kcal',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ),
            ],
          ),
        ] else ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$percentage% of target',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              Text(
                '${intake.round()} kcal',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildVerticalMacroCards(BuildContext context) {
    return Column(
      children: [
        _buildMacroItem(
          context,
          'Protein',
          widget.nutritionData['prot'] ?? 0,
          _dailyProteinTarget,
          'g',
          Colors.red,
        ),
        const SizedBox(height: 12),
        _buildMacroItem(
          context,
          'Carbs',
          widget.nutritionData['carb'] ?? 0,
          _dailyCarbTarget,
          'g',
          Colors.orange,
        ),
        const SizedBox(height: 12),
        _buildMacroItem(
          context,
          'Fat',
          widget.nutritionData['fat'] ?? 0,
          _dailyFatTarget,
          'g',
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildMacroItem(
    BuildContext context,
    String label,
    double current,
    double target,
    String unit,
    Color color,
  ) {
    final progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    final percentage = target > 0 ? ((current / target) * 100).round() : 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Top row: Label with icon and current/target values
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              Text(
                '${current.round()}/$target$unit',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$percentage%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar spanning full width
          LinearProgressIndicator(
            value: progress,
            backgroundColor: color.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ],
      ),
    );
  }
} 