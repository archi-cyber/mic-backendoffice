import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../config/app_config.dart';
import '../offline/offline_cache.dart';
import '../offline/offline_queue.dart';
import 'api_exception.dart';
import 'token_storage.dart';

/// Résultat paginé renvoyé par l'API.
class Paginated<T> {
  const Paginated({
    required this.data,
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
    this.extra,
  });

  final List<T> data;
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  /// Champs supplémentaires du bloc `meta` — totaux financiers, compteur de
  /// notifications non lues…
  final Map<String, dynamic>? extra;

  bool get hasNextPage => page < totalPages;
  bool get isEmpty => data.isEmpty;
  bool get isNotEmpty => data.isNotEmpty;
  int get length => data.length;
}


// =============================================================================
// Conversion des clés
// =============================================================================
//
// L'API travaille en camelCase, l'application en snake_case — c'est l'héritage
// de Supabase, où les clés JSON étaient les noms de colonnes PostgreSQL.
//
// La conversion est faite ici plutôt que dans chaque service. Le bénéfice est
// considérable : les soixante écrans continuent de passer `{'first_name': ...}`
// et les modèles gardent leurs `@JsonKey(name: 'first_name')`. Aucun n'a
// besoin d'être touché.
//
// Le sens de conversion n'introduit pas d'ambiguïté : `camelToSnake` laisse
// intacte une chaîne déjà en snake_case, faute de majuscule à convertir.

String _snakeToCamel(String input) {
  if (!input.contains('_')) return input;

  final parts = input.split('_');
  final buffer = StringBuffer(parts.first);

  for (var i = 1; i < parts.length; i++) {
    final part = parts[i];
    if (part.isEmpty) continue;
    buffer
      ..write(part[0].toUpperCase())
      ..write(part.substring(1));
  }

  return buffer.toString();
}

String _camelToSnake(String input) {
  return input.replaceAllMapped(
    RegExp(r'[A-Z]'),
    (match) => '_${match.group(0)!.toLowerCase()}',
  );
}

/// Applique un convertisseur à toutes les clés, en profondeur.
dynamic _convertKeys(dynamic value, String Function(String) convert) {
  if (value is Map) {
    return value.map(
      (key, val) => MapEntry(convert(key.toString()), _convertKeys(val, convert)),
    );
  }
  if (value is List) {
    return value.map((item) => _convertKeys(item, convert)).toList();
  }
  return value;
}

/// Client HTTP unique de l'application.
///
/// Remplace `supabase_flutter`. Trois responsabilités :
///
///   - porter le jeton d'accès sur chaque requête ;
///   - le rafraîchir automatiquement quand il expire, sans que l'appelant
///     s'en aperçoive ;
///   - traduire les réponses d'erreur en [ApiException].
///
/// Le déballage de l'enveloppe `{ data, meta }` est également centralisé ici :
/// tous les services reçoivent directement le contenu utile.
class ApiClient {
  ApiClient({TokenStorage? tokenStorage, Dio? dio})
      : _tokens = tokenStorage ?? TokenStorage(),
        _dio = dio ?? Dio() {
    _configure();
  }

  final Dio _dio;
  final TokenStorage _tokens;

  /// Rafraîchissement en cours, partagé par toutes les requêtes en attente.
  ///
  /// Sans ce verrou, dix requêtes simultanées recevant un 401 lanceraient dix
  /// rafraîchissements. Or la rotation côté serveur révoque l'ancien jeton à
  /// chaque échange : le deuxième appel présenterait un jeton déjà consommé,
  /// que le serveur interpréterait comme une réutilisation frauduleuse — et
  /// toutes les sessions seraient fermées.
  Future<bool>? _refreshInFlight;

  /// Appelé quand la session ne peut plus être rétablie.
  ///
  /// Permet à l'application de renvoyer l'utilisateur vers l'écran de
  /// connexion depuis n'importe quel endroit.
  void Function()? onSessionExpired;

  TokenStorage get tokens => _tokens;

  // ---------------------------------------------------------------------------
  // Configuration
  // ---------------------------------------------------------------------------

  void _configure() {
    _dio.options = BaseOptions(
      baseUrl: AppConfig.apiUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      sendTimeout: AppConfig.sendTimeout,
      headers: {'Content-Type': 'application/json'},
      // Dio ne lève pas d'exception : on gère les codes nous-mêmes pour
      // produire des ApiException homogènes.
      validateStatus: (_) => true,
    );

    _dio.interceptors.add(
      InterceptorsWrapper(onRequest: _attachToken),
    );

    if (kDebugMode && AppConfig.verboseHttpLogging) {
      _dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          // L'en-tête Authorization contient le jeton : le tracer reviendrait
          // à le laisser dans les journaux de l'appareil.
          requestHeader: false,
          responseHeader: false,
        ),
      );
    }
  }

  /// Ajoute le jeton, en le rafraîchissant d'abord s'il est expiré.
  ///
  /// Le rafraîchissement préventif évite un aller-retour inutile : sans lui,
  /// chaque requête après quinze minutes d'inactivité partirait, échouerait en
  /// 401, puis serait rejouée.
  Future<void> _attachToken(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final isAuthRoute = options.path.startsWith('/auth/');
    final needsAuth = !isAuthRoute ||
        options.path == '/auth/me' ||
        options.path == '/auth/logout' ||
        options.path == '/auth/change-password' ||
        options.path.startsWith('/auth/sessions');

    if (needsAuth) {
      if (await _tokens.isAccessTokenExpired()) {
        await _refreshSession();
      }

      final token = await _tokens.getAccessToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }

    handler.next(options);
  }

  // ---------------------------------------------------------------------------
  // Verbes HTTP
  // ---------------------------------------------------------------------------

  /// Requête de lecture, avec repli sur le cache.
  ///
  /// En cas de panne réseau, la dernière réponse connue est renvoyée plutôt
  /// qu'une erreur. Un responsable arrivant dans une salle sans couverture
  /// trouve ainsi la liste des membres, et peut pointer — ce qui est tout
  /// l'intérêt du mode hors ligne.
  ///
  /// Seules les routes de la liste blanche d'`OfflineCache` sont concernées :
  /// rapports et données financières n'ont pas à traîner sur l'appareil.
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final cacheKey = _cacheKey(path, query);

    try {
      final result = await _send(
        () => _dio.get(path, queryParameters: _cleanQuery(query)),
      );

      // Le cache est alimenté hors du chemin critique : son échec ne doit pas
      // faire échouer une requête réussie.
      unawaited(OfflineCache.instance.put(cacheKey, result));

      return result;
    } on ApiException catch (error) {
      if (!error.isNetworkError) rethrow;

      final cached = await OfflineCache.instance.get(cacheKey);
      if (cached == null) rethrow;

      debugPrint(
        '[ApiClient] Hors ligne : réponse du cache pour $path '
        '(${cached.age.inMinutes} min)',
      );

      return cached.value;
    }
  }

  /// Clé de cache — chemin et paramètres, pour distinguer les filtres.
  ///
  /// Les clés sont triées : deux requêtes identiques à l'ordre des paramètres
  /// près doivent partager la même entrée.
  String _cacheKey(String path, Map<String, dynamic>? query) {
    final cleaned = _cleanQuery(query);
    if (cleaned == null || cleaned.isEmpty) return path;

    final keys = cleaned.keys.toList()..sort();
    return '$path?${keys.map((k) => '$k=${cleaned[k]}').join('&')}';
  }

  /// Écriture, mise en file si le réseau est absent.
  ///
  /// L'opération est alors rejouée au retour de la connexion. L'appelant
  /// reçoit une réponse optimiste : la saisie est acceptée côté interface,
  /// même si le serveur ne l'a pas encore reçue.
  ///
  /// C'est le compromis qu'impose le hors ligne — sans lui, un responsable ne
  /// pourrait rien pointer sans réseau. Le risque est qu'une opération soit
  /// finalement refusée par le serveur ; l'écran de synchronisation permet de
  /// le constater.
  Future<dynamic> post(String path, {dynamic body, String? offlineLabel}) =>
      _write('POST', path, body, offlineLabel);

  Future<dynamic> patch(String path, {dynamic body, String? offlineLabel}) =>
      _write('PATCH', path, body, offlineLabel);

  Future<dynamic> put(String path, {dynamic body, String? offlineLabel}) =>
      _write('PUT', path, body, offlineLabel);

  Future<dynamic> delete(String path, {dynamic body, String? offlineLabel}) =>
      _write('DELETE', path, body, offlineLabel);

  Future<dynamic> _write(
    String method,
    String path,
    dynamic body,
    String? offlineLabel,
  ) async {
    // L'authentification ne passe jamais par la file : mettre une connexion en
    // attente n'aurait aucun sens, et rejouerait un mot de passe plus tard.
    final isAuthRoute = path.startsWith('/auth/');

    try {
      return await _send(() {
        final data = _toApi(body);
        switch (method) {
          case 'POST':
            return _dio.post(path, data: data);
          case 'PATCH':
            return _dio.patch(path, data: data);
          case 'PUT':
            return _dio.put(path, data: data);
          default:
            return _dio.delete(path, data: data);
        }
      });
    } on ApiException catch (error) {
      if (isAuthRoute || !error.isNetworkError) rethrow;

      final converted = _toApi(body);

      await OfflineQueue.instance.enqueue(
        method: method,
        path: path,
        body: converted is Map ? converted.cast<String, dynamic>() : null,
        label: offlineLabel,
      );

      // Réponse optimiste : l'interface poursuit comme si l'opération avait
      // abouti. Le champ `_offline` permet à un écran de le signaler.
      return {'_offline': true, 'message': 'Enregistré, en attente de réseau.'};
    }
  }

  /// Requête renvoyant une liste simple.
  ///
  /// Les routes paginées renvoient `{ data, meta }` ; seul `data` est conservé.
  /// La plupart des écrans n'ont que faire de la pagination : cette méthode
  /// leur évite d'avoir à la déballer.
  Future<List<Map<String, dynamic>>> getList(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final data = await get(path, query: query);

    if (data is List) {
      return data.map((e) => (e as Map).cast<String, dynamic>()).toList();
    }
    if (data is Map && data['data'] is List) {
      return (data['data'] as List)
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
    }

    return const [];
  }


  /// Plafond de pagination du serveur.
  ///
  /// Le backend refuse toute requête dépassant cette valeur. La constante est
  /// exposée pour que les services sachent quand paginer plutôt que de
  /// demander un lot trop grand.
  static const int maxPageSize = 200;

  /// Récupère **toutes** les pages d'une ressource.
  ///
  /// Le serveur plafonne chaque requête à [maxPageSize] lignes. Demander
  /// davantage échoue ; se contenter du plafond tronquerait silencieusement le
  /// résultat, ce qui est pire — un rapport incomplet ne se signale pas.
  ///
  /// Cette méthode enchaîne les pages jusqu'à épuisement, avec un garde-fou
  /// [maxItems] pour éviter qu'une erreur de filtre ne fasse charger la table
  /// entière sur un téléphone.
  Future<List<Map<String, dynamic>>> getAll(
    String path, {
    Map<String, dynamic>? query,
    int maxItems = 5000,
  }) async {
    final all = <Map<String, dynamic>>[];
    var page = 1;

    while (all.length < maxItems) {
      final batch = await getList(path, query: {
        ...?query,
        'page': page,
        'limit': maxPageSize,
      });

      all.addAll(batch);

      // Une page incomplète signale la fin : inutile d'en demander une autre
      // pour se le faire confirmer.
      if (batch.length < maxPageSize) break;

      page += 1;
    }

    return all.length > maxItems ? all.sublist(0, maxItems) : all;
  }

  /// Requête renvoyant un objet.
  Future<Map<String, dynamic>> getOne(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final data = await get(path, query: query);
    return (data as Map).cast<String, dynamic>();
  }

  /// Requête paginée.
  ///
  /// [fromJson] convertit chaque élément ; l'enveloppe `meta` est lue
  /// automatiquement.
  Future<Paginated<T>> getPaginated<T>(
    String path, {
    Map<String, dynamic>? query,
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    final response = await _dio.get(path, queryParameters: _cleanQuery(query));
    final body = _validate(response, unwrap: false);

    if (body is! Map || body['data'] is! List) {
      throw const ApiException(
        statusCode: 0,
        code: ApiErrorCodes.unknown,
        message: 'Réponse paginée invalide.',
      );
    }

    final meta = (body['meta'] as Map?)?.cast<String, dynamic>() ?? const {};

    return Paginated<T>(
      data: (body['data'] as List)
          .map((item) => fromJson((item as Map).cast<String, dynamic>()))
          .toList(),
      page: meta['page'] as int? ?? 1,
      limit: meta['limit'] as int? ?? 20,
      total: meta['total'] as int? ?? 0,
      totalPages: meta['total_pages'] as int? ?? meta['totalPages'] as int? ?? 1,
      extra: meta.isEmpty ? null : meta,
    );
  }

  // ---------------------------------------------------------------------------
  // Exécution
  // ---------------------------------------------------------------------------

  /// Exécute la requête, rejoue une fois après rafraîchissement si nécessaire.
  Future<dynamic> _send(Future<Response> Function() request) async {
    try {
      var response = await request();

      // Un 401 malgré le rafraîchissement préventif signifie que le jeton a
      // été révoqué côté serveur — changement de mot de passe, désactivation
      // du compte. Une tentative de rafraîchissement tranche le cas.
      if (response.statusCode == 401) {
        final refreshed = await _refreshSession();
        if (refreshed) {
          response = await request();
        }
      }

      return _validate(response);
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  /// Déballe l'enveloppe ou lève une [ApiException].
  dynamic _validate(Response response, {bool unwrap = true}) {
    final status = response.statusCode ?? 0;

    if (status >= 200 && status < 300) {
      final body = _fromApi(response.data);

      // L'API enveloppe systématiquement dans `{ data: ... }`, sauf la sonde
      // de santé. Le déballage est fait ici pour que les services manipulent
      // directement le contenu.
      if (unwrap && body is Map && body.containsKey('data')) {
        return body['data'];
      }
      return body;
    }

    if (status == 401) {
      _handleSessionExpired();
    }

    throw ApiException.fromResponse(status, response.data);
  }

  ApiException _mapDioException(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return ApiException.timeout();

      case DioExceptionType.badResponse:
        return ApiException.fromResponse(
          error.response?.statusCode ?? 0,
          error.response?.data,
        );

      case DioExceptionType.cancel:
        return const ApiException(
          statusCode: 0,
          code: ApiErrorCodes.unknown,
          message: 'Requête annulée.',
        );

      case DioExceptionType.badCertificate:
        return ApiException.network('Certificat du serveur invalide.');

      // Couvre connectionError, unknown, et les valeurs que Dio pourrait
      // ajouter. Un `default` evite qu'une montee de version ne casse la
      // compilation pour un cas traite de la meme facon de toute maniere.
      default:
        return ApiException.network('Vérifiez votre connexion internet.');
    }
  }

  // ---------------------------------------------------------------------------
  // Rafraîchissement
  // ---------------------------------------------------------------------------

  /// Renouvelle le couple de jetons.
  ///
  /// Les appels concurrents partagent la même opération : le premier lance le
  /// rafraîchissement, les suivants attendent son résultat. Voir le commentaire
  /// de [_refreshInFlight] pour la raison — la rotation côté serveur rend les
  /// appels parallèles destructeurs.
  Future<bool> _refreshSession() {
    return _refreshInFlight ??= _performRefresh()
        .whenComplete(() => _refreshInFlight = null);
  }

  Future<bool> _performRefresh() async {
    final refreshToken = await _tokens.getRefreshToken();

    if (refreshToken == null || refreshToken.isEmpty) {
      return false;
    }

    try {
      // Instance distincte : passer par `_dio` déclencherait l'intercepteur,
      // qui tenterait à son tour un rafraîchissement — boucle infinie.
      final response = await Dio(
        BaseOptions(
          baseUrl: AppConfig.apiUrl,
          connectTimeout: AppConfig.connectTimeout,
          receiveTimeout: AppConfig.receiveTimeout,
          headers: {'Content-Type': 'application/json'},
          validateStatus: (_) => true,
        ),
      ).post('/auth/refresh', data: {'refreshToken': refreshToken});

      if (response.statusCode != 200 && response.statusCode != 201) {
        await _handleRefreshFailure(response);
        return false;
      }

      final payload = (response.data as Map)['data'] as Map;

      await _tokens.save(
        accessToken: payload['accessToken'] as String,
        refreshToken: payload['refreshToken'] as String,
        expiresIn: payload['expiresIn'] as int? ?? 900,
      );

      return true;
    } catch (error) {
      debugPrint('[ApiClient] Rafraîchissement impossible : $error');
      return false;
    }
  }

  /// Décide s'il faut effacer la session après un échec de rafraîchissement.
  ///
  /// Un refus explicite du serveur — jeton inconnu, expiré, réutilisé, compte
  /// désactivé — est définitif : garder les jetons ferait boucler l'application
  /// sur des tentatives vouées à l'échec.
  ///
  /// Une erreur transitoire, en revanche, ne doit pas déconnecter : le serveur
  /// peut redémarrer, la base être momentanément indisponible. Forcer une
  /// reconnexion dans ce cas serait une mauvaise expérience pour une panne de
  /// quelques secondes.
  Future<void> _handleRefreshFailure(Response response) async {
    final body = response.data;
    final code = body is Map ? body['code']?.toString() : null;

    const definitive = {
      ApiErrorCodes.refreshTokenReused,
      ApiErrorCodes.refreshTokenExpired,
      ApiErrorCodes.accountDisabled,
      'REFRESH_TOKEN_UNKNOWN',
      'REFRESH_TOKEN_INVALID',
      'REFRESH_TOKEN_MISMATCH',
      'USER_NOT_FOUND',
      'MEMBER_DELETED',
    };

    if (response.statusCode == 401 && definitive.contains(code)) {
      debugPrint('[ApiClient] Session définitivement close : $code');
      await _tokens.clear();
      _handleSessionExpired();
    }
  }

  void _handleSessionExpired() {
    final callback = onSessionExpired;
    if (callback != null) {
      callback();
    }
  }

  // ---------------------------------------------------------------------------
  // Utilitaires
  // ---------------------------------------------------------------------------

  /// Corps de requête : snake_case vers camelCase.
  dynamic _toApi(dynamic body) =>
      body == null ? null : _convertKeys(body, _snakeToCamel);

  /// Réponse : camelCase vers snake_case.
  dynamic _fromApi(dynamic body) =>
      body == null ? null : _convertKeys(body, _camelToSnake);

  /// Retire les paramètres nuls ou vides, et convertit les clés.
  ///
  /// Envoyer `?search=` ferait échouer certaines validations côté serveur,
  /// alors que l'intention est simplement l'absence de filtre.
  Map<String, dynamic>? _cleanQuery(Map<String, dynamic>? query) {
    if (query == null) return null;

    final cleaned = <String, dynamic>{};
    query.forEach((key, value) {
      if (value == null) return;
      if (value is String && value.trim().isEmpty) return;
      cleaned[_snakeToCamel(key)] = value;
    });

    return cleaned.isEmpty ? null : cleaned;
  }
}