import 'package:flutter/material.dart';
import '../services/health_service.dart';
import '../models/health_data.dart';

class HealthPermissionProvider extends ChangeNotifier {
  bool _hasPermissions = false;
  bool _isInitialized = false;
  bool _isLoading = false;
  
  HealthPermissionProvider() {
    debugPrint('[HealthPermissionProvider] Constructor called');
    _initializePermissions();
  }

  bool get hasPermissions {
    debugPrint('[HealthPermissionProvider] hasPermissions getter called: $_hasPermissions');
    return _hasPermissions;
  }
  
  bool get isInitialized {
    debugPrint('[HealthPermissionProvider] isInitialized getter called: $_isInitialized');
    return _isInitialized;
  }
  
  bool get isLoading {
    debugPrint('[HealthPermissionProvider] isLoading getter called: $_isLoading');
    return _isLoading;
  }

  Future<void> _initializePermissions() async {
    debugPrint('[HealthPermissionProvider] _initializePermissions started');
    if (_isInitialized) {
      debugPrint('[HealthPermissionProvider] Already initialized, skipping');
      return;
    }
    
    _isLoading = true;
    debugPrint('[HealthPermissionProvider] Setting isLoading to true, calling notifyListeners');
    notifyListeners();
    
    try {
      debugPrint('[HealthPermissionProvider] Getting HealthService instance');
      final healthService = HealthService.instance;
      
      debugPrint('[HealthPermissionProvider] Calling healthService.hasPermissions()');
      _hasPermissions = await healthService.hasPermissions();
      
      debugPrint('[HealthPermissionProvider] healthService.hasPermissions() returned: $_hasPermissions');
      _isInitialized = true;
      debugPrint('[HealthPermissionProvider] Set isInitialized to true');
    } catch (e) {
      debugPrint('[HealthPermissionProvider] Error initializing health permissions: $e');
      _hasPermissions = false;
      _isInitialized = true;
    } finally {
      _isLoading = false;
      debugPrint('[HealthPermissionProvider] Set isLoading to false, calling notifyListeners');
      debugPrint('[HealthPermissionProvider] Final state - hasPermissions: $_hasPermissions, isInitialized: $_isInitialized, isLoading: $_isLoading');
      notifyListeners();
    }
  }

  Future<bool> requestPermissions() async {
    debugPrint('[HealthPermissionProvider] requestPermissions called');
    if (_hasPermissions) {
      debugPrint('[HealthPermissionProvider] Already have permissions, returning true');
      return true;
    }
    
    _isLoading = true;
    debugPrint('[HealthPermissionProvider] Setting isLoading to true for permission request');
    notifyListeners();
    
    try {
      debugPrint('[HealthPermissionProvider] Getting HealthService instance for permission request');
      final healthService = HealthService.instance;
      
      debugPrint('[HealthPermissionProvider] Calling healthService.requestPermissions()');
      _hasPermissions = await healthService.requestPermissions();
      
      debugPrint('[HealthPermissionProvider] healthService.requestPermissions() returned: $_hasPermissions');
      notifyListeners();
      return _hasPermissions;
    } catch (e) {
      debugPrint('[HealthPermissionProvider] Error requesting health permissions: $e');
      return false;
    } finally {
      _isLoading = false;
      debugPrint('[HealthPermissionProvider] Permission request finished, isLoading set to false');
      debugPrint('[HealthPermissionProvider] Final permission state: $_hasPermissions');
      notifyListeners();
    }
  }

  Future<HealthData> getHealthDataForDate(DateTime date) async {
    debugPrint('[HealthPermissionProvider] getHealthDataForDate called for: $date');
    if (!_hasPermissions) {
      debugPrint('[HealthPermissionProvider] No permissions, returning empty health data');
      return HealthData.empty(date: date);
    }
    
    try {
      debugPrint('[HealthPermissionProvider] Getting health data from service');
      final healthService = HealthService.instance;
      final data = await healthService.getHealthDataForDate(date);
      debugPrint('[HealthPermissionProvider] Health data retrieved successfully');
      return data;
    } catch (e) {
      debugPrint('[HealthPermissionProvider] Error getting health data: $e');
      return HealthData.empty(date: date);
    }
  }

  Future<HealthData> getTodayHealthData() async {
    debugPrint('[HealthPermissionProvider] getTodayHealthData called');
    return getHealthDataForDate(DateTime.now());
  }

  // Force refresh permissions (useful if permissions might have changed externally)
  Future<void> refreshPermissions() async {
    debugPrint('[HealthPermissionProvider] refreshPermissions called');
    _isInitialized = false;
    await _initializePermissions();
  }
} 