import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'config/app_config.dart';
import 'core/constants/app_colors.dart';
import 'core/localization/app_localizations.dart';
import 'core/navigation/app_navigator.dart';
import 'core/platform/platform_capabilities.dart';
import 'core/routes/app_router.dart';
import 'core/routes/route_names.dart';
import 'core/theme/app_theme.dart';
import 'providers/app_update_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/desktop/desktop_shell.dart';
import 'services/auth_service.dart';
import 'services/connectivity_sync_service.dart';
import 'services/settings_service.dart';
import 'widgets/update_dialog.dart';

/// Point d'entree de l application.
///
/// Supabase a disparu. L initialisation se limite a creer le client HTTP et a
/// lui indiquer quoi faire quand une session expire.
///
/// Firebase n est plus initialise ici : les notifications arrivent en temps
/// reel par Socket.IO tant que l application est ouverte, et le push ne sert
/// qu a prevenir un utilisateur dont l application est fermee. Si tu l actives
/// plus tard, remets l initialisation Firebase avant AuthService.initialize.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Le client HTTP est cree avant runApp : les providers en dependent des leur
  // construction.
  //
  // Le rappel onSessionExpired se declenche quand les jetons ne peuvent plus
  // etre renouveles — compte desactive, mot de passe change ailleurs, session
  // revoquee. Il ramene l utilisateur a l ecran de connexion depuis n importe
  // quel point de l application.
  AuthService.initialize(
    onSessionExpired: () {
      AppNavigator.rootNavigatorKey.currentState?.pushNamedAndRemoveUntil(
        RouteNames.login,
        (_) => false,
      );
    },
  );

  unawaited(ConnectivitySyncService.instance.initialize());

  final initialLocale = await SettingsService.loadResolvedLocale();

  runApp(MyApp(initialLocale: initialLocale));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.initialLocale});

  final Locale? initialLocale;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) =>
              SettingsProvider(initialLocale: widget.initialLocale)
                ..initialize(),
        ),
        ChangeNotifierProvider(create: (_) => AuthProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => AppUpdateProvider()),
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
              localeResolutionCallback: (deviceLocale, supported) {
                return settingsProvider.locale;
              },
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
                  return const SafeArea(
                    child: Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }
                final content = child ?? const SizedBox.shrink();
                return SafeArea(
                  child: ValueListenableBuilder<bool>(
                    valueListenable:
                        ConnectivitySyncService.instance.onlineNotifier,
                    builder: (context, isOnline, _) {
                      final width = MediaQuery.sizeOf(context).width;
                      final showMobileOfflineBanner =
                          !isOnline && width < kDesktopBreakpoint;
                      if (!showMobileOfflineBanner) return content;
                      return Column(
                        children: [
                          MaterialBanner(
                            content: Text(
                              context.tr(
                                'You are offline. Changes will sync when you reconnect.',
                              ),
                            ),
                            leading: const Icon(
                              Icons.cloud_off,
                              color: AppColors.warning,
                            ),
                            backgroundColor:
                                AppColors.warning.withValues(alpha: 0.12),
                            actions: const [SizedBox.shrink()],
                          ),
                          Expanded(child: content),
                        ],
                      );
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// Wrapper widget to monitor app lifecycle (connectivity and update checks)
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

  /// Au retour au premier plan : réseau et mises à jour. Les jetons sont
  /// rafraîchis par `ApiClient` à la demande, sans surveillance ici.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;

    unawaited(ConnectivitySyncService.instance.refresh());
    final updateProvider =
        Provider.of<AppUpdateProvider>(context, listen: false);
    unawaited(updateProvider.onAppResumed());
    if (PlatformCapabilities.supportsAppUpdates &&
        !updateProvider.isBusy &&
        !updateProvider.showsProgressUi) {
      // Force check on resume so a just-published release is noticed.
      // Use post-frame + root navigator (this State sits above MaterialApp).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(UpdateDialog.showIfAvailable(null, forceCheck: true));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

// AuthWrapper removed - navigation is now handled by routes
// The splash screen will handle initial navigation logic
