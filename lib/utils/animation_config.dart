import 'package:flutter/material.dart';

class AnimationConfig {
  // Singleton instance
  static final AnimationConfig _instance = AnimationConfig._internal();
  
  factory AnimationConfig() => _instance;
  
  AnimationConfig._internal();
  
  // Default duration for most animations
  final Duration defaultDuration = const Duration(milliseconds: 300);
  
  // Get optimal duration based on device refresh rate
  Duration get optimizedDuration {
    // Simplified refresh rate detection since waitingForFirstFrame is removed
    final refreshRate = 60.0; // Default fallback
    
    // Adjust animation duration for higher refresh rates
    if (refreshRate >= 90) {
      return const Duration(milliseconds: 200);
    } else {
      return const Duration(milliseconds: 300);
    }
  }
  
  // Page transitions with optimized animations
  PageRouteBuilder<T> createPageRoute<T>({
    required WidgetBuilder builder,
    RouteSettings? settings,
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        final tween = Tween(begin: begin, end: end)
            .chain(CurveTween(curve: Curves.easeOutCubic));
        final offsetAnimation = animation.drive(tween);
        
        return SlideTransition(
          position: offsetAnimation,
          child: child,
        );
      },
      transitionDuration: optimizedDuration,
    );
  }
  
  // Fade transitions
  Widget createFadeTransition({
    required Widget child,
    required AnimationController controller,
  }) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: controller,
        curve: Curves.easeIn,
      ),
      child: child,
    );
  }
}