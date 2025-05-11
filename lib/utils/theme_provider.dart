import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ThemeOption {
  light,
  dark,
  system,
}

class ThemeProvider extends ChangeNotifier {
  ThemeOption _themeOption = ThemeOption.system;
  late SharedPreferences _prefs;
  static const String _themeKey = 'theme_preference';

  ThemeProvider() {
    _loadThemePreference();
  }

  ThemeOption get themeOption => _themeOption;

  bool get isDarkMode {
    if (_themeOption == ThemeOption.system) {
      return SchedulerBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
    }
    return _themeOption == ThemeOption.dark;
  }

  ThemeMode get themeMode {
    switch (_themeOption) {
      case ThemeOption.light: return ThemeMode.light;
      case ThemeOption.dark: return ThemeMode.dark;
      case ThemeOption.system: return ThemeMode.system;
    }
  }

  Future<void> _loadThemePreference() async {
    _prefs = await SharedPreferences.getInstance();
    final savedTheme = _prefs.getString(_themeKey);
    
    if (savedTheme != null) {
      _themeOption = ThemeOption.values.firstWhere(
        (e) => e.toString() == savedTheme,
        orElse: () => ThemeOption.system,
      );
      notifyListeners();
    }
  }

  Future<void> setThemeOption(ThemeOption option) async {
    _themeOption = option;
    await _prefs.setString(_themeKey, option.toString());
    
    // Update system UI overlay to match theme
    if (option == ThemeOption.dark || 
        (option == ThemeOption.system && 
         SchedulerBinding.instance.platformDispatcher.platformBrightness == Brightness.dark)) {
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    } else {
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    }
    
    notifyListeners();
  }
}