import 'package:flutter/foundation.dart';

import '../core/api/api_client.dart';
import 'auth_service.dart';
import 'church_service_service.dart';

/// Présence aux cultes.
///
/// Signatures identiques à l'implémentation Supabase.
///
/// Une différence de fond, invisible depuis les écrans : la graduation des
/// nouveaux venus n'est plus calculée ici. Le serveur l'applique
/// automatiquement après chaque pointage, ce qui garantit qu'elle ne peut ni
/// être oubliée ni diverger selon le client utilisé.
class ChurchAttendanceService {
  static ApiClient get _client => AuthService.client;

  static String _day(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  // ---------------------------------------------------------------------------
  // Saisie
  // ---------------------------------------------------------------------------

  /// Marque la présence d'un membre.
  ///
  /// Créée ou mise à jour selon qu'une ligne existe déjà : revenir sur une
  /// saisie ne produit pas de doublon.
  static Future<Map<String, dynamic>> markAttendance({
    required String memberId,
    required String churchServiceId,
    String attendanceType = 'onsite',
    String? specificObservation,
  }) async {
    final data = await _client.post(
      '/church-services/$churchServiceId/attendance',
      body: {
        'entries': [
          {
            'member_id': memberId,
            'attendance_type': attendanceType,
            if (specificObservation != null)
              'specific_observation': specificObservation,
          }
        ],
      },
    );
    return (data as Map).cast<String, dynamic>();
  }

  /// Marque la présence de plusieurs membres en une requête.
  ///
  /// C'est la voie normale pour une feuille de présence : envoyer une requête
  /// par personne serait inutilisable sur une connexion mobile avec cinquante
  /// membres à pointer.
  ///
  /// La réponse contient `graduated_members` — ceux qui viennent de perdre
  /// leur statut de nouveau venu.
  static Future<Map<String, dynamic>> markBulkAttendance({
    required List<String> memberIds,
    required String churchServiceId,
    String attendanceType = 'onsite',
    Map<String, String?>? specificObservationsByMember,
  }) async {
    final entries = memberIds.map((memberId) {
      final note = specificObservationsByMember?[memberId];
      return {
        'member_id': memberId,
        'attendance_type': attendanceType,
        if (note != null && note.isNotEmpty) 'specific_observation': note,
      };
    }).toList();

    final data = await _client.post(
      '/church-services/$churchServiceId/attendance',
      body: {'entries': entries},
    );

    debugPrint('[ChurchAttendance] ${memberIds.length} présence(s) enregistrée(s)');

    return (data as Map).cast<String, dynamic>();
  }

  /// Modifie une présence existante.
  ///
  /// L'API travaille par couple membre + culte plutôt que par identifiant de
  /// ligne : renvoyer l'entrée met à jour celle qui existe.
  static Future<Map<String, dynamic>> updateAttendance({
    required String attendanceId,
    String? attendanceType,
    String? specificObservation,
    bool clearSpecificObservation = false,
    String? churchServiceId,
    String? memberId,
  }) async {
    if (churchServiceId == null || memberId == null) {
      throw ArgumentError(
        'churchServiceId et memberId sont requis : l\'API identifie une '
        'présence par ce couple, non par un identifiant de ligne.',
      );
    }

    final data = await _client.post(
      '/church-services/$churchServiceId/attendance',
      body: {
        'entries': [
          {
            'member_id': memberId,
            'attendance_type': attendanceType ?? 'onsite',
            'specific_observation':
                clearSpecificObservation ? null : specificObservation,
          }
        ],
      },
    );
    return (data as Map).cast<String, dynamic>();
  }

  // ---------------------------------------------------------------------------
  // Consultation
  // ---------------------------------------------------------------------------

  /// Historique de présence d'un membre.
  static Future<List<Map<String, dynamic>>> getMemberAttendance({
    required String memberId,
    DateTime? startDate,
    DateTime? endDate,
    String? churchServiceId,
    int? limit,
    int? offset,
  }) {
    final effectiveLimit = limit ?? 200;
    final page = offset == null ? 1 : (offset ~/ effectiveLimit) + 1;

    return _client.getList('/church-attendance', query: {
      'member_id': memberId,
      if (startDate != null) 'from': _day(startDate),
      if (endDate != null) 'to': _day(endDate),
      if (churchServiceId != null) 'church_service_id': churchServiceId,
      'page': page,
      'limit': effectiveLimit,
    });
  }

  /// Présences enregistrées pour un culte.
  static Future<List<Map<String, dynamic>>> getServiceAttendance({
    required String churchServiceId,
  }) {
    return _client.getList('/church-attendance', query: {
      'church_service_id': churchServiceId,
      'limit': 200,
    });
  }

  /// Lignes brutes de présence, pour les rapports.
  static Future<List<Map<String, dynamic>>> getRawAttendanceRows({
    DateTime? startDate,
    DateTime? endDate,
    String? churchServiceId,
    bool includeDeleted = false,
    int limit = 300,
    int offset = 0,
  }) {
    final page = (offset ~/ limit) + 1;

    return _client.getList('/church-attendance', query: {
      if (startDate != null) 'from': _day(startDate),
      if (endDate != null) 'to': _day(endDate),
      if (churchServiceId != null) 'church_service_id': churchServiceId,
      'page': page,
      'limit': limit,
    });
  }

  /// Nombre de présences sur les trois derniers mois.
  ///
  /// Sert au suivi des nouveaux venus. Le calcul est fait côté serveur, qui
  /// renvoie le décompte dans les statistiques de l'historique.
  static Future<int> getMemberAttendanceCountLast3Months(
    String memberId,
  ) async {
    final since = DateTime.now().subtract(const Duration(days: 90));

    final data = await _client.getOne(
      '/church-attendance/member/$memberId',
      query: {'from': _day(since)},
    );

    final stats = (data['stats'] as Map?)?.cast<String, dynamic>();
    return stats?['present'] as int? ?? 0;
  }

  /// Tous les cultes — délègue à [ChurchServiceService].
  static Future<List<Map<String, dynamic>>> getAllServices({
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) {
    return ChurchServiceService.getAllServices(
      startDate: startDate,
      endDate: endDate,
      limit: limit,
    );
  }

  // ---------------------------------------------------------------------------
  // Suppression
  // ---------------------------------------------------------------------------

  /// Supprime un culte et ses présences.
  static Future<void> deleteService({required String churchServiceId}) async {
    await _client.delete('/church-services/$churchServiceId');
  }

  /// Retire une présence.
  ///
  /// Marquer la personne absente est le geste équivalent côté API : il n'y a
  /// pas de suppression unitaire d'une ligne de présence.
  static Future<void> removeAttendance(
    String attendanceId, {
    String? churchServiceId,
    String? memberId,
  }) async {
    if (churchServiceId == null || memberId == null) {
      throw ArgumentError(
        'churchServiceId et memberId sont requis pour retirer une présence.',
      );
    }

    await _client.post(
      '/church-services/$churchServiceId/attendance',
      body: {
        'entries': [
          {'member_id': memberId, 'attendance_type': 'absent'}
        ],
      },
    );
  }

  /// Vérifie la graduation d'un nouveau venu.
  ///
  /// Conservée pour compatibilité : le serveur applique désormais cette règle
  /// automatiquement après chaque pointage. Cette méthode se contente donc de
  /// consulter l'état courant.
  static Future<bool> checkAndUpdateNewComerStatus(String memberId) async {
    try {
      final member = await _client.getOne('/members/$memberId');
      return member['is_new_comer'] == false;
    } catch (_) {
      return false;
    }
  }
}