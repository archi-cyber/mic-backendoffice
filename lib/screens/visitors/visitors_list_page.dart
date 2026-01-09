import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/routes/route_names.dart';
import '../../core/utils/permission_helper.dart';
import '../../services/visitor_service.dart';

/// Visitors list page
class VisitorsListPage extends StatefulWidget {
  const VisitorsListPage({super.key});

  @override
  State<VisitorsListPage> createState() => _VisitorsListPageState();
}

class _VisitorsListPageState extends State<VisitorsListPage> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _visitors = [];
  bool _isLoading = true;
  bool _canEdit = false;
  bool _canDelete = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _loadVisitors();
  }

  Future<void> _checkPermissions() async {
    final canEdit = await PermissionHelper.canEdit('visitors');
    final canDelete = await PermissionHelper.canDelete('visitors');
    setState(() {
      _canEdit = canEdit;
      _canDelete = canDelete;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadVisitors() async {
    setState(() => _isLoading = true);
    try {
      final visitors = await VisitorService.getVisitors(limit: 200);
      setState(() {
        _visitors = visitors;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading visitors: $e')),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredVisitors {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      return _visitors;
    }
    return _visitors.where((visitor) {
      final name = '${visitor['first_name']} ${visitor['last_name']}'
          .toLowerCase();
      final email = (visitor['email'] ?? '').toLowerCase();
      final phone = (visitor['phone'] ?? '').toLowerCase();
      return name.contains(query) || 
             email.contains(query) || 
             phone.contains(query);
    }).toList();
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }

  Future<void> _deleteVisitor(String visitorId, String visitorName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Visitor'),
        content: Text('Are you sure you want to delete "$visitorName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await VisitorService.deleteVisitor(visitorId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Visitor deleted successfully'),
              backgroundColor: AppColors.success,
            ),
          );
          _loadVisitors();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting visitor: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Widget _buildVisitorCard(Map<String, dynamic> visitor) {
    final firstName = visitor['first_name']?.toString() ?? '';
    final lastName = visitor['last_name']?.toString() ?? '';
    final fullName = '$firstName $lastName'.trim();
    final email = visitor['email']?.toString() ?? '';
    final phone = visitor['phone']?.toString() ?? '';
    final visitDate = visitor['visit_date'] != null
        ? DateTime.parse(visitor['visit_date'])
        : null;
    final visitorId = visitor['id'].toString();

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingMD,
        vertical: AppDimensions.spacingSM,
      ),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    fullName.isEmpty ? 'Unnamed Visitor' : fullName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (_canEdit) ...[
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    color: AppColors.primary,
                    onPressed: () async {
                      final result = await Navigator.of(context).pushNamed(
                        RouteNames.editVisitor.replaceAll(':id', visitorId),
                      );
                      if (result == true) {
                        _loadVisitors();
                      }
                    },
                    tooltip: 'Edit Visitor',
                  ),
                ],
                if (_canDelete) ...[
                  IconButton(
                    icon: const Icon(Icons.delete, size: 20),
                    color: AppColors.error,
                    onPressed: () => _deleteVisitor(visitorId, fullName),
                    tooltip: 'Delete Visitor',
                  ),
                ],
              ],
            ),
            if (visitDate != null) ...[
              const SizedBox(height: AppDimensions.spacingXS),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppDimensions.spacingXS),
                  Text(
                    'Visited: ${_formatDate(visitDate)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
            if (email.isNotEmpty) ...[
              const SizedBox(height: AppDimensions.spacingXS),
              Row(
                children: [
                  const Icon(
                    Icons.email_outlined,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppDimensions.spacingXS),
                  Expanded(
                    child: Text(
                      email,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (phone.isNotEmpty) ...[
              const SizedBox(height: AppDimensions.spacingXS),
              Row(
                children: [
                  const Icon(
                    Icons.phone_outlined,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppDimensions.spacingXS),
                  Expanded(
                    child: Text(
                      phone,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (visitor['notes'] != null && visitor['notes'].toString().isNotEmpty) ...[
              const SizedBox(height: AppDimensions.spacingXS),
              Text(
                visitor['notes'].toString(),
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Visitors (${_filteredVisitors.length})'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadVisitors,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingMD),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search visitors...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          // Visitors list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredVisitors.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.person_outline,
                          size: 64,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: AppDimensions.spacingMD),
                        Text(
                          _searchController.text.isNotEmpty
                              ? 'No visitors found matching your search'
                              : 'No visitors yet',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadVisitors,
                    child: ListView.builder(
                      itemCount: _filteredVisitors.length,
                      itemBuilder: (context, index) {
                        return _buildVisitorCard(_filteredVisitors[index]);
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FutureBuilder<bool>(
        future: PermissionHelper.canCreate('visitors'),
        builder: (context, snapshot) {
          final canCreate = snapshot.data ?? false;
          if (!canCreate) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: () async {
              final result = await Navigator.of(context).pushNamed(
                RouteNames.addVisitor,
              );
              if (result == true) {
                _loadVisitors();
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Visitor'),
          );
        },
      ),
    );
  }
}
