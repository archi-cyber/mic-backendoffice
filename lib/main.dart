import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'config/app_config.dart';
import 'core/localization/app_localizations.dart';
import 'core/navigation/app_navigator.dart';
import 'core/routes/app_router.dart';
import 'core/routes/route_names.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/settings_provider.dart';
import 'services/auth_service.dart';

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

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => AuthProvider()..initialize()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return MaterialApp(
            navigatorKey: AppNavigator.rootNavigatorKey,
            title: AppConfig.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: settings.themeMode,
            locale: settings.locale,
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
          );
        },
      ),
    );
  }
}