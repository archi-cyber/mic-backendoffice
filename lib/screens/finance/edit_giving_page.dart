import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/localization/app_localizations.dart';
import '../../services/finance_service.dart';

/// Edit giving page - Editable within 2 days of creation, read-only after
class EditGivingPage extends StatefulWidget {
  final String givingId;

  const EditGivingPage({super.key, required this.givingId});

  @override
  State<EditGivingPage> createState() => _EditGivingPageState();
}

class _EditGivingPageState extends State<EditGivingPage> {
  final _formKey = GlobalKey<FormState>();
  final _giverNameController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  Map<String, dynamic>? _givingRecord;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _canEdit = false; // Can only edit if created within 2 days
  String? _selectedMemberId;
  String? _selectedTag;
  bool _isExpense = false;
  bool _isLoadingMembers = false;
  List<Map<String, dynamic>> _members = [];
  bool _isExternalGiver = false;

  List<Map<String, String>> _getTagOptions(AppLocalizations localizations) {
    return [
      {'value': 'construction', 'label': localizations.construction},
      {'value': 'special_op', 'label': localizations.specialOperation},
      {'value': 'tithe', 'label': localizations.tithe},
      {'value': 'offering', 'label': localizations.offering},
      {'value': 'gift', 'label': localizations.gift},
      {'value': 'other', 'label': localizations.other},
    ];
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

  // Tag icons mapping
  static const Map<String, IconData> _tagIcons = {
    'construction': Icons.construction,
    'special_op': Icons.stars,
    'tithe': Icons.church,
    'offering': Icons.volunteer_activism,
    'gift': Icons.card_giftcard,
    'other': Icons.category,
  };

  @override
  void initState() {
    super.initState();
    _loadGivingRecord();
  }

  @override
  void dispose() {
    _giverNameController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadGivingRecord() async {
    setState(() => _isLoading = true);
    try {
      final record = await FinanceService.getGivingRecordById(widget.givingId);

      // Check if record can be edited (created within 2 days)
      if (record['created_at'] != null) {
        final createdAt = DateTime.parse(record['created_at']);
        final now = DateTime.now();
        final difference = now.difference(createdAt);
        _canEdit = difference.inDays < 2;
      }

      // Pre-fill form fields
      final amount = (record['amount'] as num?)?.toDouble() ?? 0.0;
      final isExpense = amount < 0;
      final absoluteAmount = amount.abs();

      _giverNameController.text = record['giver_name']?.toString() ?? '';
      _amountController.text = absoluteAmount.toStringAsFixed(2);
      _notesController.text = record['notes']?.toString() ?? '';
      _selectedTag = record['tag']?.toString();
      _isExpense = isExpense;
      _selectedMemberId = record['member_id']?.toString();
      _isExternalGiver = record['member_id'] == null;

      // Load members if needed for editing
      if (_canEdit) {
        await _loadMembers();
      }

      setState(() {
        _givingRecord = record;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.errorLoadingGivingRecord ??
                  'Error loading giving record: $e',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoadingMembers = true);
    try {
      final members = await FinanceService.getActiveMembers();
      setState(() {
        _members = members;
        _isLoadingMembers = false;
      });
    } catch (e) {
      setState(() => _isLoadingMembers = false);
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final localizations = AppLocalizations.of(context)!;

    // Validate giver name
    if (_giverNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations.giverNameRequired),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Validate tag
    if (_selectedTag == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations.pleaseSelectTag),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Validate amount
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations.amountRequired),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations.validAmountRequired),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await FinanceService.updateGivingRecord(
        givingId: widget.givingId,
        giverName: _giverNameController.text.trim(),
        amount: amount,
        tag: _selectedTag!,
        isExpense: _isExpense,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        memberId: _isExternalGiver ? null : _selectedMemberId,
      );

      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.givingRecordUpdated ??
                  'Giving record updated successfully',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        // Navigate back and return true to indicate success
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  String _formatDateTime(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final hour = date.hour > 12
          ? date.hour - 12
          : (date.hour == 0 ? 12 : date.hour);
      final amPm = date.hour >= 12 ? 'PM' : 'AM';
      return '${months[date.month - 1]} ${date.day}, ${date.year} at $hour:${date.minute.toString().padLeft(2, '0')} $amPm';
    } catch (e) {
      return dateString;
    }
  }

  IconData _getTagIcon(String? tag) {
    if (tag == null) return Icons.category;
    return _tagIcons[tag] ?? Icons.category;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(localizations.givingRecord)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_givingRecord == null) {
      return Scaffold(
        appBar: AppBar(title: Text(localizations.givingRecord)),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: AppDimensions.spacingMD),
              Text(
                localizations.givingRecordNotFound,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final record = _givingRecord!;
    final amount = (record['amount'] as num?)?.toDouble() ?? 0.0;
    final isExpense = amount < 0;
    final absoluteAmount = amount.abs();
    final tag = record['tag']?.toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Giving Record'),
        elevation: 0,
        actions: _canEdit
            ? [
                IconButton(
                  icon: const Icon(Icons.save),
                  onPressed: _isSaving ? null : _handleSave,
                  tooltip: 'Save Changes',
                ),
              ]
            : null,
      ),
      body: _canEdit
          ? _buildEditableView(theme, localizations)
          : _buildReadOnlyView(
              theme,
              localizations,
              record,
              isExpense,
              absoluteAmount,
              tag,
            ),
    );
  }

  Widget _buildEditableView(ThemeData theme, AppLocalizations localizations) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.paddingMD),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info banner
            Container(
              margin: const EdgeInsets.only(bottom: AppDimensions.spacingMD),
              padding: const EdgeInsets.all(AppDimensions.paddingMD),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.success.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.edit, color: AppColors.success, size: 24),
                  const SizedBox(width: AppDimensions.spacingMD),
                  Expanded(
                    child: Text(
                      localizations.recordCanBeEdited,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.success,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Transaction Type Toggle
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingMD),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${localizations.transactionType} *',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppDimensions.spacingMD),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.arrow_downward, size: 18),
                                const SizedBox(width: 4),
                                Text(localizations.receiving),
                              ],
                            ),
                            selected: !_isExpense,
                            onSelected: (selected) {
                              setState(() {
                                _isExpense = !selected;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: AppDimensions.spacingMD),
                        Expanded(
                          child: ChoiceChip(
                            label: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.arrow_upward, size: 18),
                                const SizedBox(width: 4),
                                Text(localizations.expense),
                              ],
                            ),
                            selected: _isExpense,
                            onSelected: (selected) {
                              setState(() {
                                _isExpense = selected;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingMD),

            // Giver Type Toggle
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingMD),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizations.giverType,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppDimensions.spacingMD),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: Text(localizations.member),
                            selected: !_isExternalGiver,
                            onSelected: (selected) {
                              setState(() {
                                _isExternalGiver = !selected;
                                if (!_isExternalGiver) {
                                  _giverNameController.clear();
                                } else {
                                  _selectedMemberId = null;
                                }
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: AppDimensions.spacingMD),
                        Expanded(
                          child: ChoiceChip(
                            label: Text(localizations.externalPerson),
                            selected: _isExternalGiver,
                            onSelected: (selected) {
                              setState(() {
                                _isExternalGiver = selected;
                                if (_isExternalGiver) {
                                  _selectedMemberId = null;
                                } else {
                                  _giverNameController.clear();
                                }
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingMD),

            // Member Selection or Giver Name
            if (!_isExternalGiver)
              _isLoadingMembers
                  ? const Card(
                      child: Padding(
                        padding: EdgeInsets.all(AppDimensions.paddingMD),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    )
                  : DropdownButtonFormField<String>(
                      initialValue: _selectedMemberId,
                      decoration: InputDecoration(
                        labelText: '${localizations.selectMember} *',
                        prefixIcon: const Icon(Icons.person),
                        helperText: localizations.selectMember,
                      ),
                      items: _members.map((member) {
                        final fullName =
                            '${member['first_name']} ${member['last_name']}';
                        return DropdownMenuItem<String>(
                          value: member['id'].toString(),
                          child: Text(fullName),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedMemberId = value;
                          if (value != null) {
                            final member = _members.firstWhere(
                              (m) => m['id'].toString() == value,
                            );
                            _giverNameController.text =
                                '${member['first_name']} ${member['last_name']}';
                          }
                        });
                      },
                      validator: (value) {
                        if (!_isExternalGiver &&
                            (value == null || value.isEmpty)) {
                          return localizations.selectMember;
                        }
                        return null;
                      },
                    )
            else
              TextFormField(
                controller: _giverNameController,
                decoration: InputDecoration(
                  labelText: '${localizations.giverName} *',
                  prefixIcon: const Icon(Icons.person_outline),
                  helperText: localizations.externalPerson,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return localizations.giverNameRequired;
                  }
                  return null;
                },
              ),
            const SizedBox(height: AppDimensions.spacingMD),

            // Amount
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: '${localizations.amount} *',
                prefixIcon: const Icon(Icons.attach_money),
                helperText: localizations.amount,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return localizations.amountRequired;
                }
                final amount = double.tryParse(value);
                if (amount == null || amount <= 0) {
                  return localizations.validAmountRequired;
                }
                return null;
              },
            ),
            const SizedBox(height: AppDimensions.spacingMD),

            // Tag Selection
            DropdownButtonFormField<String>(
              initialValue: _selectedTag,
              decoration: InputDecoration(
                labelText: '${localizations.tag} *',
                prefixIcon: const Icon(Icons.label),
                helperText: localizations.category,
              ),
              items: _getTagOptions(localizations).map((tag) {
                return DropdownMenuItem<String>(
                  value: tag['value'],
                  child: Text(tag['label']!),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedTag = value;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return localizations.pleaseSelectTag;
                }
                return null;
              },
            ),
            const SizedBox(height: AppDimensions.spacingMD),

            // Notes
            TextFormField(
              controller: _notesController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: localizations.notes,
                prefixIcon: const Icon(Icons.description),
                helperText: localizations.description,
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingXL),

            // Save Button
            ElevatedButton(
              onPressed: _isSaving ? null : _handleSave,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(
                  double.infinity,
                  AppDimensions.buttonHeightLG,
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(localizations.saveChanges),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadOnlyView(
    ThemeData theme,
    AppLocalizations localizations,
    Map<String, dynamic> record,
    bool isExpense,
    double absoluteAmount,
    String? tag,
  ) {
    return CustomScrollView(
      slivers: [
        // Hero Section with Amount
        SliverToBoxAdapter(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isExpense
                    ? [
                        AppColors.error.withOpacity(0.8),
                        AppColors.error.withOpacity(0.6),
                      ]
                    : [
                        AppColors.success.withOpacity(0.8),
                        AppColors.success.withOpacity(0.6),
                      ],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingXL),
                child: Column(
                  children: [
                    // Transaction Type Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.paddingMD,
                        vertical: AppDimensions.spacingSM,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isExpense
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: AppDimensions.spacingXS),
                          Text(
                            isExpense
                                ? localizations.expense
                                : localizations.receiving,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingXL),
                    // Amount
                    Text(
                      '\$${absoluteAmount.toStringAsFixed(2)}',
                      style: theme.textTheme.displayLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 48,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingMD),
                    // Giver Name
                    Text(
                      record['giver_name']?.toString() ?? 'Unknown',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Main Content
        SliverPadding(
          padding: const EdgeInsets.all(AppDimensions.paddingMD),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Info banner if cannot edit
              Container(
                margin: const EdgeInsets.only(bottom: AppDimensions.spacingMD),
                padding: const EdgeInsets.all(AppDimensions.paddingMD),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppColors.warning,
                      size: 24,
                    ),
                    const SizedBox(width: AppDimensions.spacingMD),
                    Expanded(
                      child: Text(
                        localizations.recordCannotBeEdited,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Transaction Details Card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.paddingMD),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localizations.transactionDetails,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacingMD),
                      const Divider(),
                      const SizedBox(height: AppDimensions.spacingMD),
                      // Tag
                      _buildDetailRow(
                        icon: _getTagIcon(tag),
                        label: localizations.category,
                        value: _getTagLabel(tag, localizations),
                        theme: theme,
                      ),
                      const SizedBox(height: AppDimensions.spacingMD),
                      // Date
                      _buildDetailRow(
                        icon: Icons.calendar_today,
                        label: localizations.date,
                        value: _formatDate(record['date']?.toString()),
                        theme: theme,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.spacingMD),

              // Notes Card (if exists)
              if (record['notes'] != null &&
                  record['notes'].toString().isNotEmpty)
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimensions.paddingMD),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.notes,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: AppDimensions.spacingSM),
                            Text(
                              localizations.notes,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppDimensions.spacingMD),
                        Text(
                          record['notes']?.toString() ?? 'N/A',
                          style: theme.textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                ),
              if (record['notes'] != null &&
                  record['notes'].toString().isNotEmpty)
                const SizedBox(height: AppDimensions.spacingMD),

              // Record Information Card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.paddingMD),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localizations.recordInformation,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacingMD),
                      const Divider(),
                      const SizedBox(height: AppDimensions.spacingMD),
                      // Created At
                      _buildDetailRow(
                        icon: Icons.access_time,
                        label: localizations.created,
                        value: _formatDateTime(
                          record['created_at']?.toString(),
                        ),
                        theme: theme,
                      ),
                      if (record['updated_at'] != null &&
                          record['updated_at'] != record['created_at']) ...[
                        const SizedBox(height: AppDimensions.spacingMD),
                        _buildDetailRow(
                          icon: Icons.update,
                          label: localizations.lastUpdated,
                          value: _formatDateTime(
                            record['updated_at']?.toString(),
                          ),
                          theme: theme,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.spacingXL),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required ThemeData theme,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: AppColors.primary),
        ),
        const SizedBox(width: AppDimensions.spacingMD),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
