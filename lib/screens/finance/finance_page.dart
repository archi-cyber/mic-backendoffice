import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/mic_theme.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/routes/route_names.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/utils/error_message_helper.dart';
import '../../services/finance_service.dart';
import '../../services/finance_pdf_service.dart';
import '../desktop/desktop_shell_scope.dart';

/// Finance page for managing giving/tithes/offerings
/// Only accessible to finance department leaders and admins
class FinancePage extends StatefulWidget {
  /// When true (e.g. desktop layout), no app bar is shown.
  final bool hideAppBarAndBottomNav;

  FinancePage({super.key, this.hideAppBarAndBottomNav = false});

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
    if (tag == null) return context.tr('N/A');
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
      // L'accès est vérifié côté serveur : un utilisateur hors du département
      // Finance reçoit un 403, que le bloc catch traduit en message.
      final response = await FinanceService.getAllGivingRecords(limit: 50);

      setState(() {
        _givingRecords = response;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ErrorMessageHelper.showErrorSnackBar(
          context,
          e,
          title: context.tr('Error loading giving records'),
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
        start: DateTime.now().subtract(Duration(days: 30)),
        end: DateTime.now(),
      ),
      helpText: context.tr('Select Date Range for Report'),
    );

    // If user cancelled, return
    if (dateRange == null || !mounted) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(context.tr('Generating PDF report...')),
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
          SnackBar(
            content: Text(context.tr('PDF report saved successfully')),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ErrorMessageHelper.showErrorSnackBar(
          context,
          e,
          title: context.tr('Error saving report'),
        );
      }
    }
  }

  void _openAddGiving(BuildContext context) {
    final scope = DesktopShellScope.maybeOf(context);
    if (scope != null && widget.hideAppBarAndBottomNav) {
      scope.pushDetail(RouteNames.addGiving, '');
    } else {
      Navigator.of(context).pushNamed(RouteNames.addGiving).then((result) {
        if (result == true) _loadGivingRecords();
      });
    }
  }

  void _openEditGiving(BuildContext context, String id) {
    final scope = DesktopShellScope.maybeOf(context);
    if (scope != null && widget.hideAppBarAndBottomNav) {
      scope.pushDetail(RouteNames.editGiving, id);
    } else {
      Navigator.of(
        context,
      ).pushNamed(RouteNames.editGiving.replaceAll(':id', id)).then((result) {
        if (result == true) _loadGivingRecords();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context);
    final isDesktop = widget.hideAppBarAndBottomNav;

    return Scaffold(
      appBar: widget.hideAppBarAndBottomNav
          ? null
          : AppBar(
              title: Text(context.tr('Finance')),
              actions: [
                IconButton(
                  icon: Icon(Icons.picture_as_pdf),
                  onPressed: _generatePdfReport,
                  tooltip: context.tr('Generate PDF Report'),
                ),
                IconButton(
                  icon: Icon(Icons.add),
                  onPressed: () => _openAddGiving(context),
                  tooltip:
                      context.tr('Add Giving Record'),
                ),
              ],
            ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
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
                            color: context.mic.textSecondary,
                          ),
                          SizedBox(height: AppDimensions.spacingMD),
                          Text(
                            localizations?.noGivingRecords ??
                                context.tr('No giving records yet'),
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: context.mic.textSecondary,
                            ),
                          ),
                          SizedBox(height: AppDimensions.spacingSM),
                          ElevatedButton.icon(
                            onPressed: () => _openAddGiving(context),
                            icon: Icon(Icons.add),
                            label: Text(
                              localizations?.addFirstRecord ??
                                  context.tr('Add First Record'),
                            ),
                          ),
                        ],
                      ),
                    )
                  : isDesktop
                  ? _buildDesktopList(context, theme, localizations)
                  : _buildMobileList(context, theme, localizations),
            ),
      floatingActionButton: widget.hideAppBarAndBottomNav
          ? null
          : FloatingActionButton(
              onPressed: () => _openAddGiving(context),
              tooltip: context.tr('Add Giving Record'),
              child: Icon(Icons.add),
            ),
    );
  }

  Widget _buildDesktopList(
    BuildContext context,
    ThemeData theme,
    AppLocalizations? localizations,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: EdgeInsets.all(AppDimensions.paddingMD),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _generatePdfReport,
                      icon: Icon(Icons.picture_as_pdf),
                      label: Text(context.tr('Generate PDF Report')),
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(0, AppDimensions.buttonHeightMD),
                      ),
                    ),
                    SizedBox(width: AppDimensions.spacingMD),
                    ElevatedButton.icon(
                      onPressed: () => _openAddGiving(context),
                      icon: Icon(Icons.add),
                      label: Text(
                        context.tr('Add Giving Record'),
                      ),
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(0, AppDimensions.buttonHeightMD),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppDimensions.spacingMD),
                LayoutBuilder(
                  builder: (context, tableConstraints) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: tableConstraints.maxWidth,
                        ),
                        child: DataTable(
                  columns: [
                    DataColumn(label: Text(context.tr('Giver'))),
                    DataColumn(
                      label: Text(context.tr('Type')),
                    ),
                    DataColumn(label: Text(context.tr('Tag'))),
                    DataColumn(label: Text(context.tr('Date'))),
                    DataColumn(label: Text(context.tr('Amount'))),
                    DataColumn(label: Text('')),
                  ],
                  rows: _givingRecords.map((record) {
                    final canEdit = _canEditRecord(record);
                    final amount =
                        (record['amount'] as num?)?.toDouble() ?? 0.0;
                    return DataRow(
                      cells: [
                        DataCell(
                          Text(
                            record['giver_name'] ??
                                record['member_name'] ??
                                context.tr('Unknown'),
                            style: theme.textTheme.titleMedium,
                          ),
                          onTap: () =>
                              _openEditGiving(context, record['id'].toString()),
                        ),
                        DataCell(Text(record['type'] ?? context.tr('N/A'))),
                        DataCell(
                          Text(
                            _getTagLabel(
                              record['tag']?.toString(),
                              localizations ?? AppLocalizations.of(context)!,
                            ),
                          ),
                        ),
                        DataCell(Text(record['date']?.toString() ?? '')),
                        DataCell(
                          Text(
                            '\$${amount.abs().toStringAsFixed(2)}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: amount < 0
                                  ? AppColors.error
                                  : AppColors.success,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        DataCell(
                          canEdit
                              ? IconButton(
                                  icon: Icon(Icons.edit),
                                  onPressed: () => _openEditGiving(
                                    context,
                                    record['id'].toString(),
                                  ),
                                  tooltip: context.tr('Edit Record'),
                                  iconSize: 20,
                                )
                              : SizedBox.shrink(),
                        ),
                      ],
                    );
                  }).toList(),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _canEditRecord(Map<String, dynamic> record) {
    if (record['created_at'] == null) return false;
    try {
      final createdAt = DateTime.parse(record['created_at']);
      return DateTime.now().difference(createdAt).inDays < 2;
    } catch (e) {
      return false;
    }
  }

  Widget _buildMobileList(
    BuildContext context,
    ThemeData theme,
    AppLocalizations? localizations,
  ) {
    return ListView.builder(
      padding: EdgeInsets.all(AppDimensions.paddingMD),
      itemCount: _givingRecords.length,
      itemBuilder: (context, index) {
        final record = _givingRecords[index];
        final canEdit = _canEditRecord(record);

        return Card(
          margin: EdgeInsets.only(bottom: AppDimensions.spacingMD),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: Icon(
                Icons.account_balance_wallet,
                color: AppColors.primary,
              ),
            ),
            title: Text(
              record['giver_name'] ?? record['member_name'] ?? context.tr('Unknown'),
              style: theme.textTheme.titleMedium,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${context.tr('Type')}: ${record['type'] ?? context.tr('N/A')}',
                  style: theme.textTheme.bodySmall,
                ),
                if (record['tag'] != null)
                  Text(
                    '${context.tr('Tag')}: ${_getTagLabel(record['tag']?.toString(), localizations!)}',
                    style: theme.textTheme.bodySmall,
                  ),
                if (record['date'] != null)
                  Text(
                    '${context.tr('Date')}: ${record['date']}',
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
                    color: ((record['amount'] as num?)?.toDouble() ?? 0.0) < 0.0
                        ? AppColors.error
                        : AppColors.success,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (canEdit) ...[
                  SizedBox(width: AppDimensions.spacingSM),
                  IconButton(
                    icon: Icon(Icons.edit),
                    onPressed: () =>
                        _openEditGiving(context, record['id'].toString()),
                    tooltip: context.tr('Edit Record'),
                    iconSize: 20,
                  ),
                ],
              ],
            ),
            onTap: () => _openEditGiving(context, record['id'].toString()),
          ),
        );
      },
    );
  }
}