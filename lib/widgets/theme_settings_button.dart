import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/theme_provider.dart';

class ThemeSettingsButton extends StatefulWidget {
  const ThemeSettingsButton({super.key});

  @override
  State<ThemeSettingsButton> createState() => _ThemeSettingsButtonState();
}

class _ThemeSettingsButtonState extends State<ThemeSettingsButton> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Stack(
      children: [
        // Theme options
        if (_isOpen) ...[
          // Tap outside to close
          Positioned.fill(
            child: GestureDetector(
              onTap: _toggleMenu,
              behavior: HitTestBehavior.translucent,
              child: Container(color: Colors.transparent),
            ),
          ),
          
          // System theme option
          Positioned(
            bottom: 200,
            right: 16,
            child: ScaleTransition(
              scale: CurvedAnimation(
                parent: _animationController,
                curve: Curves.easeOut,
              ),
              child: FloatingActionButton.small(
                heroTag: 'system_theme',
                backgroundColor: themeProvider.themeOption == ThemeOption.system 
                    ? Theme.of(context).colorScheme.primary 
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                foregroundColor: themeProvider.themeOption == ThemeOption.system 
                    ? Theme.of(context).colorScheme.onPrimary 
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                tooltip: 'Use system theme',
                onPressed: () {
                  themeProvider.setThemeOption(ThemeOption.system);
                  _toggleMenu();
                },
                child: const Icon(Icons.brightness_auto),
              ),
            ),
          ),
          
          // Light theme option
          Positioned(
            bottom: 140,
            right: 16,
            child: ScaleTransition(
              scale: CurvedAnimation(
                parent: _animationController,
                curve: Curves.easeOut,
              ),
              child: FloatingActionButton.small(
                heroTag: 'light_theme',
                backgroundColor: themeProvider.themeOption == ThemeOption.light 
                    ? Theme.of(context).colorScheme.primary 
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                foregroundColor: themeProvider.themeOption == ThemeOption.light 
                    ? Theme.of(context).colorScheme.onPrimary 
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                tooltip: 'Light mode',
                onPressed: () {
                  themeProvider.setThemeOption(ThemeOption.light);
                  _toggleMenu();
                },
                child: const Icon(Icons.light_mode),
              ),
            ),
          ),
          
          // Dark theme option
          Positioned(
            bottom: 80,
            right: 16,
            child: ScaleTransition(
              scale: CurvedAnimation(
                parent: _animationController,
                curve: Curves.easeOut,
              ),
              child: FloatingActionButton.small(
                heroTag: 'dark_theme',
                backgroundColor: themeProvider.themeOption == ThemeOption.dark 
                    ? Theme.of(context).colorScheme.primary 
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                foregroundColor: themeProvider.themeOption == ThemeOption.dark 
                    ? Theme.of(context).colorScheme.onPrimary 
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                tooltip: 'Dark mode',
                onPressed: () {
                  themeProvider.setThemeOption(ThemeOption.dark);
                  _toggleMenu();
                },
                child: const Icon(Icons.dark_mode),
              ),
            ),
          ),
        ],
        
        // Main settings button
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            onPressed: _toggleMenu,
            tooltip: 'Theme settings',
            backgroundColor: _isOpen 
                ? Theme.of(context).colorScheme.tertiary 
                : Theme.of(context).colorScheme.primary,
            foregroundColor: _isOpen 
                ? Theme.of(context).colorScheme.onTertiary 
                : Theme.of(context).colorScheme.onPrimary,
            child: AnimatedIcon(
              icon: AnimatedIcons.menu_close,
              progress: _animationController,
            ),
          ),
        ),
      ],
    );
  }
}