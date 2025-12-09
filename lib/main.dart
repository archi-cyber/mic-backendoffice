import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'config/app_config.dart';
import 'services/supabase_service.dart';
import 'services/offline_storage_service.dart';
import 'services/device_token_service.dart';
import 'services/background_task_service.dart';
import 'services/push_notification_handler.dart';
import 'providers/auth_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/localization/app_localizations.dart';
import 'core/routes/app_router.dart';
import 'core/routes/route_names.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (for FCM)
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Error initializing Firebase: $e');
  }

  // Initialize Supabase
  try {
    await SupabaseService.initialize(
      supabaseUrl: AppConfig.supabaseUrl,
      supabaseAnonKey: AppConfig.supabaseAnonKey,
    );
  } catch (e) {
    debugPrint('Error initializing Supabase: $e');
    debugPrint(
      'Please configure your Supabase credentials in lib/config/app_config.dart',
    );
  }

  // Initialize offline storage
  await OfflineStorageService.database;

  // Initialize background tasks
  try {
    await BackgroundTaskService.initialize();
  } catch (e) {
    debugPrint('Error initializing background tasks: $e');
  }

  // Initialize FCM and get device token
  try {
    await DeviceTokenService.initialize();
    await PushNotificationHandler.initialize();
  } catch (e) {
    debugPrint('Error initializing FCM: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider()..initialize(),
      child: MaterialApp(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        onGenerateRoute: AppRouter.generateRoute,
        onUnknownRoute: AppRouter.onUnknownRoute,
        initialRoute: RouteNames.splash,
      ),
    );
  }
}

// AuthWrapper removed - navigation is now handled by routes
// The splash screen will handle initial navigation logic
