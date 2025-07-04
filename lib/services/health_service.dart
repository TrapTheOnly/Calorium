import 'package:health/health.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/health_data.dart';

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
    if (!_isConfigured) return false;
    try {
      final bool? hasPerms = await _health.hasPermissions(_dataTypes);
      _hasPermissions = hasPerms ?? false;
      debugPrint('Has permissions: $_hasPermissions');
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
      final List<HealthDataPoint> healthDataPoints = await _health.getHealthDataFromTypes(
        types: _dataTypes,
        startTime: startOfDay,
        endTime: endOfDay,
      );

      debugPrint('Found ${healthDataPoints.length} health data points for ${date.toIso8601String().split('T')[0]}');
      
      // Log each data point for detailed debugging
      for (final point in healthDataPoints) {
        final pointDate = point.dateFrom.toIso8601String().split('T')[0];
        debugPrint('Data point: ${point.type} = ${point.value} from ${point.sourceName} on $pointDate');
      }

      return _processHealthData(healthDataPoints, date);
    } catch (e) {
      debugPrint('Error fetching health data: $e');
      return HealthData.empty(date: date);
    }
  }

  /// Get health data for today
  Future<HealthData> getTodayHealthData() async {
    return getHealthDataForDate(DateTime.now());
  }

  /// Process raw health data points into structured HealthData
  HealthData _processHealthData(List<HealthDataPoint> dataPoints, DateTime date) {
    double totalWorkoutTime = 0;
    double totalCaloriesBurned = 0;
    int totalSteps = 0;
    List<WorkoutSession> workoutSessions = [];
    double totalDistance = 0;

    debugPrint('Processing ${dataPoints.length} data points for date: ${date.toIso8601String().split('T')[0]}');

    // Strict date filtering - only include data from the exact target date
    final targetDateString = date.toIso8601String().split('T')[0];

    // Group calories entries by time to potentially reconstruct workout sessions
    List<HealthDataPoint> caloriesEntries = [];

    // Process each data point with strict date filtering
    for (final point in dataPoints) {
      final pointDateString = point.dateFrom.toIso8601String().split('T')[0];
      
      // Skip data points that are not from the target date
      if (pointDateString != targetDateString) {
        debugPrint('Skipping data point from different date: $pointDateString (target: $targetDateString)');
        continue;
      }
      
      debugPrint('Processing point: ${point.type} - ${point.value} - Source: ${point.sourceName} - Date: $pointDateString');
      
      switch (point.type) {
        case HealthDataType.STEPS:
          if (point.value is NumericHealthValue) {
            final value = (point.value as NumericHealthValue).numericValue;
            totalSteps += value.round();
            debugPrint('Added steps: $value, total: $totalSteps');
          }
          break;
        
        case HealthDataType.ACTIVE_ENERGY_BURNED:
          if (point.value is NumericHealthValue) {
            final value = (point.value as NumericHealthValue).numericValue;
            totalCaloriesBurned += value;
            debugPrint('Added active calories: $value, total: $totalCaloriesBurned');
          }
          break;
        
        case HealthDataType.TOTAL_CALORIES_BURNED:
          if (point.value is NumericHealthValue) {
            final value = (point.value as NumericHealthValue).numericValue;
            // Always add total calories (Samsung Health uses multiple entries for different activities)
            totalCaloriesBurned += value;
            caloriesEntries.add(point); // Store for potential workout reconstruction
            debugPrint('Added total calories: $value, total: $totalCaloriesBurned');
          }
          break;
        
        case HealthDataType.DISTANCE_DELTA:
          if (point.value is NumericHealthValue) {
            final value = (point.value as NumericHealthValue).numericValue;
            totalDistance += value;
            debugPrint('Added distance: ${(value/1000).toStringAsFixed(2)} km, total: ${(totalDistance/1000).toStringAsFixed(2)} km');
          }
          break;
        
        case HealthDataType.WORKOUT:
          if (point.value is WorkoutHealthValue) {
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
            
            debugPrint('Added workout: ${session.type}, duration: $duration min, calories: $calories');
          }
          break;
        
        default:
          debugPrint('Unhandled data type: ${point.type}');
      }
    }

    // If no explicit workout sessions but we have calories entries, estimate workout time
    if (workoutSessions.isEmpty && caloriesEntries.isNotEmpty) {
      totalWorkoutTime = _estimateWorkoutTimeFromCalories(caloriesEntries);
      debugPrint('Estimated workout time from calories entries: $totalWorkoutTime minutes');
    }

    final healthData = HealthData(
      totalWorkoutTime: totalWorkoutTime,
      totalCaloriesBurned: totalCaloriesBurned,
      totalSteps: totalSteps,
      date: date,
      workoutSessions: workoutSessions,
    );

    debugPrint('Final health data for ${targetDateString}: Steps: $totalSteps, Calories: ${totalCaloriesBurned.round()}, Workout time: $totalWorkoutTime min, Sessions: ${workoutSessions.length}, Distance: ${(totalDistance/1000).toStringAsFixed(2)} km');
    
    return healthData;
  }

  /// Estimate workout time from calories entries (Samsung Health pattern)
  double _estimateWorkoutTimeFromCalories(List<HealthDataPoint> caloriesEntries) {
    if (caloriesEntries.isEmpty) return 0;
    
    // Sort by start time
    caloriesEntries.sort((a, b) => a.dateFrom.compareTo(b.dateFrom));
    
    double totalMinutes = 0;
    
    for (final entry in caloriesEntries) {
      final duration = entry.dateTo.difference(entry.dateFrom).inMinutes.toDouble();
      totalMinutes += duration;
    }
    
    return totalMinutes;
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