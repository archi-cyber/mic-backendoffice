import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/routes/route_names.dart';
import '../../core/localization/app_localizations.dart';
import '../../services/supabase_service.dart';
import '../../services/finance_pdf_service.dart';

/// Finance page for managing giving/tithes/offerings
/// Only accessible to finance department leaders and admins
class FinancePage extends StatefulWidget {
  /// When true (e.g. desktop layout), no app bar is shown.
  final bool hideAppBarAndBottomNav;

  const FinancePage({super.key, this.hideAppBarAndBottomNav = false});

  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> {
  List<Map<String, dynamic>> _givingRecords = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGivingRecords();
  }

  String _getTagLabel(String? tag, AppLocalizations localizations) {
    if (tag == null) return 'N/A';
    switch (tag) {
      case 'construction':
        return localizations.construction;
      case 'special_op':
        return localizations.specialOperation;
      case 'tithe':
        return localizations.tithe;
      case 'offering':
        return localizations.offering;
      case 'gift':
        return localizations.gift;
      case 'other':
        return localizations.other;
      default:
        return tag;
    }
  }

  Future<void> _loadGivingRecords() async {
    setState(() => _isLoading = true);
    try {
      final response = await SupabaseService.client
          .from('giving')
          .select()
          .order('created_at', ascending: false)
          .limit(50);

      setState(() {
        _givingRecords = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.errorLoadingGivingRecords ??
                  'Error loading giving records: $e',
            ),
          ),
        );
      }
    }
  }

  Future<void> _generatePdfReport() async {
    if (!mounted) return;

    // Show date range picker dialog first
    final dateRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: DateTime.now().subtract(const Duration(days: 30)),
        end: DateTime.now(),
      ),
      helpText: 'Select Date Range for Report',
    );

    // If user cancelled, return
    if (dateRange == null || !mounted) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Generating PDF report...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      await FinancePdfService.generateAndSaveReport(
        fromDate: dateRange.start,
        toDate: dateRange.end,
      );
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF report saved successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving report: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: widget.hideAppBarAndBottomNav
          ? null
          : AppBar(
              title: Text(localizations?.finance ?? 'Finance'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf),
                  onPressed: _generatePdfReport,
                  tooltip: 'Generate PDF Report',
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () async {
                    final result = await Navigator.of(
                      context,
                    ).pushNamed(RouteNames.addGiving);
                    if (result == true) {
                      _loadGivingRecords();
                    }
                  },
                  tooltip:
                      localizations?.addGivingRecord ?? 'Add Giving Record',
                ),
              ],
            ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadGivingRecords,
              child: _givingRecords.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.account_balance_wallet_outlined,
                            size: 64,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(height: AppDimensions.spacingMD),
                          Text(
                            localizations?.noGivingRecords ??
                                'No giving records yet',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppDimensions.spacingSM),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final result = await Navigator.of(
                                context,
                              ).pushNamed(RouteNames.addGiving);
                              // Refresh the list if a new record was created
                              if (result == true) {
                                _loadGivingRecords();
                              }
                            },
                            icon: const Icon(Icons.add),
                            label: Text(
                              localizations?.addFirstRecord ??
                                  'Add First Record',
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(AppDimensions.paddingMD),
                      itemCount: _givingRecords.length,
                      itemBuilder: (context, index) {
                        final record = _givingRecords[index];

                        // Check if record can be edited (created within 2 days)
                        bool canEdit = false;
                        if (record['created_at'] != null) {
                          try {
                            final createdAt = DateTime.parse(
                              record['created_at'],
                            );
                            final now = DateTime.now();
                            final difference = now.difference(createdAt);
                            canEdit = difference.inDays < 2;
                          } catch (e) {
                            // If parsing fails, cannot edit
                            canEdit = false;
                          }
                        }

                        return Card(
                          margin: const EdgeInsets.only(
                            bottom: AppDimensions.spacingMD,
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primary.withOpacity(
                                0.1,
                              ),
                              child: Icon(
                                Icons.account_balance_wallet,
                                color: AppColors.primary,
                              ),
                            ),
                            title: Text(
                              record['giver_name'] ??
                                  record['member_name'] ??
                                  'Unknown',
                              style: theme.textTheme.titleMedium,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${localizations?.transactionType ?? 'Type'}: ${record['type'] ?? 'N/A'}',
                                  style: theme.textTheme.bodySmall,
                                ),
                                if (record['tag'] != null)
                                  Text(
                                    '${localizations?.tag ?? 'Tag'}: ${_getTagLabel(record['tag']?.toString(), localizations!)}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                if (record['date'] != null)
                                  Text(
                                    '${localizations?.date ?? 'Date'}: ${record['date']}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '\$${(record['amount'] as num?)?.abs().toStringAsFixed(2) ?? '0.00'}',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color:
                                        ((record['amount'] as num?)
                                                    ?.toDouble() ??
                                                0.0) <
                                            0.0
                                        ? AppColors.error
                                        : AppColors.success,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (canEdit) ...[
                                  const SizedBox(
                                    width: AppDimensions.spacingSM,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () async {
                                      final result = await Navigator.of(context)
                                          .pushNamed(
                                            RouteNames.editGiving.replaceAll(
                                              ':id',
                                              record['id'].toString(),
                                            ),
                                          );
                                      // Refresh the list if record was updated
                                      if (result == true) {
                                        _loadGivingRecords();
                                      }
                                    },
                                    tooltip:
                                        localizations?.edit ?? 'Edit Record',
                                    iconSize: 20,
                                  ),
                                ],
                              ],
                            ),
                            onTap: () async {
                              final result = await Navigator.of(context)
                                  .pushNamed(
                                    RouteNames.editGiving.replaceAll(
                                      ':id',
                                      record['id'].toString(),
                                    ),
                                  );
                              // Refresh the list if record was updated
                              if (result == true) {
                                _loadGivingRecords();
                              }
                            },
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.of(
            context,
          ).pushNamed(RouteNames.addGiving);
          // Refresh the list if a new record was created
          if (result == true) {
            _loadGivingRecords();
          }
        },
        tooltip: localizations?.addGivingRecord ?? 'Add Giving Record',
        child: const Icon(Icons.add),
      ),
    );
  }
}
