import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../config/app_config.dart';
import 'auth_service.dart';

/// Envoi et suppression de fichiers.
///
/// Signatures identiques à l'implémentation Supabase Storage. Le paramètre
/// `bucketName` est conservé pour compatibilité, mais sert désormais de
/// **préfixe de dossier** : le stockage repose sur un volume Railway, où les
/// fichiers sont rangés par répertoire plutôt que par bucket.
///
/// Différence de fond : les URL renvoyées sont relatives (`/files/...`).
/// [absoluteUrl] les complète pour l'affichage.
class StorageService {
  /// Dossiers, remplaçant les buckets Supabase.
  static const String departmentDocumentsBucket = 'departments';
  static const String memberPhotosBucket = 'members';

  static Dio get _dio => Dio(
        BaseOptions(
          baseUrl: AppConfig.apiUrl,
          connectTimeout: AppConfig.connectTimeout,
          // L'envoi d'un fichier peut être long sur une connexion mobile :
          // le délai standard de trente secondes serait dépassé par une photo
          // de plusieurs mégaoctets en 3G.
          sendTimeout: const Duration(minutes: 3),
          receiveTimeout: const Duration(minutes: 3),
          validateStatus: (_) => true,
        ),
      );

  /// Envoie un fichier et renvoie son URL relative.
  ///
  /// [folder] range le fichier par domaine, par exemple
  /// `departments/{departmentId}`. Le chemin est nettoyé côté serveur : un
  /// dossier fourni par le client ne peut pas sortir du volume.
  ///
  /// [fileName] est ignoré : le serveur génère un identifiant aléatoire et ne
  /// conserve que l'extension. Réutiliser le nom d'origine exposerait à des
  /// collisions et à des séquences de traversée.
  static Future<String> uploadFile({
    required File file,
    required String folder,
    String? fileName,
    String bucketName = departmentDocumentsBucket,
  }) async {
    final token = await AuthService.client.tokens.getAccessToken();

    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        file.path,
        filename: p.basename(file.path),
      ),
    });

    final response = await _dio.post(
      '/storage/upload',
      data: form,
      queryParameters: {'folder': '$bucketName/$folder'},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      final body = response.data;
      final message = body is Map ? body['message'] : null;
      throw Exception(message ?? "Échec de l'envoi du fichier.");
    }

    final data = (response.data as Map)['data'] as Map;
    final url = data['url'] as String;

    debugPrint('[Storage] Fichier envoyé : $url');

    return url;
  }

  /// Envoie la photo d'un membre.
  static Future<String> uploadMemberPhoto({
    required File file,
    required String memberId,
  }) {
    return uploadFile(
      file: file,
      folder: 'photos/$memberId',
      bucketName: memberPhotosBucket,
    );
  }

  /// Supprime un fichier.
  ///
  /// L'absence du fichier n'est pas traitée comme une erreur : le résultat
  /// voulu est atteint, et faire échouer l'appel obligerait chaque appelant à
  /// gérer ce cas sans bénéfice.
  static Future<void> deleteFile(
    String fileUrl, {
    String bucketName = departmentDocumentsBucket,
  }) async {
    final path = extractFilePath(fileUrl, bucketName: bucketName);
    if (path == null) return;

    try {
      await AuthService.client.delete('/storage/$path');
    } catch (error) {
      debugPrint('[Storage] Suppression impossible : $error');
    }
  }

  static Future<void> deleteFiles(
    List<String> fileUrls, {
    String bucketName = departmentDocumentsBucket,
  }) async {
    for (final url in fileUrls) {
      await deleteFile(url, bucketName: bucketName);
    }
  }

  /// Extrait le chemin relatif depuis une URL.
  ///
  /// Accepte aussi bien `/files/members/photos/x.jpg` que l'URL absolue.
  static String? extractFilePath(
    String fileUrl, {
    String bucketName = departmentDocumentsBucket,
  }) {
    final match = RegExp(r'/files/(.+)$').firstMatch(fileUrl);
    return match?.group(1);
  }

  /// URL complète, prête pour un widget `Image.network`.
  ///
  /// Les URL stockées en base sont relatives : elles restent valides si le
  /// domaine du serveur change, ce qu'une URL absolue ne permettrait pas sans
  /// réécrire toutes les lignes.
  static String absoluteUrl(String relativeUrl) {
    if (relativeUrl.startsWith('http')) return relativeUrl;
    return '${AppConfig.apiBaseUrl}$relativeUrl';
  }

  /// URL de lecture d'un fichier.
  ///
  /// Conservée pour compatibilité avec les URL signées de Supabase. Le
  /// stockage actuel n'en produit pas : la protection repose sur
  /// l'imprévisibilité du nom, chaque fichier portant un UUID.
  ///
  /// Ce modèle convient aux photos et documents courants. Pour des pièces
  /// véritablement confidentielles, il faudrait des URL à durée limitée.
  static Future<String> createSignedUrl(
    String fileUrl, {
    int expiresIn = 3600,
    String bucketName = departmentDocumentsBucket,
  }) async {
    return absoluteUrl(fileUrl);
  }
}