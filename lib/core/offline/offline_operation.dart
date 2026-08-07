import 'dart:convert';

/// Une opération d'écriture en attente de synchronisation.
///
/// Le format est volontairement générique — méthode, chemin, corps — plutôt
/// qu'un type par cas métier. L'ancienne implémentation avait un `switch` sur
/// « attendance » ou « task », qu'il fallait étendre à chaque nouvel usage ;
/// c'est d'ailleurs pourquoi la présence aux cultes n'y figurait pas.
class OfflineOperation {
  OfflineOperation({
    required this.id,
    required this.method,
    required this.path,
    this.body,
    required this.createdAt,
    this.attempts = 0,
    this.lastError,
    this.tempId,
    this.label,
  });

  /// Identifiant local de l'opération.
  final String id;

  /// `POST`, `PATCH`, `PUT` ou `DELETE`.
  final String method;

  /// Chemin relatif, tel qu'attendu par l'API.
  ///
  /// Peut contenir un identifiant temporaire — voir [tempId].
  final String path;

  final Map<String, dynamic>? body;

  final DateTime createdAt;

  /// Nombre de tentatives de synchronisation échouées.
  final int attempts;

  final String? lastError;

  /// Identifiant temporaire produit par cette opération, le cas échéant.
  ///
  /// Créer un culte hors ligne lui donne un identifiant local `temp_...`. Les
  /// présences saisies dans la foulée le référencent. À la synchronisation, le
  /// serveur renvoie le vrai identifiant, qui remplace le temporaire dans
  /// toutes les opérations suivantes.
  ///
  /// Sans ce mécanisme, pointer la présence d'un culte créé sur place serait
  /// impossible : les entrées viseraient un culte inexistant.
  final String? tempId;

  /// Libellé lisible, pour l'écran de synchronisation.
  ///
  /// « Présence du culte du 9 août » est plus utile à un responsable que
  /// « POST /church-services/xxx/attendance ».
  final String? label;

  bool get isRetryable => attempts < maxAttempts;

  /// Au-delà, l'opération est mise de côté plutôt que retentée indéfiniment.
  ///
  /// Une opération qui échoue cinq fois ne réussira pas à la sixième : le
  /// problème est dans la donnée, pas dans le réseau. La laisser boucler
  /// bloquerait toutes les suivantes.
  static const int maxAttempts = 5;

  OfflineOperation copyWith({int? attempts, String? lastError}) {
    return OfflineOperation(
      id: id,
      method: method,
      path: path,
      body: body,
      createdAt: createdAt,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
      tempId: tempId,
      label: label,
    );
  }

  /// Remplace un identifiant temporaire par le vrai, dans le chemin et le corps.
  OfflineOperation resolveTempId(String temp, String real) {
    final newPath = path.replaceAll(temp, real);

    Map<String, dynamic>? newBody;
    if (body != null) {
      // Le remplacement passe par la représentation JSON : l'identifiant peut
      // se trouver à n'importe quelle profondeur — dans une liste d'entrées,
      // dans un objet imbriqué. Parcourir la structure à la main manquerait
      // des cas.
      final encoded = jsonEncode(body).replaceAll(temp, real);
      newBody = jsonDecode(encoded) as Map<String, dynamic>;
    }

    return OfflineOperation(
      id: id,
      method: method,
      path: newPath,
      body: newBody,
      createdAt: createdAt,
      attempts: attempts,
      lastError: lastError,
      tempId: tempId,
      label: label,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'method': method,
        'path': path,
        'body': body,
        'created_at': createdAt.toIso8601String(),
        'attempts': attempts,
        'last_error': lastError,
        'temp_id': tempId,
        'label': label,
      };

  factory OfflineOperation.fromJson(Map<String, dynamic> json) {
    return OfflineOperation(
      id: json['id'] as String,
      method: json['method'] as String,
      path: json['path'] as String,
      body: (json['body'] as Map?)?.cast<String, dynamic>(),
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      attempts: json['attempts'] as int? ?? 0,
      lastError: json['last_error'] as String?,
      tempId: json['temp_id'] as String?,
      label: json['label'] as String?,
    );
  }
}

/// Résultat d'une synchronisation.
class SyncResult {
  const SyncResult({
    required this.synced,
    required this.failed,
    required this.remaining,
    this.errors = const [],
  });

  final int synced;
  final int failed;
  final int remaining;
  final List<String> errors;

  bool get isComplete => remaining == 0 && failed == 0;
  bool get hasErrors => failed > 0;
}