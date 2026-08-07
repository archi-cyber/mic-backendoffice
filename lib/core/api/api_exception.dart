/// Erreur renvoyée par l'API.
///
/// Le backend produit un format uniforme :
/// ```json
/// {
///   "statusCode": 409,
///   "error": "Conflict",
///   "message": "Un culte porte déjà ce nom à cette date",
///   "code": "SERVICE_NAME_DUPLICATE",
///   "timestamp": "...",
///   "path": "/api/v1/church-services"
/// }
/// ```
///
/// Le champ [code] est la clé : stable et lisible par machine, il permet
/// d'afficher un message traduit sans dépendre du texte français ou anglais de
/// [message], qui reste destiné aux développeurs et aux journaux.
class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.code,
    required this.message,
    this.fieldErrors = const [],
  });

  final int statusCode;

  /// Code stable — voir [ApiErrorCodes].
  final String code;

  /// Message technique, en français côté serveur.
  final String message;

  /// Détail des erreurs de validation, un élément par champ fautif.
  final List<String> fieldErrors;

  // ---------------------------------------------------------------------------
  // Construction
  // ---------------------------------------------------------------------------

  /// Construit l'exception depuis le corps JSON d'une réponse d'erreur.
  factory ApiException.fromResponse(int statusCode, dynamic body) {
    if (body is! Map) {
      return ApiException(
        statusCode: statusCode,
        code: ApiErrorCodes.unknown,
        message: 'Réponse inattendue du serveur.',
      );
    }

    final rawMessage = body['message'];

    // Le ValidationPipe de NestJS renvoie un tableau de messages, un par champ
    // invalide. On les conserve séparément pour permettre au formulaire de
    // signaler précisément ce qui ne va pas.
    final fieldErrors = rawMessage is List
        ? rawMessage.map((item) => item.toString()).toList()
        : const <String>[];

    final message = rawMessage is List
        ? (rawMessage.isEmpty ? 'Données invalides.' : rawMessage.first.toString())
        : (rawMessage?.toString() ?? 'Une erreur est survenue.');

    return ApiException(
      statusCode: statusCode,
      code: body['code']?.toString() ?? ApiErrorCodes.unknown,
      message: message,
      fieldErrors: fieldErrors,
    );
  }

  /// Panne réseau : serveur injoignable, DNS en échec, avion.
  factory ApiException.network([String? detail]) => ApiException(
        statusCode: 0,
        code: ApiErrorCodes.networkError,
        message: detail ?? 'Impossible de joindre le serveur.',
      );

  /// Délai dépassé.
  factory ApiException.timeout() => const ApiException(
        statusCode: 0,
        code: ApiErrorCodes.timeout,
        message: 'Le serveur met trop de temps à répondre.',
      );

  // ---------------------------------------------------------------------------
  // Qualification
  // ---------------------------------------------------------------------------

  bool get isNetworkError =>
      code == ApiErrorCodes.networkError || code == ApiErrorCodes.timeout;

  bool get isUnauthorized => statusCode == 401;

  bool get isForbidden => statusCode == 403;

  bool get isNotFound => statusCode == 404;

  bool get isConflict => statusCode == 409;

  bool get isValidationError => statusCode == 400 || statusCode == 422;

  /// Une erreur serveur mérite un signalement ; une erreur client, non.
  bool get isServerError => statusCode >= 500;

  /// Indique si l'opération peut être retentée telle quelle.
  ///
  /// Les erreurs réseau et les 5xx sont transitoires. Une erreur de validation
  /// ou un refus de permission ne le sont pas : réessayer produirait le même
  /// résultat.
  bool get isRetryable => isNetworkError || isServerError || statusCode == 503;

  @override
  String toString() => 'ApiException($statusCode, $code): $message';
}

/// Codes d'erreur émis par le backend.
///
/// Cette liste doit rester alignée sur celle du serveur. Ces constantes
/// permettent de réagir à un cas précis sans comparer des chaînes littérales
/// dispersées dans le code.
abstract final class ApiErrorCodes {
  // --- Transport ---
  static const networkError = 'NETWORK_ERROR';
  static const timeout = 'TIMEOUT';
  static const unknown = 'UNKNOWN';

  // --- Authentification ---
  static const unauthorized = 'UNAUTHORIZED';
  static const invalidCredentials = 'INVALID_CREDENTIALS';
  static const tokenExpired = 'TOKEN_EXPIRED';
  static const accountDisabled = 'ACCOUNT_DISABLED';
  static const refreshTokenReused = 'REFRESH_TOKEN_REUSED';
  static const refreshTokenExpired = 'REFRESH_TOKEN_EXPIRED';
  static const currentPasswordInvalid = 'CURRENT_PASSWORD_INVALID';
  static const resetTokenInvalid = 'RESET_TOKEN_INVALID';

  // --- Permissions ---
  static const forbidden = 'FORBIDDEN';
  static const permissionDenied = 'PERMISSION_DENIED';
  static const insufficientRole = 'INSUFFICIENT_ROLE';
  static const financeAccessDenied = 'FINANCE_ACCESS_DENIED';

  // --- Règles métier ---
  static const justPassingMustBeVisitor = 'JUST_PASSING_MUST_BE_VISITOR';
  static const serviceNameDuplicate = 'SERVICE_NAME_DUPLICATE';
  static const memberTooOldForSundaySchool = 'MEMBER_TOO_OLD_FOR_SUNDAY_SCHOOL';
  static const birthdayRequired = 'BIRTHDAY_REQUIRED';
  static const penaltyThresholdExceeded = 'PENALTY_THRESHOLD_EXCEEDED';
  static const taskOwnerConflict = 'TASK_OWNER_CONFLICT';
  static const taskOwnerRequired = 'TASK_OWNER_REQUIRED';
  static const financeDepartmentProtected = 'FINANCE_DEPARTMENT_PROTECTED';
  static const lastAdmin = 'LAST_ADMIN';
  static const notEnrolled = 'NOT_ENROLLED';
  static const givingEditWindowClosed = 'GIVING_EDIT_WINDOW_CLOSED';
  static const announcementAudienceRequired = 'ANNOUNCEMENT_AUDIENCE_REQUIRED';

  // --- Génériques ---
  static const notFound = 'NOT_FOUND';
  static const duplicateEntry = 'DUPLICATE_ENTRY';
  static const validationError = 'VALIDATION_ERROR';
  static const rateLimited = 'RATE_LIMITED';
  static const databaseUnavailable = 'DATABASE_UNAVAILABLE';
}