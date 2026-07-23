import 'package:flutter/foundation.dart' show debugPrint;
import 'supabase_service.dart';

/// CRUD for church gatherings (any date + required name; multiple per day allowed).
class ChurchServiceService {
  static final _client = SupabaseService.client;

  static String _dateOnly(DateTime date) =>
      date.toIso8601String().split('T')[0];

  /// Create a church service. [name] is required and must be unique for that date.
  static Future<Map<String, dynamic>> createService({
    required DateTime serviceDate,
    required String name,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw Exception('Service name is required');
    }

    final currentUser = SupabaseService.currentUser;
    if (currentUser == null) {
      throw Exception('User must be authenticated to create a service');
    }

    try {
      final response = await _client
          .from('church_services')
          .insert({
            'service_date': _dateOnly(serviceDate),
            'name': trimmed,
            'created_by': currentUser.id,
          })
          .select()
          .single();
      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint('[ChurchServiceService] Error creating service: $e');
      throw Exception('Failed to create service: $e');
    }
  }

  /// Find a service by date + name, or create it if missing.
  static Future<Map<String, dynamic>> findOrCreate({
    required DateTime serviceDate,
    required String name,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw Exception('Service name is required');
    }

    final existing = await getServicesForDate(serviceDate);
    for (final service in existing) {
      final existingName = service['name']?.toString().trim() ?? '';
      if (existingName.toLowerCase() == trimmed.toLowerCase()) {
        return service;
      }
    }
    return createService(serviceDate: serviceDate, name: trimmed);
  }

  static Future<Map<String, dynamic>?> getById(String serviceId) async {
    try {
      final response = await _client
          .from('church_services')
          .select()
          .eq('id', serviceId)
          .maybeSingle();
      if (response == null) return null;
      final row = Map<String, dynamic>.from(response);
      if (row['deleted_at'] != null) return null;
      return row;
    } catch (e) {
      debugPrint('[ChurchServiceService] Error getting service: $e');
      throw Exception('Failed to get service: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getServicesForDate(
    DateTime serviceDate,
  ) async {
    try {
      final response = await _client
          .from('church_services')
          .select()
          .eq('service_date', _dateOnly(serviceDate))
          .isFilter('deleted_at', null)
          .order('name', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('[ChurchServiceService] Error listing services for date: $e');
      throw Exception('Failed to list services: $e');
    }
  }

  /// List services with optional date range, newest first.
  static Future<List<Map<String, dynamic>>> getAllServices({
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    try {
      dynamic query = _client
          .from('church_services')
          .select()
          .isFilter('deleted_at', null);

      if (startDate != null) {
        query = query.gte('service_date', _dateOnly(startDate));
      }
      if (endDate != null) {
        query = query.lte('service_date', _dateOnly(endDate));
      }

      query = query.order('service_date', ascending: false).order('name');

      if (limit != null) {
        query = query.limit(limit);
      }

      final response = await query;
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('[ChurchServiceService] Error listing services: $e');
      throw Exception('Failed to list services: $e');
    }
  }

  static Future<Map<String, dynamic>> updateService({
    required String serviceId,
    String? name,
    DateTime? serviceDate,
  }) async {
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (name != null) {
      final trimmed = name.trim();
      if (trimmed.isEmpty) {
        throw Exception('Service name is required');
      }
      updates['name'] = trimmed;
    }
    if (serviceDate != null) {
      updates['service_date'] = _dateOnly(serviceDate);
    }

    try {
      final response = await _client
          .from('church_services')
          .update(updates)
          .eq('id', serviceId)
          .select()
          .single();

      // Keep denormalized attendance dates in sync when the service date moves.
      if (serviceDate != null) {
        await _client
            .from('church_attendance')
            .update({
              'service_date': _dateOnly(serviceDate),
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('church_service_id', serviceId)
            .isFilter('deleted_at', null);
      }

      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint('[ChurchServiceService] Error updating service: $e');
      throw Exception('Failed to update service: $e');
    }
  }

  /// Soft-delete the service row (caller should soft-delete attendance/visitors).
  static Future<void> softDelete(String serviceId) async {
    try {
      final deletedAt = DateTime.now().toIso8601String();
      await _client
          .from('church_services')
          .update({'deleted_at': deletedAt, 'updated_at': deletedAt})
          .eq('id', serviceId)
          .isFilter('deleted_at', null);
    } catch (e) {
      debugPrint('[ChurchServiceService] Error deleting service: $e');
      throw Exception('Failed to delete service: $e');
    }
  }
}
