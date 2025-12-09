import 'package:flutter/material.dart';

/// App localization delegate
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('en', ''), // English
    Locale('es', ''), // Spanish
    Locale('fr', ''), // French
  ];

  // Common
  String get appName =>
      _localizedValues[locale.languageCode]?['appName'] ?? 'SysteMIC';
  String get welcome =>
      _localizedValues[locale.languageCode]?['welcome'] ?? 'Welcome';
  String get loading =>
      _localizedValues[locale.languageCode]?['loading'] ?? 'Loading...';
  String get error =>
      _localizedValues[locale.languageCode]?['error'] ?? 'Error';
  String get success =>
      _localizedValues[locale.languageCode]?['success'] ?? 'Success';
  String get cancel =>
      _localizedValues[locale.languageCode]?['cancel'] ?? 'Cancel';
  String get confirm =>
      _localizedValues[locale.languageCode]?['confirm'] ?? 'Confirm';
  String get save => _localizedValues[locale.languageCode]?['save'] ?? 'Save';
  String get delete =>
      _localizedValues[locale.languageCode]?['delete'] ?? 'Delete';
  String get edit => _localizedValues[locale.languageCode]?['edit'] ?? 'Edit';
  String get search =>
      _localizedValues[locale.languageCode]?['search'] ?? 'Search';
  String get filter =>
      _localizedValues[locale.languageCode]?['filter'] ?? 'Filter';
  String get close =>
      _localizedValues[locale.languageCode]?['close'] ?? 'Close';

  // Authentication
  String get login =>
      _localizedValues[locale.languageCode]?['login'] ?? 'Login';
  String get logout =>
      _localizedValues[locale.languageCode]?['logout'] ?? 'Logout';
  String get email =>
      _localizedValues[locale.languageCode]?['email'] ?? 'Email';
  String get password =>
      _localizedValues[locale.languageCode]?['password'] ?? 'Password';
  String get forgotPassword =>
      _localizedValues[locale.languageCode]?['forgotPassword'] ??
      'Forgot Password?';
  String get signIn =>
      _localizedValues[locale.languageCode]?['signIn'] ?? 'Sign In';
  String get signOut =>
      _localizedValues[locale.languageCode]?['signOut'] ?? 'Sign Out';
  String get emailRequired =>
      _localizedValues[locale.languageCode]?['emailRequired'] ??
      'Email is required';
  String get passwordRequired =>
      _localizedValues[locale.languageCode]?['passwordRequired'] ??
      'Password is required';
  String get invalidEmail =>
      _localizedValues[locale.languageCode]?['invalidEmail'] ??
      'Invalid email format';
  String get loginError =>
      _localizedValues[locale.languageCode]?['loginError'] ??
      'Login failed. Please try again.';

  // Dashboard
  String get dashboard =>
      _localizedValues[locale.languageCode]?['dashboard'] ?? 'Dashboard';
  String get home => _localizedValues[locale.languageCode]?['home'] ?? 'Home';
  String get overview =>
      _localizedValues[locale.languageCode]?['overview'] ?? 'Overview';
  String get statistics =>
      _localizedValues[locale.languageCode]?['statistics'] ?? 'Statistics';

  // Navigation
  String get members =>
      _localizedValues[locale.languageCode]?['members'] ?? 'Members';
  String get attendance =>
      _localizedValues[locale.languageCode]?['attendance'] ?? 'Attendance';
  String get giving =>
      _localizedValues[locale.languageCode]?['giving'] ?? 'Giving';
  String get events =>
      _localizedValues[locale.languageCode]?['events'] ?? 'Events';
  String get settings =>
      _localizedValues[locale.languageCode]?['settings'] ?? 'Settings';
  String get profile =>
      _localizedValues[locale.languageCode]?['profile'] ?? 'Profile';

  // Messages
  String get noData =>
      _localizedValues[locale.languageCode]?['noData'] ?? 'No data available';
  String get networkError =>
      _localizedValues[locale.languageCode]?['networkError'] ??
      'Network error. Please check your connection.';
  String get genericError =>
      _localizedValues[locale.languageCode]?['genericError'] ??
      'An error occurred. Please try again.';

  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'appName': 'SysteMIC',
      'welcome': 'Welcome',
      'loading': 'Loading...',
      'error': 'Error',
      'success': 'Success',
      'cancel': 'Cancel',
      'confirm': 'Confirm',
      'save': 'Save',
      'delete': 'Delete',
      'edit': 'Edit',
      'search': 'Search',
      'filter': 'Filter',
      'close': 'Close',
      'login': 'Login',
      'logout': 'Logout',
      'email': 'Email',
      'password': 'Password',
      'forgotPassword': 'Forgot Password?',
      'signIn': 'Sign In',
      'signOut': 'Sign Out',
      'emailRequired': 'Email is required',
      'passwordRequired': 'Password is required',
      'invalidEmail': 'Invalid email format',
      'loginError': 'Login failed. Please try again.',
      'dashboard': 'Dashboard',
      'home': 'Home',
      'overview': 'Overview',
      'statistics': 'Statistics',
      'members': 'Members',
      'attendance': 'Attendance',
      'giving': 'Giving',
      'events': 'Events',
      'settings': 'Settings',
      'profile': 'Profile',
      'noData': 'No data available',
      'networkError': 'Network error. Please check your connection.',
      'genericError': 'An error occurred. Please try again.',
    },
    'es': {
      'appName': 'SysteMIC',
      'welcome': 'Bienvenido',
      'loading': 'Cargando...',
      'error': 'Error',
      'success': 'Éxito',
      'cancel': 'Cancelar',
      'confirm': 'Confirmar',
      'save': 'Guardar',
      'delete': 'Eliminar',
      'edit': 'Editar',
      'search': 'Buscar',
      'filter': 'Filtrar',
      'close': 'Cerrar',
      'login': 'Iniciar sesión',
      'logout': 'Cerrar sesión',
      'email': 'Correo electrónico',
      'password': 'Contraseña',
      'forgotPassword': '¿Olvidaste tu contraseña?',
      'signIn': 'Iniciar sesión',
      'signOut': 'Cerrar sesión',
      'emailRequired': 'El correo electrónico es obligatorio',
      'passwordRequired': 'La contraseña es obligatoria',
      'invalidEmail': 'Formato de correo electrónico inválido',
      'loginError': 'Error al iniciar sesión. Por favor, inténtalo de nuevo.',
      'dashboard': 'Panel de control',
      'home': 'Inicio',
      'overview': 'Resumen',
      'statistics': 'Estadísticas',
      'members': 'Miembros',
      'attendance': 'Asistencia',
      'giving': 'Ofrendas',
      'events': 'Eventos',
      'settings': 'Configuración',
      'profile': 'Perfil',
      'noData': 'No hay datos disponibles',
      'networkError': 'Error de red. Por favor, verifica tu conexión.',
      'genericError': 'Ocurrió un error. Por favor, inténtalo de nuevo.',
    },
    'fr': {
      'appName': 'SysteMIC',
      'welcome': 'Bienvenue',
      'loading': 'Chargement...',
      'error': 'Erreur',
      'success': 'Succès',
      'cancel': 'Annuler',
      'confirm': 'Confirmer',
      'save': 'Enregistrer',
      'delete': 'Supprimer',
      'edit': 'Modifier',
      'search': 'Rechercher',
      'filter': 'Filtrer',
      'close': 'Fermer',
      'login': 'Connexion',
      'logout': 'Déconnexion',
      'email': 'E-mail',
      'password': 'Mot de passe',
      'forgotPassword': 'Mot de passe oublié?',
      'signIn': 'Se connecter',
      'signOut': 'Se déconnecter',
      'emailRequired': 'L\'e-mail est requis',
      'passwordRequired': 'Le mot de passe est requis',
      'invalidEmail': 'Format d\'e-mail invalide',
      'loginError': 'Échec de la connexion. Veuillez réessayer.',
      'dashboard': 'Tableau de bord',
      'home': 'Accueil',
      'overview': 'Aperçu',
      'statistics': 'Statistiques',
      'members': 'Membres',
      'attendance': 'Présence',
      'giving': 'Dons',
      'events': 'Événements',
      'settings': 'Paramètres',
      'profile': 'Profil',
      'noData': 'Aucune donnée disponible',
      'networkError': 'Erreur réseau. Veuillez vérifier votre connexion.',
      'genericError': 'Une erreur s\'est produite. Veuillez réessayer.',
    },
  };
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return AppLocalizations.supportedLocales.contains(locale);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
