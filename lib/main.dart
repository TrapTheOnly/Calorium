import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:openfoodfacts/openfoodfacts.dart';
import 'screens/main_shell.dart';
import 'theme/app_theme.dart';
import 'utils/theme_provider.dart';
import 'utils/health_permission_provider.dart';
import 'utils/app_navigator.dart';
import 'services/scheduler_service.dart';
import 'services/share_intent_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  // Initialize notification plugin early; schedule after first frame.
  await SchedulerService.initialize(requestPermissionsOnInit: false);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => HealthPermissionProvider()),
      ],
      child: const MyApp(),
    ),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) {
    SchedulerService.setupScheduledNotifications();
    // Start listening for shared Instagram/YouTube links once the app is up.
    ShareIntentService.init();
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Calorium',
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeProvider.themeMode,
      home: MainShell(key: mainShellKey),
    );
  }
}
