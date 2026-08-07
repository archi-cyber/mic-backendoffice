import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Conservation des jetons d'authentification.
///
/// `flutter_secure_storage` est retenu plutôt que `shared_preferences` : les
/// jetons transitent par le Keychain sur iOS et le Keystore sur Android,
/// chiffrés par le système. Dans `shared_preferences`, ils seraient stockés en
/// clair et lisibles sur un appareil rooté ou jailbreaké.
///
/// Un jeton de rafraîchissement vaut trente jours d'accès : le protéger n'est
/// pas une précaution excessive.
class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                // Les jetons ne sont lisibles qu'appareil déverrouillé, et ne
                // sont pas repris lors d'une restauration sur un autre
                // appareil : une sauvegarde iCloud ne doit pas transporter une
                // session active.
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  final FlutterSecureStorage _storage;

  static const _accessTokenKey = 'systemic_access_token';
  static const _refreshTokenKey = 'systemic_refresh_token';
  static const _expiresAtKey = 'systemic_expires_at';

  /// Cache mémoire du jeton d'accès.
  ///
  /// Le stockage sécurisé traverse un canal natif, ce qui coûte quelques
  /// millisecondes. Lire à chaque requête HTTP serait perceptible sur une
  /// liste qui en déclenche plusieurs. Le cache est invalidé à chaque écriture.
  String? _cachedAccessToken;
  DateTime? _cachedExpiresAt;

  // ---------------------------------------------------------------------------
  // Lecture
  // ---------------------------------------------------------------------------

  Future<String?> getAccessToken() async {
    _cachedAccessToken ??= await _storage.read(key: _accessTokenKey);
    return _cachedAccessToken;
  }

  Future<String?> getRefreshToken() => _storage.read(key: _refreshTokenKey);

  Future<DateTime?> getExpiresAt() async {
    if (_cachedExpiresAt != null) return _cachedExpiresAt;

    final raw = await _storage.read(key: _expiresAtKey);
    if (raw == null) return null;

    _cachedExpiresAt = DateTime.tryParse(raw);
    return _cachedExpiresAt;
  }

  /// Indique si le jeton est expiré ou sur le point de l'être.
  ///
  /// La marge de trente secondes évite une course : un jeton valide au moment
  /// de la vérification peut expirer pendant le trajet réseau. Rafraîchir un
  /// peu tôt coûte une requête ; échouer coûte un aller-retour complet plus une
  /// erreur visible par l'utilisateur.
  Future<bool> isAccessTokenExpired() async {
    final expiresAt = await getExpiresAt();
    if (expiresAt == null) return true;

    return DateTime.now().isAfter(
      expiresAt.subtract(const Duration(seconds: 30)),
    );
  }

  Future<bool> hasSession() async {
    final refresh = await getRefreshToken();
    return refresh != null && refresh.isNotEmpty;
  }

  // ---------------------------------------------------------------------------
  // Écriture
  // ---------------------------------------------------------------------------

  /// Enregistre le couple de jetons issu d'une connexion ou d'un rafraîchissement.
  ///
  /// [expiresIn] est exprimé en secondes, comme le renvoie l'API.
  Future<void> save({
    required String accessToken,
    required String refreshToken,
    required int expiresIn,
  }) async {
    final expiresAt = DateTime.now().add(Duration(seconds: expiresIn));

    _cachedAccessToken = accessToken;
    _cachedExpiresAt = expiresAt;

    await Future.wait([
      _storage.write(key: _accessTokenKey, value: accessToken),
      _storage.write(key: _refreshTokenKey, value: refreshToken),
      _storage.write(key: _expiresAtKey, value: expiresAt.toIso8601String()),
    ]);
  }

  /// Efface la session.
  ///
  /// Appelé à la déconnexion, mais aussi lorsque le serveur rejette
  /// définitivement les jetons — compte désactivé, session compromise.
  /// Conserver des jetons morts ferait boucler l'application sur des échecs de
  /// rafraîchissement.
  Future<void> clear() async {
    _cachedAccessToken = null;
    _cachedExpiresAt = null;

    await Future.wait([
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
      _storage.delete(key: _expiresAtKey),
    ]);
  }
}