import 'package:flutter/material.dart';
import '../services/health_service.dart';
import '../models/health_data.dart';

class HealthPermissionProvider extends ChangeNotifier {
  bool _hasPermissions = false;
  bool _isInitialized = false;
  bool _isLoading = false;

  HealthPermissionProvider() {
    _initializePermissions();
  }

  bool get hasPermissions => _hasPermissions;

  bool get isInitialized => _isInitialized;

  bool get isLoading => _isLoading;

  Future<void> _initializePermissions() async {
    if (_isInitialized) {
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final healthService = HealthService.instance;

      _hasPermissions = await healthService.hasPermissions();

      _isInitialized = true;
    } catch (e) {
      debugPrint(
        '[HealthPermissionProvider] Error initializing health permissions: $e',
      );
      _hasPermissions = false;
      _isInitialized = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> requestPermissions() async {
    if (_hasPermissions) {
      return true;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final healthService = HealthService.instance;

      _hasPermissions = await healthService.requestPermissions();
      notifyListeners();
      return _hasPermissions;
    } catch (e) {
      debugPrint(
        '[HealthPermissionProvider] Error requesting health permissions: $e',
      );
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<HealthData> getHealthDataForDate(DateTime date) async {
    if (!_hasPermissions) {
      return HealthData.empty(date: date);
    }

    try {
      final healthService = HealthService.instance;
      final data = await healthService.getHealthDataForDate(date);
      return data;
    } catch (e) {
      debugPrint('[HealthPermissionProvider] Error getting health data: $e');
      return HealthData.empty(date: date);
    }
  }

  Future<HealthData> getTodayHealthData() async {
    return getHealthDataForDate(DateTime.now());
  }

  // Force refresh permissions (useful if permissions might have changed externally)
  Future<void> refreshPermissions() async {
    _isInitialized = false;
    await _initializePermissions();
  }
}
