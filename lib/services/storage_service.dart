import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'package:path/path.dart' as path;

/// Storage service for file uploads to Supabase Storage
class StorageService {
  static final _client = SupabaseService.client;
  static const String departmentDocumentsBucket = 'department-documents';
  static const String memberPhotosBucket = 'member-photos';

  /// Upload a file to Supabase Storage
  /// Returns the public URL of the uploaded file
  static Future<String> uploadFile({
    required File file,
    required String folder, // e.g., 'departments/{departmentId}'
    String? fileName,
    String bucketName = departmentDocumentsBucket,
  }) async {
    try {
      // Use provided fileName or extract from file path
      final name = fileName ?? path.basename(file.path);

      // Generate unique filename to avoid conflicts
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = path.extension(name);
      final baseName = path.basenameWithoutExtension(name);
      final uniqueFileName = '${baseName}_$timestamp$extension';

      // Full path in storage
      final filePath = '$folder/$uniqueFileName';

      // Read file bytes
      final fileBytes = await file.readAsBytes();

      // Upload to Supabase Storage
      await _client.storage
          .from(bucketName)
          .uploadBinary(
            filePath,
            fileBytes,
            fileOptions: const FileOptions(
              upsert: true, // Replace if exists
            ),
          );

      // Get public URL
      final url = _client.storage.from(bucketName).getPublicUrl(filePath);

      return url;
    } catch (e) {
      final errorMessage = e.toString();
      if (errorMessage.contains('Bucket not found')) {
        throw Exception(
          'Storage bucket "$bucketName" not found. '
          'Please create the bucket in Supabase Dashboard → Storage → Create Bucket. '
          'Bucket name: $bucketName',
        );
      }
      throw Exception('Failed to upload file: $e');
    }
  }

  /// Upload a member profile photo.
  static Future<String> uploadMemberPhoto({
    required File file,
    required String memberId,
  }) {
    return uploadFile(
      file: file,
      folder: 'members/$memberId',
      fileName: 'profile.jpg',
      bucketName: memberPhotosBucket,
    );
  }

  /// Delete a file from Supabase Storage
  static Future<void> deleteFile(
    String fileUrl, {
    String bucketName = departmentDocumentsBucket,
  }) async {
    try {
      // Extract file path from URL
      final uri = Uri.parse(fileUrl);
      final pathSegments = uri.pathSegments;

      // Find the bucket name index and get path after it
      final bucketIndex = pathSegments.indexOf(bucketName);
      if (bucketIndex == -1 || bucketIndex == pathSegments.length - 1) {
        throw Exception('Invalid file URL');
      }

      final filePath = pathSegments.sublist(bucketIndex + 1).join('/');

      await _client.storage.from(bucketName).remove([filePath]);
    } catch (e) {
      throw Exception('Failed to delete file: $e');
    }
  }

  /// Delete multiple files
  static Future<void> deleteFiles(
    List<String> fileUrls, {
    String bucketName = departmentDocumentsBucket,
  }) async {
    try {
      final filePaths = <String>[];

      for (final url in fileUrls) {
        final uri = Uri.parse(url);
        final pathSegments = uri.pathSegments;
        final bucketIndex = pathSegments.indexOf(bucketName);

        if (bucketIndex != -1 && bucketIndex < pathSegments.length - 1) {
          final filePath = pathSegments.sublist(bucketIndex + 1).join('/');
          filePaths.add(filePath);
        }
      }

      if (filePaths.isNotEmpty) {
        await _client.storage.from(bucketName).remove(filePaths);
      }
    } catch (e) {
      throw Exception('Failed to delete files: $e');
    }
  }

  /// Extract file path from a Supabase Storage URL
  static String? extractFilePath(
    String fileUrl, {
    String bucketName = departmentDocumentsBucket,
  }) {
    try {
      final uri = Uri.parse(fileUrl);
      final pathSegments = uri.pathSegments;
      final bucketIndex = pathSegments.indexOf(bucketName);

      if (bucketIndex != -1 && bucketIndex < pathSegments.length - 1) {
        return pathSegments.sublist(bucketIndex + 1).join('/');
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Create a signed URL for a file (valid for 1 hour by default)
  /// This is useful for private buckets or when you need temporary access
  static Future<String> createSignedUrl(
    String fileUrl, {
    int expiresIn = 3600, // 1 hour in seconds
    String bucketName = departmentDocumentsBucket,
  }) async {
    try {
      final filePath = extractFilePath(fileUrl, bucketName: bucketName);
      if (filePath == null) {
        throw Exception('Invalid file URL: $fileUrl');
      }

      final signedUrl = await _client.storage
          .from(bucketName)
          .createSignedUrl(filePath, expiresIn);

      return signedUrl;
    } catch (e) {
      throw Exception('Failed to create signed URL: $e');
    }
  }
}
