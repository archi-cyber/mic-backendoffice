/// Configuration de l'application.
///
/// Supabase a disparu : l'application ne parle plus qu'à l'API NestJS, en
/// HTTPS pour les données et en WebSocket pour le temps réel. Elle ne connaît
/// plus la base de données, et ne porte donc plus aucun secret.
///
/// C'est le principal gain de la migration : la clé `anon` Supabase, présente
/// dans chaque installation, donnait un accès direct à la base. Un jeton JWT
/// expire au bout de quinze minutes et ne vaut que pour son porteur.
class AppConfig {
  AppConfig._();

  // ---------------------------------------------------------------------------
  // API
  // ---------------------------------------------------------------------------

  /// URL de base de l'API.
  ///
  /// Surchargeable au lancement sans recompiler :
  ///   flutter run --dart-define=API_BASE_URL=https://api.exemple.org
  ///
  /// Le repli pointe vers le développement local. Attention sur Android :
  /// l'émulateur ne voit pas `localhost`, qui désigne l'appareil lui-même.
  /// Utiliser `10.0.2.2` pour atteindre la machine hôte.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );

  static const String apiPrefix = '/api/v1';

  /// URL complète des requêtes REST.
  static String get apiUrl => '$apiBaseUrl$apiPrefix';

  /// Point d'entrée WebSocket.
  static String get realtimeUrl => apiBaseUrl;

  static const String realtimeNamespace = '/realtime';

  // ---------------------------------------------------------------------------
  // Délais
  // ---------------------------------------------------------------------------

  /// Délai d'établissement de la connexion.
  static const Duration connectTimeout = Duration(seconds: 15);

  /// Délai de réception de la réponse.
  ///
  /// Volontairement large : certains rapports croisent plusieurs centaines de
  /// membres avec des dizaines de cultes, et une connexion mobile lente peut
  /// dépasser les valeurs par défaut.
  static const Duration receiveTimeout = Duration(seconds: 30);

  static const Duration sendTimeout = Duration(seconds: 30);

  // ---------------------------------------------------------------------------
  // Application
  // ---------------------------------------------------------------------------

  static const String appName = 'SysteMIC';
  static const String appVersion = '2.0.0';

  /// Pays par défaut pour les numéros de téléphone sans indicatif.
  static const String defaultPhoneCountryIso = 'CM';

  /// Active les traces réseau détaillées.
  ///
  /// `kDebugMode` ne suffit pas : on veut pouvoir couper ces traces même en
  /// développement, car elles noient la console lors d'un test de charge.
  static const bool verboseHttpLogging = bool.fromEnvironment(
    'VERBOSE_HTTP',
    defaultValue: true,
  );
}