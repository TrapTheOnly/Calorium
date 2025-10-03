import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:openfoodfacts/openfoodfacts.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'screens/home_screen.dart';
import 'utils/theme_provider.dart';
import 'utils/health_permission_provider.dart';
import 'services/scheduler_service.dart';

final GlobalKey<NavigatorState> _appNavigatorKey = GlobalKey<NavigatorState>();

// Import debug service for easy access during development

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SchedulerService.configureNavigator(_appNavigatorKey);

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );

  OpenFoodAPIConfiguration.userAgent = UserAgent(
    name: 'Calorium App - Flutter - Version 1.0',
  );
  OpenFoodAPIConfiguration.globalLanguages = [OpenFoodFactsLanguage.ENGLISH];
  OpenFoodAPIConfiguration.globalCountry = OpenFoodFactsCountry.USA;
  OpenFoodAPIConfiguration.globalUser = User(
    userId: 'calorie_tracker_app',
    password: 'nx9*HCx8RJ3YP&WH',
  );

  // Initialize scheduler service for AI nutrition analysis
  await SchedulerService.initialize();
  await SchedulerService.setupScheduledNotifications();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => HealthPermissionProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        ColorScheme lightScheme;
        ColorScheme darkScheme;

        if (lightDynamic != null && darkDynamic != null) {
          // Use dynamic colors if available
          lightScheme = lightDynamic.harmonized();
          darkScheme = darkDynamic.harmonized();
        } else {
          // Fallback to default colors if dynamic colors are not available
          lightScheme = ColorScheme.fromSeed(
            seedColor: const Color(0xFF4B68FF),
            brightness: Brightness.light,
          );
          darkScheme = ColorScheme.fromSeed(
            seedColor: const Color(0xFF4B68FF),
            brightness: Brightness.dark,
          );
        }

        return MaterialApp(
          title: 'Calorium',
          debugShowCheckedModeBanner: false,

          theme: ThemeData(useMaterial3: true, colorScheme: lightScheme),

          darkTheme: ThemeData(useMaterial3: true, colorScheme: darkScheme),

          themeMode: themeProvider.themeMode,

          navigatorKey: _appNavigatorKey,
          home: const HomeScreen(),
        );
      },
    );
  }
}
