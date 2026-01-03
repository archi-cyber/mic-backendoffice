import 'supabase_service.dart';

/// Finance service for checking finance department access
class FinanceService {
  static final _client = SupabaseService.client;

  /// Check if the current user is a finance department leader or admin
  /// Returns true if user is admin or leader of finance department
  static Future<bool> isFinanceLeader() async {
    try {
      final currentUserId = SupabaseService.currentUser?.id;
      if (currentUserId == null) return false;

      // Check if user is admin
      final user = await _client
          .from('users')
          .select('role, is_active')
          .eq('id', currentUserId)
          .maybeSingle();

      if (user == null) return false;

      final role = user['role'] as String?;
      final isActive = user['is_active'] == true;

      // Admin always has access
      if (role == 'admin' && isActive) {
        return true;
      }

      // Check if user is a leader of the finance department
      if (role == 'leader' && isActive) {
        final memberId = await _client
            .from('users')
            .select('member_id')
            .eq('id', currentUserId)
            .maybeSingle();

        if (memberId == null || memberId['member_id'] == null) return false;

        final financeDept = await _client
            .from('departments')
            .select('id')
            .eq('name', 'Finance')
            .eq('is_active', true)
            .maybeSingle();

        if (financeDept == null) return false;

        final financeDeptIdValue = financeDept['id'];
        if (financeDeptIdValue == null) return false;

        final financeDeptId = financeDeptIdValue.toString();
        final memberIdValue = (memberId['member_id'] as dynamic)?.toString();
        if (memberIdValue == null) return false;

        final isFinanceMember = await _client
            .from('department_members')
            .select('id')
            .eq('department_id', financeDeptId)
            .eq('member_id', memberIdValue)
            .maybeSingle();

        return isFinanceMember != null;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Get finance department ID
  static Future<String?> getFinanceDepartmentId() async {
    try {
      final financeDept = await _client
          .from('departments')
          .select('id')
          .eq('name', 'Finance')
          .eq('is_active', true)
          .maybeSingle();

      return financeDept?['id']?.toString();
    } catch (e) {
      return null;
    }
  }

  /// Get active members for dropdown selection
  static Future<List<Map<String, dynamic>>> getActiveMembers() async {
    try {
      final response = await _client
          .from('members')
          .select('id, first_name, last_name')
          .eq('is_active', true)
          .order('first_name', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch members: $e');
    }
  }

  /// Get giving record by ID
  static Future<Map<String, dynamic>> getGivingRecordById(
    String givingId,
  ) async {
    try {
      final response = await _client
          .from('giving')
          .select()
          .eq('id', givingId)
          .single();

      return response;
    } catch (e) {
      throw Exception('Failed to get giving record: $e');
    }
  }

  /// Create a giving record
  /// Parameters:
  /// - giverName: Name of the giver (member or external person)
  /// - amount: Amount given (positive number)
  /// - tag: Category tag (construction, special_op, tithe, offering, gift, other)
  /// - isExpense: true for expense, false for receiving money
  /// - description: Description of the transaction
  /// - memberId: Optional member ID if giver is a member
  static Future<Map<String, dynamic>> createGivingRecord({
    required String giverName,
    required double amount,
    required String tag,
    required bool isExpense,
    String? notes,
    String? memberId,
  }) async {
    try {
      // Validate amount
      if (amount <= 0) {
        throw Exception('Amount must be greater than zero');
      }

      // Validate tag
      const validTags = [
        'construction',
        'special_op',
        'tithe',
        'offering',
        'gift',
        'other',
      ];
      if (!validTags.contains(tag)) {
        throw Exception('Invalid tag. Must be one of: ${validTags.join(", ")}');
      }

      // Prepare data for insertion
      final givingData = {
        'giver_name': giverName,
        'amount': isExpense
            ? -amount.abs()
            : amount.abs(), // Negative for expenses
        'tag': tag,
        'type': isExpense ? 'expense' : 'receiving',
        'notes': notes,
        'member_id': memberId,
        'date': DateTime.now().toIso8601String().split('T')[0], // Current date
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await _client
          .from('giving')
          .insert(givingData)
          .select()
          .single();

      return response;
    } catch (e) {
      throw Exception('Failed to create giving record: $e');
    }
  }

  /// Update a giving record
  /// Parameters:
  /// - givingId: ID of the giving record to update
  /// - giverName: Name of the giver (member or external person)
  /// - amount: Amount given (positive number)
  /// - tag: Category tag (construction, special_op, tithe, offering, gift, other)
  /// - isExpense: true for expense, false for receiving money
  /// - notes: Optional description
  /// - memberId: Optional member ID if giver is a member
  static Future<Map<String, dynamic>> updateGivingRecord({
    required String givingId,
    required String giverName,
    required double amount,
    required String tag,
    required bool isExpense,
    String? notes,
    String? memberId,
  }) async {
    try {
      // Validate amount
      if (amount <= 0) {
        throw Exception('Amount must be greater than zero');
      }

      // Validate tag
      const validTags = [
        'construction',
        'special_op',
        'tithe',
        'offering',
        'gift',
        'other',
      ];
      if (!validTags.contains(tag)) {
        throw Exception('Invalid tag. Must be one of: ${validTags.join(", ")}');
      }

      // Prepare data for update
      final givingData = {
        'giver_name': giverName,
        'amount': isExpense
            ? -amount.abs()
            : amount.abs(), // Negative for expenses
        'tag': tag,
        'type': isExpense ? 'expense' : 'receiving',
        'notes': notes,
        'member_id': memberId,
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await _client
          .from('giving')
          .update(givingData)
          .eq('id', givingId)
          .select()
          .single();

      return response;
    } catch (e) {
      throw Exception('Failed to update giving record: $e');
    }
  }

  /// Get all giving records for reporting
  /// Parameters:
  /// - fromDate: Optional start date filter
  /// - toDate: Optional end date filter
  static Future<List<Map<String, dynamic>>> getAllGivingRecords({
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      var query = _client.from('giving').select();

      if (fromDate != null) {
        query = query.gte('date', fromDate.toIso8601String().split('T')[0]);
      }
      if (toDate != null) {
        query = query.lte('date', toDate.toIso8601String().split('T')[0]);
      }

      final response = await query.order('date', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch giving records: $e');
    }
  }
}
