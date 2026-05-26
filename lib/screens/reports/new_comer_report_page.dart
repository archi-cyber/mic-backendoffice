import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_dimensions.dart';
import '../../services/new_comer_report_pdf_service.dart';
import '../../services/report_service.dart';

enum _NewComerReportPeriod { weekly, monthly, yearly, custom }

class NewComerReportPage extends StatefulWidget {
  const NewComerReportPage({super.key});

  @override
  State<NewComerReportPage> createState() => _NewComerReportPageState();
}

class _NewComerReportPageState extends State<NewComerReportPage> {
  _NewComerReportPeriod _period = _NewComerReportPeriod.monthly;
  DateTime _referenceDate = DateTime.now();
  int _selectedYear = DateTime.now().year;
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  bool _isLoading = true;
  Map<String, dynamic>? _report;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      Map<String, dynamic> result;
      switch (_period) {
        case _NewComerReportPeriod.weekly:
          result = await ReportService.getWeeklyNewComerReport(
            referenceDate: _referenceDate,
          );
          break;
        case _NewComerReportPeriod.monthly:
          result = await ReportService.getMonthlyNewComerReport(
            referenceDate: _referenceDate,
          );
          break;
        case _NewComerReportPeriod.yearly:
          result = await ReportService.getYearlyNewComerReport(
            year: _selectedYear,
          );
          break;
        case _NewComerReportPeriod.custom:
          result = await ReportService.getNewComerReport(
            fromDate: _customStartDate,
            toDate: _customEndDate,
          );
          break;
      }

      if (!mounted) return;
      setState(() {
        _report = result;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _pickCustomDate({required bool isStart}) async {
    final initial = isStart
        ? (_customStartDate ?? DateTime.now())
        : (_customEndDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: isStart ? 'Select start date' : 'Select end date',
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _customStartDate = picked;
      } else {
        _customEndDate = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final summary =
        (_report?['status_summary'] as Map<String, dynamic>?) ?? const {};
    final records =
        List<Map<String, dynamic>>.from(_report?['records'] as List? ?? const []);

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Comers Report'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _generatePdfReport,
            tooltip: 'Generate PDF Report',
            icon: const Icon(Icons.picture_as_pdf),
          ),
          IconButton(
            onPressed: _isLoading ? null : _loadReport,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingMD),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: AppDimensions.spacingSM,
                  runSpacing: AppDimensions.spacingSM,
                  children: [
                    ChoiceChip(
                      label: const Text('Weekly'),
                      selected: _period == _NewComerReportPeriod.weekly,
                      onSelected: (_) {
                        setState(() => _period = _NewComerReportPeriod.weekly);
                        _loadReport();
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Monthly'),
                      selected: _period == _NewComerReportPeriod.monthly,
                      onSelected: (_) {
                        setState(() => _period = _NewComerReportPeriod.monthly);
                        _loadReport();
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Yearly'),
                      selected: _period == _NewComerReportPeriod.yearly,
                      onSelected: (_) {
                        setState(() => _period = _NewComerReportPeriod.yearly);
                        _loadReport();
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Custom'),
                      selected: _period == _NewComerReportPeriod.custom,
                      onSelected: (_) {
                        setState(() => _period = _NewComerReportPeriod.custom);
                        _loadReport();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.spacingSM),
                if (_period == _NewComerReportPeriod.yearly)
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: _selectedYear,
                          decoration: const InputDecoration(labelText: 'Year'),
                          items: List.generate(10, (i) => DateTime.now().year - i)
                              .map(
                                (y) => DropdownMenuItem<int>(
                                  value: y,
                                  child: Text(y.toString()),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _selectedYear = value);
                            _loadReport();
                          },
                        ),
                      ),
                    ],
                  ),
                if (_period == _NewComerReportPeriod.custom)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickCustomDate(isStart: true),
                          icon: const Icon(Icons.calendar_today),
                          label: Text(
                            _customStartDate == null
                                ? 'Start date'
                                : DateFormat('yyyy-MM-dd').format(_customStartDate!),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppDimensions.spacingSM),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickCustomDate(isStart: false),
                          icon: const Icon(Icons.calendar_today),
                          label: Text(
                            _customEndDate == null
                                ? 'End date'
                                : DateFormat('yyyy-MM-dd').format(_customEndDate!),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppDimensions.spacingSM),
                      ElevatedButton(
                        onPressed: _loadReport,
                        child: const Text('Apply'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Expanded(
              child: Center(
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.paddingMD,
                  vertical: AppDimensions.spacingSM,
                ),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: 'New Comers',
                          value: '${summary['new_comer'] ?? 0}',
                        ),
                      ),
                      const SizedBox(width: AppDimensions.spacingSM),
                      Expanded(
                        child: _StatCard(
                          label: 'Members',
                          value: '${summary['member'] ?? 0}',
                        ),
                      ),
                      const SizedBox(width: AppDimensions.spacingSM),
                      Expanded(
                        child: _StatCard(
                          label: 'Visitors',
                          value: '${summary['visitor'] ?? 0}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.spacingMD),
                  Text(
                    'Records (${records.length})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppDimensions.spacingSM),
                  if (records.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(AppDimensions.paddingMD),
                        child: Text('No newcomer records found for this period.'),
                      ),
                    )
                  else
                    ...records.map((record) {
                      final fullName =
                          '${record['first_name'] ?? ''} ${record['last_name'] ?? ''}'
                              .trim();
                      final status = (record['current_status'] ?? 'visitor')
                          .toString()
                          .replaceAll('_', ' ');
                      return Card(
                        child: ListTile(
                          title: Text(fullName.isEmpty ? 'Unknown' : fullName),
                          subtitle: Text(
                            'Joined: ${record['newcomer_join_date'] ?? '-'}\nStatus: $status',
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _generatePdfReport() async {
    try {
      DateTime? startDate;
      DateTime? endDate;

      switch (_period) {
        case _NewComerReportPeriod.weekly:
          final start = DateTime(
            _referenceDate.year,
            _referenceDate.month,
            _referenceDate.day,
          ).subtract(Duration(days: _referenceDate.weekday - DateTime.monday));
          startDate = start;
          endDate = start.add(const Duration(days: 6));
          break;
        case _NewComerReportPeriod.monthly:
          startDate = DateTime(_referenceDate.year, _referenceDate.month, 1);
          endDate = DateTime(_referenceDate.year, _referenceDate.month + 1, 0);
          break;
        case _NewComerReportPeriod.yearly:
          startDate = DateTime(_selectedYear, 1, 1);
          endDate = DateTime(_selectedYear, 12, 31);
          break;
        case _NewComerReportPeriod.custom:
          startDate = _customStartDate;
          endDate = _customEndDate;
          break;
      }

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()),
        );
      }

      final filePath = await NewComerReportPdfService.generateReport(
        startDate: startDate,
        endDate: endDate,
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF report generated: ${filePath ?? 'saved'}'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate PDF report: $e')),
      );
    }
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingMD),
        child: Column(
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: AppDimensions.spacingXS),
            Text(label),
          ],
        ),
      ),
    );
  }
}
