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

  // Finance
  String get finance =>
      _localizedValues[locale.languageCode]?['finance'] ?? 'Finance';
  String get addGivingRecord =>
      _localizedValues[locale.languageCode]?['addGivingRecord'] ??
      'Add Giving Record';
  String get givingRecord =>
      _localizedValues[locale.languageCode]?['givingRecord'] ?? 'Giving Record';
  String get givingRecordDetails =>
      _localizedValues[locale.languageCode]?['givingRecordDetails'] ??
      'Giving Record Details';
  String get transactionType =>
      _localizedValues[locale.languageCode]?['transactionType'] ??
      'Transaction Type';
  String get receiving =>
      _localizedValues[locale.languageCode]?['receiving'] ?? 'Receiving';
  String get expense =>
      _localizedValues[locale.languageCode]?['expense'] ?? 'Expense';
  String get giverType =>
      _localizedValues[locale.languageCode]?['giverType'] ?? 'Giver Type';
  String get member =>
      _localizedValues[locale.languageCode]?['member'] ?? 'Member';
  String get externalPerson =>
      _localizedValues[locale.languageCode]?['externalPerson'] ??
      'External Person';
  String get giverName =>
      _localizedValues[locale.languageCode]?['giverName'] ?? 'Giver Name';
  String get selectMember =>
      _localizedValues[locale.languageCode]?['selectMember'] ?? 'Select Member';
  String get amount =>
      _localizedValues[locale.languageCode]?['amount'] ?? 'Amount';
  String get tag => _localizedValues[locale.languageCode]?['tag'] ?? 'Tag';
  String get notes =>
      _localizedValues[locale.languageCode]?['notes'] ?? 'Notes';
  String get description =>
      _localizedValues[locale.languageCode]?['description'] ?? 'Description';
  String get date => _localizedValues[locale.languageCode]?['date'] ?? 'Date';
  String get category =>
      _localizedValues[locale.languageCode]?['category'] ?? 'Category';
  String get created =>
      _localizedValues[locale.languageCode]?['created'] ?? 'Created';
  String get lastUpdated =>
      _localizedValues[locale.languageCode]?['lastUpdated'] ?? 'Last Updated';
  String get recordInformation =>
      _localizedValues[locale.languageCode]?['recordInformation'] ??
      'Record Information';
  String get transactionDetails =>
      _localizedValues[locale.languageCode]?['transactionDetails'] ??
      'Transaction Details';
  String get noGivingRecords =>
      _localizedValues[locale.languageCode]?['noGivingRecords'] ??
      'No giving records yet';
  String get addFirstRecord =>
      _localizedValues[locale.languageCode]?['addFirstRecord'] ??
      'Add First Record';
  String get givingRecordCreated =>
      _localizedValues[locale.languageCode]?['givingRecordCreated'] ??
      'Giving record created successfully';
  String get givingRecordUpdated =>
      _localizedValues[locale.languageCode]?['givingRecordUpdated'] ??
      'Giving record updated successfully';
  String get givingRecordNotFound =>
      _localizedValues[locale.languageCode]?['givingRecordNotFound'] ??
      'Giving record not found';
  String get errorLoadingGivingRecord =>
      _localizedValues[locale.languageCode]?['errorLoadingGivingRecord'] ??
      'Error loading giving record';
  String get giverNameRequired =>
      _localizedValues[locale.languageCode]?['giverNameRequired'] ??
      'Giver name is required';
  String get pleaseSelectTag =>
      _localizedValues[locale.languageCode]?['pleaseSelectTag'] ??
      'Please select a tag';
  String get amountRequired =>
      _localizedValues[locale.languageCode]?['amountRequired'] ??
      'Amount is required';
  String get validAmountRequired =>
      _localizedValues[locale.languageCode]?['validAmountRequired'] ??
      'Please enter a valid amount greater than zero';
  String get createExpense =>
      _localizedValues[locale.languageCode]?['createExpense'] ??
      'Create Expense';
  String get createReceivingRecord =>
      _localizedValues[locale.languageCode]?['createReceivingRecord'] ??
      'Create Receiving Record';
  String get saveChanges =>
      _localizedValues[locale.languageCode]?['saveChanges'] ?? 'Save Changes';
  String get recordCanBeEdited =>
      _localizedValues[locale.languageCode]?['recordCanBeEdited'] ??
      'This record can be edited. Changes will be saved immediately.';
  String get recordCannotBeEdited =>
      _localizedValues[locale.languageCode]?['recordCannotBeEdited'] ??
      'This record was created more than 2 days ago and cannot be edited.';
  String get errorLoadingMembers =>
      _localizedValues[locale.languageCode]?['errorLoadingMembers'] ??
      'Error loading members';
  String get errorLoadingGivingRecords =>
      _localizedValues[locale.languageCode]?['errorLoadingGivingRecords'] ??
      'Error loading giving records';

  // Tag labels
  String get construction =>
      _localizedValues[locale.languageCode]?['construction'] ?? 'Construction';
  String get specialOperation =>
      _localizedValues[locale.languageCode]?['specialOperation'] ??
      'Special Operation';
  String get tithe =>
      _localizedValues[locale.languageCode]?['tithe'] ?? 'Tithe';
  String get offering =>
      _localizedValues[locale.languageCode]?['offering'] ?? 'Offering';
  String get gift => _localizedValues[locale.languageCode]?['gift'] ?? 'Gift';
  String get other =>
      _localizedValues[locale.languageCode]?['other'] ?? 'Other';

  // Dashboard
  String get upcomingSessions =>
      _localizedValues[locale.languageCode]?['upcomingSessions'] ??
      'Upcoming Sessions';
  String get upcomingEvents =>
      _localizedValues[locale.languageCode]?['upcomingEvents'] ??
      'Upcoming Events';
  String get tasks =>
      _localizedValues[locale.languageCode]?['tasks'] ?? 'Tasks';
  String get birthdays =>
      _localizedValues[locale.languageCode]?['birthdays'] ?? 'Birthdays';
  String get quickActions =>
      _localizedValues[locale.languageCode]?['quickActions'] ?? 'Quick Actions';
  String get departments =>
      _localizedValues[locale.languageCode]?['departments'] ?? 'Departments';
  String get classes =>
      _localizedValues[locale.languageCode]?['classes'] ?? 'Classes';
  String get reports =>
      _localizedValues[locale.languageCode]?['reports'] ?? 'Reports';
  String get chat => _localizedValues[locale.languageCode]?['chat'] ?? 'Chat';
  String get errorLoadingDashboard =>
      _localizedValues[locale.languageCode]?['errorLoadingDashboard'] ??
      'Error loading dashboard';

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
      // Finance
      'finance': 'Finance',
      'addGivingRecord': 'Add Giving Record',
      'givingRecord': 'Giving Record',
      'givingRecordDetails': 'Giving Record Details',
      'transactionType': 'Transaction Type',
      'receiving': 'Receiving',
      'expense': 'Expense',
      'giverType': 'Giver Type',
      'member': 'Member',
      'externalPerson': 'External Person',
      'giverName': 'Giver Name',
      'selectMember': 'Select Member',
      'amount': 'Amount',
      'tag': 'Tag',
      'notes': 'Notes',
      'description': 'Description',
      'date': 'Date',
      'category': 'Category',
      'created': 'Created',
      'lastUpdated': 'Last Updated',
      'recordInformation': 'Record Information',
      'transactionDetails': 'Transaction Details',
      'noGivingRecords': 'No giving records yet',
      'addFirstRecord': 'Add First Record',
      'givingRecordCreated': 'Giving record created successfully',
      'givingRecordUpdated': 'Giving record updated successfully',
      'givingRecordNotFound': 'Giving record not found',
      'errorLoadingGivingRecord': 'Error loading giving record',
      'giverNameRequired': 'Giver name is required',
      'pleaseSelectTag': 'Please select a tag',
      'amountRequired': 'Amount is required',
      'validAmountRequired': 'Please enter a valid amount greater than zero',
      'createExpense': 'Create Expense',
      'createReceivingRecord': 'Create Receiving Record',
      'saveChanges': 'Save Changes',
      'recordCanBeEdited':
          'This record can be edited. Changes will be saved immediately.',
      'recordCannotBeEdited':
          'This record was created more than 2 days ago and cannot be edited.',
      'errorLoadingMembers': 'Error loading members',
      'errorLoadingGivingRecords': 'Error loading giving records',
      // Tag labels
      'construction': 'Construction',
      'specialOperation': 'Special Operation',
      'tithe': 'Tithe',
      'offering': 'Offering',
      'gift': 'Gift',
      'other': 'Other',
      // Dashboard
      'upcomingSessions': 'Upcoming Sessions',
      'upcomingEvents': 'Upcoming Events',
      'tasks': 'Tasks',
      'birthdays': 'Birthdays',
      'quickActions': 'Quick Actions',
      'departments': 'Departments',
      'classes': 'Classes',
      'reports': 'Reports',
      'chat': 'Chat',
      'errorLoadingDashboard': 'Error loading dashboard',
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
      // Finance
      'finance': 'Finance',
      'addGivingRecord': 'Ajouter un enregistrement de don',
      'givingRecord': 'Enregistrement de don',
      'givingRecordDetails': 'Détails de l\'enregistrement de don',
      'transactionType': 'Type de transaction',
      'receiving': 'Réception',
      'expense': 'Dépense',
      'giverType': 'Type de donneur',
      'member': 'Membre',
      'externalPerson': 'Personne externe',
      'giverName': 'Nom du donneur',
      'selectMember': 'Sélectionner un membre',
      'amount': 'Montant',
      'tag': 'Étiquette',
      'notes': 'Notes',
      'description': 'Description',
      'date': 'Date',
      'category': 'Catégorie',
      'created': 'Créé',
      'lastUpdated': 'Dernière mise à jour',
      'recordInformation': 'Informations sur l\'enregistrement',
      'transactionDetails': 'Détails de la transaction',
      'noGivingRecords': 'Aucun enregistrement de don pour le moment',
      'addFirstRecord': 'Ajouter le premier enregistrement',
      'givingRecordCreated': 'Enregistrement de don créé avec succès',
      'givingRecordUpdated': 'Enregistrement de don mis à jour avec succès',
      'givingRecordNotFound': 'Enregistrement de don introuvable',
      'errorLoadingGivingRecord':
          'Erreur lors du chargement de l\'enregistrement de don',
      'giverNameRequired': 'Le nom du donneur est requis',
      'pleaseSelectTag': 'Veuillez sélectionner une étiquette',
      'amountRequired': 'Le montant est requis',
      'validAmountRequired':
          'Veuillez entrer un montant valide supérieur à zéro',
      'createExpense': 'Créer une dépense',
      'createReceivingRecord': 'Créer un enregistrement de réception',
      'saveChanges': 'Enregistrer les modifications',
      'recordCanBeEdited':
          'Cet enregistrement peut être modifié. Les modifications seront enregistrées immédiatement.',
      'recordCannotBeEdited':
          'Cet enregistrement a été créé il y a plus de 2 jours et ne peut pas être modifié.',
      'errorLoadingMembers': 'Erreur lors du chargement des membres',
      'errorLoadingGivingRecords':
          'Erreur lors du chargement des enregistrements de don',
      // Tag labels
      'construction': 'Construction',
      'specialOperation': 'Opération spéciale',
      'tithe': 'Dîme',
      'offering': 'Offrande',
      'gift': 'Cadeau',
      'other': 'Autre',
      // Dashboard
      'upcomingSessions': 'Sessions à venir',
      'upcomingEvents': 'Événements à venir',
      'tasks': 'Tâches',
      'birthdays': 'Anniversaires',
      'quickActions': 'Actions rapides',
      'departments': 'Départements',
      'classes': 'Classes',
      'reports': 'Rapports',
      'chat': 'Chat',
      'errorLoadingDashboard': 'Erreur lors du chargement du tableau de bord',
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
