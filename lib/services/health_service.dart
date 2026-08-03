import 'dart:io' show Platform;
import 'package:health/health.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/health_data.dart';

/// A single body-weight reading (kg) sourced from Health Connect.
class WeightPoint {
  WeightPoint(this.date, this.kg);
  final DateTime date;
  final double kg;
}

class HealthService {
  static final HealthService _instance = HealthService._internal();
  static HealthService get instance => _instance;
  HealthService._internal();

  final Health _health = Health();
  
  // Updated Health data types for Health Connect compatibility  
  static const List<HealthDataType> _dataTypes = [
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.TOTAL_CALORIES_BURNED,
    HealthDataType.WORKOUT,
    HealthDataType.DISTANCE_DELTA,
  ];

  // Permissions for reading health data
  static const List<HealthDataAccess> _permissions = [
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
  ];

  bool _isConfigured = false;
  bool _hasPermissions = false;

  /// Initialize and configure the health service
  Future<bool> initialize() async {
    try {
      // Configure the Health plugin before use
      await _health.configure();
      _isConfigured = true;
      
      // Check existing permissions
      await _checkStoredPermissions();
      
      debugPrint('Health Connect initialized successfully');
      return true;
    } catch (e) {
      debugPrint('Error initializing Health Service: $e');
      return false;
    }
  }

  /// Check stored permissions from SharedPreferences
  Future<void> _checkStoredPermissions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedPermissions = prefs.getBool('health_permissions_granted') ?? false;
      
      if (storedPermissions) {
        // Verify permissions are still valid
        final bool? hasPerms = await _health.hasPermissions(_dataTypes);
        _hasPermissions = hasPerms ?? false;
        
        if (!_hasPermissions) {
          // Permissions were revoked, clear stored state
          await prefs.setBool('health_permissions_granted', false);
        }
      }
      
      debugPrint('Stored permissions status: $storedPermissions, Current: $_hasPermissions');
    } catch (e) {
      debugPrint('Error checking stored permissions: $e');
    }
  }

  /// Store permission status
  Future<void> _storePermissionStatus(bool granted) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('health_permissions_granted', granted);
      debugPrint('Stored permission status: $granted');
    } catch (e) {
      debugPrint('Error storing permission status: $e');
    }
  }

  /// Check if health permissions are granted
  Future<bool> hasPermissions() async {
    if (!_isConfigured) {
      debugPrint('HealthService not configured, initializing...');
      await initialize();
    }
    
    // First check stored permissions from SharedPreferences
    await _checkStoredPermissions();
    
    // If we have stored permissions, verify they're still valid
    if (_hasPermissions) {
      try {
        final bool? hasPerms = await _health.hasPermissions(_dataTypes);
        final currentPerms = hasPerms ?? false;
        
        // If permissions were revoked, update stored state
        if (!currentPerms) {
          _hasPermissions = false;
          await _storePermissionStatus(false);
          debugPrint('Permissions were revoked, updated stored state');
        }
        
        debugPrint('Has permissions (from stored): $_hasPermissions, verified: $currentPerms');
        return _hasPermissions;
      } catch (e) {
        debugPrint('Error verifying permissions: $e');
        return _hasPermissions; // Return stored value if verification fails
      }
    }
    
    // If no stored permissions, check directly with health plugin
    try {
      final bool? hasPerms = await _health.hasPermissions(_dataTypes);
      _hasPermissions = hasPerms ?? false;
      debugPrint('Has permissions (direct check): $_hasPermissions');
      return _hasPermissions;
    } catch (e) {
      debugPrint('Error checking permissions: $e');
      return false;
    }
  }

  /// Request health permissions (only if not already granted)
  Future<bool> requestPermissions() async {
    if (!_isConfigured) {
      await initialize();
    }
    
    // Check if we already have permissions
    if (_hasPermissions) {
      debugPrint('Permissions already granted, skipping request');
      return true;
    }
    
    try {
      debugPrint('Requesting Health Connect permissions...');
      _hasPermissions = await _health.requestAuthorization(_dataTypes, permissions: _permissions);
      
      // Store permission status
      await _storePermissionStatus(_hasPermissions);
      
      // Request historical data access
      if (_hasPermissions) {
        try {
          debugPrint('Requesting historical data access...');
          await _health.requestHealthDataHistoryAuthorization();
          debugPrint('Historical data access requested successfully');
        } catch (e) {
          debugPrint('Error requesting historical data access: $e');
        }

        // Also request nutrition WRITE so logged meals are shared back to
        // Health Connect for other apps (Google Health, etc.) to read.
        try {
          await requestNutritionWritePermission();
        } catch (e) {
          debugPrint('Error requesting nutrition write access: $e');
        }
      }
      
      debugPrint('Permissions granted: $_hasPermissions');
      return _hasPermissions;
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
      return false;
    }
  }

  /// Get health data for a specific date with precise time range
  Future<HealthData> getHealthDataForDate(DateTime date) async {
    if (!_hasPermissions && !await hasPermissions()) {
      debugPrint('Health permissions not granted');
      return HealthData.empty(date: date);
    }

    try {
      // Use exact date boundaries to avoid adjacent day data
      final DateTime startOfDay = DateTime(date.year, date.month, date.day);
      final DateTime endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

      debugPrint('Fetching health data for exact date: $startOfDay to $endOfDay');

      // Fetch health data points
      List<HealthDataPoint> healthDataPoints = await _health.getHealthDataFromTypes(
        types: _dataTypes,
        startTime: startOfDay,
        endTime: endOfDay,
      );

      // Remove exact duplicate records that the plugin may surface more than once.
      try {
        healthDataPoints = _health.removeDuplicates(healthDataPoints);
      } catch (e) {
        debugPrint('removeDuplicates failed: $e');
      }

      debugPrint('Found ${healthDataPoints.length} health data points for ${date.toIso8601String().split('T')[0]}');

      // Steps: use Health Connect's aggregate total, which de-duplicates
      // overlapping records written by multiple providers (e.g. Heytap Health
      // + Google Fit both syncing into Health Connect). Falls back to the
      // single-source heuristic in [_processHealthData] if unavailable.
      int? aggregatedSteps;
      try {
        aggregatedSteps = await _health.getTotalStepsInInterval(startOfDay, endOfDay);
        debugPrint('Aggregated steps (Health Connect): $aggregatedSteps');
      } catch (e) {
        debugPrint('getTotalStepsInInterval failed: $e');
      }

      return _processHealthData(healthDataPoints, date, aggregatedSteps: aggregatedSteps);
    } catch (e) {
      debugPrint('Error fetching health data: $e');
      return HealthData.empty(date: date);
    }
  }

  /// Picks the single provider ("source") that contributes the most energy for
  /// the day. When several apps mirror the same data into Health Connect,
  /// summing every source inflates the totals — so we attribute calories,
  /// workouts and distance to one primary source instead of adding them all.
  String? _pickPrimarySource(List<HealthDataPoint> points, String targetDateString) {
    final Map<String, double> caloriesBySource = {};
    for (final point in points) {
      if (point.dateFrom.toIso8601String().split('T')[0] != targetDateString) {
        continue;
      }
      if (point.type != HealthDataType.ACTIVE_ENERGY_BURNED &&
          point.type != HealthDataType.TOTAL_CALORIES_BURNED) {
        continue;
      }
      if (point.value is NumericHealthValue) {
        final value = (point.value as NumericHealthValue).numericValue.toDouble();
        caloriesBySource[point.sourceName] =
            (caloriesBySource[point.sourceName] ?? 0) + value;
      }
    }

    if (caloriesBySource.isEmpty) return null;

    String? best;
    double bestValue = -1;
    caloriesBySource.forEach((source, value) {
      if (value > bestValue) {
        bestValue = value;
        best = source;
      }
    });
    debugPrint('Primary health source: $best (${bestValue.round()} kcal) '
        'among ${caloriesBySource.keys.toList()}');
    return best;
  }

  /// Get health data for today
  Future<HealthData> getTodayHealthData() async {
    return getHealthDataForDate(DateTime.now());
  }

  // ---------------------------------------------------------------------------
  // Body weight (kept separate from the activity permission set so that reading
  // weight is optional and doesn't disturb existing steps/energy permissions).

  static const List<HealthDataType> _weightTypes = [HealthDataType.WEIGHT];

  /// Ensures we can read body weight, requesting authorization lazily.
  Future<bool> _ensureWeightAuth() async {
    if (!_isConfigured) await initialize();
    try {
      final bool has = (await _health.hasPermissions(_weightTypes)) ?? false;
      if (has) return true;
      return await _health.requestAuthorization(
        _weightTypes,
        permissions: const [HealthDataAccess.READ],
      );
    } catch (e) {
      debugPrint('Weight authorization error: $e');
      return false;
    }
  }

  /// Most recent body weight (kg) within [lookbackDays], or null if none.
  Future<double?> getLatestWeightKg({int lookbackDays = 365}) async {
    final series = await getWeightSeries(
      DateTime.now().subtract(Duration(days: lookbackDays)),
      DateTime.now(),
    );
    if (series.isEmpty) return null;
    return series.last.kg;
  }

  // ---------------------------------------------------------------------------
  // Nutrition write — expose our logged meals to Health Connect so other apps
  // (Google Health, etc.) can read the calories/macros we record.

  static const List<HealthDataType> _nutritionTypes = [
    HealthDataType.NUTRITION,
  ];

  /// Whether we already hold write access for nutrition.
  Future<bool> hasNutritionWritePermission() async {
    if (!_isConfigured) await initialize();
    try {
      return (await _health.hasPermissions(
            _nutritionTypes,
            permissions: const [HealthDataAccess.WRITE],
          )) ??
          false;
    } catch (e) {
      debugPrint('Nutrition write permission check failed: $e');
      return false;
    }
  }

  /// Prompts for write access to nutrition (call from a settings action).
  Future<bool> requestNutritionWritePermission() async {
    if (!_isConfigured) await initialize();
    try {
      return await _health.requestAuthorization(
        _nutritionTypes,
        permissions: const [HealthDataAccess.WRITE],
      );
    } catch (e) {
      debugPrint('Nutrition write authorization error: $e');
      return false;
    }
  }

  /// Writes a single logged meal to Health Connect. No-ops silently when not on
  /// mobile or when write permission hasn't been granted (so it never prompts
  /// or throws on the logging hot path).
  Future<bool> writeMeal({
    required String name,
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
    required DateTime time,
  }) async {
    if (!(Platform.isAndroid || Platform.isIOS)) return false;
    try {
      if (!_isConfigured) await initialize();
      if (!await hasNutritionWritePermission()) return false;
      return await _health.writeMeal(
        mealType: MealType.UNKNOWN,
        startTime: time,
        endTime: time.add(const Duration(minutes: 1)),
        name: name,
        caloriesConsumed: calories,
        protein: protein,
        carbohydrates: carbs,
        fatTotal: fat,
        recordingMethod: RecordingMethod.manual,
      );
    } catch (e) {
      debugPrint('writeMeal failed: $e');
      return false;
    }
  }

  /// Body-weight readings (kg) within [start, end], sorted oldest first.
  Future<List<WeightPoint>> getWeightSeries(
    DateTime start,
    DateTime end,
  ) async {
    if (!await _ensureWeightAuth()) return [];
    try {
      var points = await _health.getHealthDataFromTypes(
        types: _weightTypes,
        startTime: start,
        endTime: end,
      );
      try {
        points = _health.removeDuplicates(points);
      } catch (_) {}
      final result = <WeightPoint>[];
      for (final p in points) {
        if (p.value is NumericHealthValue) {
          final kg = (p.value as NumericHealthValue).numericValue.toDouble();
          if (kg > 0) result.add(WeightPoint(p.dateFrom, kg));
        }
      }
      result.sort((a, b) => a.date.compareTo(b.date));
      return result;
    } catch (e) {
      debugPrint('Error fetching weight series: $e');
      return [];
    }
  }

  /// Process raw health data points into structured HealthData.
  ///
  /// [aggregatedSteps] is Health Connect's de-duplicated step total; when
  /// provided it is used verbatim. Calories, workouts and distance are only
  /// counted from a single primary source to avoid double-counting when
  /// multiple providers mirror the same activity into Health Connect.
  HealthData _processHealthData(
    List<HealthDataPoint> dataPoints,
    DateTime date, {
    int? aggregatedSteps,
  }) {
    double totalWorkoutTime = 0;
    double totalCaloriesBurned = 0;
    int totalSteps = 0;
    List<WorkoutSession> workoutSessions = [];
    double totalDistance = 0;

    debugPrint('Processing ${dataPoints.length} data points for date: ${date.toIso8601String().split('T')[0]}');

    // Strict date filtering - only include data from the exact target date
    final targetDateString = date.toIso8601String().split('T')[0];

    // Attribute energy/workout/distance to a single provider to prevent
    // multi-source inflation (e.g. Heytap Health + Google Fit).
    final String? primarySource = _pickPrimarySource(dataPoints, targetDateString);

    // Track steps per source so we can take the largest single source and avoid
    // double-counting the same walk mirrored by several apps.
    final Map<String, int> stepsBySource = {};

    // Process each data point with strict date filtering
    for (final point in dataPoints) {
      final pointDateString = point.dateFrom.toIso8601String().split('T')[0];
      
      // Skip data points that are not from the target date
      if (pointDateString != targetDateString) {
        debugPrint('Skipping data point from different date: $pointDateString (target: $targetDateString)');
        continue;
      }

      // For everything except steps (handled via aggregate), restrict to the
      // primary source so mirrored records are not counted twice.
      final bool isPrimary = primarySource == null || point.sourceName == primarySource;

      switch (point.type) {
        case HealthDataType.STEPS:
          if (point.value is NumericHealthValue) {
            final value = (point.value as NumericHealthValue).numericValue.round();
            stepsBySource[point.sourceName] =
                (stepsBySource[point.sourceName] ?? 0) + value;
          }
          break;
        
        case HealthDataType.ACTIVE_ENERGY_BURNED:
          if (isPrimary && point.value is NumericHealthValue) {
            final value = (point.value as NumericHealthValue).numericValue;
            totalCaloriesBurned += value;
          }
          break;
        
        case HealthDataType.TOTAL_CALORIES_BURNED:
          if (isPrimary && point.value is NumericHealthValue) {
            final value = (point.value as NumericHealthValue).numericValue;
            totalCaloriesBurned += value;
          }
          break;
        
        case HealthDataType.DISTANCE_DELTA:
          if (isPrimary && point.value is NumericHealthValue) {
            final value = (point.value as NumericHealthValue).numericValue;
            totalDistance += value;
          }
          break;
        
        case HealthDataType.WORKOUT:
          if (isPrimary && point.value is WorkoutHealthValue) {
            final workout = point.value as WorkoutHealthValue;
            final duration = point.dateTo.difference(point.dateFrom).inMinutes.toDouble();
            final calories = workout.totalEnergyBurned?.toDouble() ?? 0;
            
            final session = WorkoutSession(
              type: _getWorkoutTypeName(workout.workoutActivityType),
              startTime: point.dateFrom,
              endTime: point.dateTo,
              duration: duration,
              caloriesBurned: calories,
            );
            
            workoutSessions.add(session);
            totalWorkoutTime += duration;
          }
          break;
        
        default:
          debugPrint('Unhandled data type: ${point.type}');
      }
    }

    // Resolve steps by taking the single largest source. Several apps mirror
    // the same walk into Health Connect (e.g. OnePlus Health + Google/Strava),
    // and even Health Connect's own aggregate can sum non-overlapping mirrored
    // records — inflating the count. Trusting one source matches what each
    // individual app reports. Falls back to the aggregate only if we somehow
    // got no per-source step records.
    if (stepsBySource.isNotEmpty) {
      totalSteps = stepsBySource.values.reduce((a, b) => a > b ? a : b);
    } else if (aggregatedSteps != null && aggregatedSteps > 0) {
      totalSteps = aggregatedSteps;
    }

    // Active minutes come ONLY from real workout sessions (single primary
    // source). We deliberately do not estimate them from calorie-burn records,
    // which spanned the whole day and produced bogus "active minutes".

    final healthData = HealthData(
      totalWorkoutTime: totalWorkoutTime,
      totalCaloriesBurned: totalCaloriesBurned,
      totalSteps: totalSteps,
      date: date,
      workoutSessions: workoutSessions,
    );

    debugPrint('Final health data for $targetDateString: Steps: $totalSteps, Calories: ${totalCaloriesBurned.round()}, Workout time: $totalWorkoutTime min, Sessions: ${workoutSessions.length}, Distance: ${(totalDistance/1000).toStringAsFixed(2)} km');
    
    return healthData;
  }

  /// Convert workout activity type to readable name
  String _getWorkoutTypeName(HealthWorkoutActivityType type) {
    switch (type) {
      case HealthWorkoutActivityType.RUNNING:
        return 'Running';
      case HealthWorkoutActivityType.WALKING:
        return 'Walking';
      case HealthWorkoutActivityType.BIKING:
        return 'Cycling';
      case HealthWorkoutActivityType.BASKETBALL:
        return 'Basketball';
      case HealthWorkoutActivityType.SOCCER:
        return 'Football';
      case HealthWorkoutActivityType.TENNIS:
        return 'Tennis';
      case HealthWorkoutActivityType.STRENGTH_TRAINING:
        return 'Strength Training';
      case HealthWorkoutActivityType.YOGA:
        return 'Yoga';
      case HealthWorkoutActivityType.SWIMMING:
        return 'Swimming';
      case HealthWorkoutActivityType.DANCING:
        return 'Dancing';
      case HealthWorkoutActivityType.HIKING:
        return 'Hiking';
      case HealthWorkoutActivityType.BOXING:
        return 'Boxing';
      case HealthWorkoutActivityType.GOLF:
        return 'Golf';
      case HealthWorkoutActivityType.MARTIAL_ARTS:
        return 'Martial Arts';
      case HealthWorkoutActivityType.BADMINTON:
        return 'Badminton';
      case HealthWorkoutActivityType.VOLLEYBALL:
        return 'Volleyball';
      case HealthWorkoutActivityType.HIGH_INTENSITY_INTERVAL_TRAINING:
        return 'HIIT';
      case HealthWorkoutActivityType.PILATES:
        return 'Pilates';
      case HealthWorkoutActivityType.ELLIPTICAL:
        return 'Elliptical';
      case HealthWorkoutActivityType.ROWING:
        return 'Rowing';
      case HealthWorkoutActivityType.STAIR_CLIMBING:
        return 'Stairs';
      default:
        return 'Workout';
    }
  }

  /// Get formatted workout time string
  static String formatWorkoutTime(double minutes) {
    if (minutes < 60) {
      return '${minutes.round()}m';
    } else {
      final hours = (minutes / 60).floor();
      final remainingMinutes = (minutes % 60).round();
      if (remainingMinutes == 0) {
        return '${hours}h';
      } else {
        return '${hours}h ${remainingMinutes}m';
      }
    }
  }

  /// Get formatted calories string
  static String formatCalories(double calories) {
    if (calories < 1000) {
      return '${calories.round()} kcal';
    } else {
      return '${(calories / 1000).toStringAsFixed(1)}k kcal';
    }
  }

  /// Get formatted steps string
  static String formatSteps(int steps) {
    if (steps < 1000) {
      return '$steps steps';
    } else {
      return '${(steps / 1000).toStringAsFixed(1)}k steps';
    }
  }

  /// Clear stored permissions (useful for testing or when permissions change)
  Future<void> clearStoredPermissions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('health_permissions_granted');
      _hasPermissions = false;
      debugPrint('Cleared stored permissions');
    } catch (e) {
      debugPrint('Error clearing stored permissions: $e');
    }
  }

  /// Test data processing logic with sample data
  void testDataProcessing() {
    debugPrint('=== TESTING HEALTH DATA PROCESSING ===');
    debugPrint('Expected Results for June 8th:');
    debugPrint('- Steps: 3,800 (Samsung Health shows)');
    debugPrint('- Calories: ~322 kcal (sum of all entries)');
    debugPrint('- Workout time: ~61 minutes (estimated from calories)');
    debugPrint('=========================================');
  }
} 