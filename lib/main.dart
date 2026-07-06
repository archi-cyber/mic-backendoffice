import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'config/app_config.dart';
import 'services/supabase_service.dart';
import 'services/offline_storage_service.dart';
import 'services/device_token_service.dart';
import 'services/background_task_service.dart';
import 'services/push_notification_handler.dart';
import 'providers/auth_provider.dart';
import 'providers/settings_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/localization/app_localizations.dart';
import 'core/routes/app_router.dart';
import 'core/routes/route_names.dart';
import 'core/navigation/app_navigator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (for FCM)
  bool firebaseInitialized = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseInitialized = true;
    debugPrint('✓ Firebase initialized successfully');

    // CRITICAL: Register background message handler IMMEDIATELY after Firebase init
    // This MUST be done before any other FCM operations and before runApp()
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    debugPrint('✓ Background message handler registered');
  } catch (e) {
    debugPrint('⚠ Error initializing Firebase: $e');
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

  // Initialize FCM and get device token (only if Firebase is initialized)
  // IMPORTANT: Background message handler must be registered BEFORE runApp()
  if (firebaseInitialized) {
    try {
      // Register background message handler first (before any other FCM calls)
      // This is done in PushNotificationHandler.initialize(), but we ensure it's early
      await DeviceTokenService.initialize();
      await PushNotificationHandler.initialize();
    } catch (e) {
      debugPrint('Error initializing FCM: $e');
    }
  } else {
    debugPrint('Skipping FCM initialization - Firebase not available');
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => AuthProvider()..initialize()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settingsProvider, _) {
          return _AppLifecycleWrapper(
            child: MaterialApp(
              navigatorKey: AppNavigator.rootNavigatorKey,
              title: AppConfig.appName,
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: settingsProvider.themeMode,
              locale: settingsProvider.locale,
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
              builder: (context, child) {
                if (settingsProvider.isLoading) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                return child ?? const SizedBox.shrink();
              },
            ),
          );
        },
      ),
    );
  }
}

/// Wrapper widget to monitor app lifecycle and handle token refresh
class _AppLifecycleWrapper extends StatefulWidget {
  final Widget child;

  const _AppLifecycleWrapper({required this.child});

  @override
  State<_AppLifecycleWrapper> createState() => _AppLifecycleWrapperState();
}

class _AppLifecycleWrapperState extends State<_AppLifecycleWrapper>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    switch (state) {
      case AppLifecycleState.resumed:
        // App is active - check and refresh token if needed
        authProvider.setAppActive(true);
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        // App is in background - mark as inactive
        authProvider.setAppActive(false);
        break;
      case AppLifecycleState.hidden:
        authProvider.setAppActive(false);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

// AuthWrapper removed - navigation is now handled by routes
// The splash screen will handle initial navigation logic
