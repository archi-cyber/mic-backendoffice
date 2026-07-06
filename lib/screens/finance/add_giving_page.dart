import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/localization/app_localizations.dart';
import '../../services/finance_service.dart';

/// Add giving page for creating new giving/expense records
class AddGivingPage extends StatefulWidget {
  /// When set (e.g. desktop stack), back/close uses this instead of Navigator.pop.
  final void Function([dynamic result])? onClose;

  AddGivingPage({super.key, this.onClose});

  @override
  State<AddGivingPage> createState() => _AddGivingPageState();
}

class _AddGivingPageState extends State<AddGivingPage> {
  final _formKey = GlobalKey<FormState>();
  final _giverNameController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _selectedMemberId;
  String? _selectedTag;
  bool _isExpense = false; // false = receiving, true = expense
  bool _isLoading = false;
  bool _isLoadingMembers = true;
  List<Map<String, dynamic>> _members = [];
  bool _isExternalGiver = false; // true if giver is external (not a member)

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

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  @override
  void dispose() {
    _giverNameController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.errorLoadingMembers ??
                  'Error loading members: $e',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final localizations = AppLocalizations.of(context);

    // Validate giver name
    if (_giverNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localizations?.giverNameRequired ?? 'Giver name is required',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Validate tag
    if (_selectedTag == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localizations?.pleaseSelectTag ?? 'Please select a tag',
          ),
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
          content: Text(localizations?.amountRequired ?? 'Amount is required'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localizations?.validAmountRequired ??
                'Please enter a valid amount greater than zero',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FinanceService.createGivingRecord(
        giverName: _giverNameController.text.trim(),
        amount: amount,
        tag: _selectedTag!,
        isExpense: _isExpense,
        notes: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        memberId: _isExternalGiver ? null : _selectedMemberId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.givingRecordCreated ??
                  'Giving record created successfully',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        if (widget.onClose != null) {
          widget.onClose!(true);
        } else {
          Navigator.of(context).pop(true); // Return true to indicate success
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.addGivingRecord),
        leading: widget.onClose != null
            ? IconButton(
                icon: Icon(Icons.arrow_back),
                onPressed: () => widget.onClose!(),
              )
            : null,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(AppDimensions.paddingMD),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: widget.onClose != null ? 600 : double.infinity,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Transaction Type Toggle
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(AppDimensions.paddingMD),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${localizations.transactionType} *',
                            style: theme.textTheme.titleMedium,
                          ),
                          SizedBox(height: AppDimensions.spacingMD),
                          Row(
                            children: [
                              Expanded(
                                child: ChoiceChip(
                                  label: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.arrow_downward, size: 18),
                                      SizedBox(width: 4),
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
                              SizedBox(width: AppDimensions.spacingMD),
                              Expanded(
                                child: ChoiceChip(
                                  label: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.arrow_upward, size: 18),
                                      SizedBox(width: 4),
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
                  SizedBox(height: AppDimensions.spacingMD),

                  // Giver Type Toggle
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(AppDimensions.paddingMD),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            localizations.giverType,
                            style: theme.textTheme.titleMedium,
                          ),
                          SizedBox(height: AppDimensions.spacingMD),
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
                              SizedBox(width: AppDimensions.spacingMD),
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
                  SizedBox(height: AppDimensions.spacingMD),

                  // Member Selection or Giver Name
                  if (!_isExternalGiver)
                    _isLoadingMembers
                        ? Card(
                            child: Padding(
                              padding: EdgeInsets.all(AppDimensions.paddingMD),
                              child: Center(child: CircularProgressIndicator()),
                            ),
                          )
                        : DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: _selectedMemberId,
                            decoration: InputDecoration(
                              labelText: context.tr(
                                '${localizations.selectMember} *',
                              ),
                              prefixIcon: Icon(Icons.person),
                              helperText: localizations.selectMember,
                            ),
                            items: _members.map((member) {
                              final fullName =
                                  '${member['first_name']} ${member['last_name']}';
                              return DropdownMenuItem<String>(
                                value: member['id'].toString(),
                                child: Text(
                                  fullName,
                                  overflow: TextOverflow.ellipsis,
                                ),
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
                        labelText: context.tr('${localizations.giverName} *'),
                        prefixIcon: Icon(Icons.person_outline),
                        helperText: localizations.externalPerson,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return localizations.giverNameRequired;
                        }
                        return null;
                      },
                    ),
                  SizedBox(height: AppDimensions.spacingMD),

                  // Amount
                  TextFormField(
                    controller: _amountController,
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: context.tr('${localizations.amount} *'),
                      prefixIcon: Icon(Icons.attach_money),
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
                  SizedBox(height: AppDimensions.spacingMD),

                  // Tag Selection
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _selectedTag,
                    decoration: InputDecoration(
                      labelText: context.tr('${localizations.tag} *'),
                      prefixIcon: Icon(Icons.label),
                      helperText: localizations.category,
                    ),
                    items: _getTagOptions(localizations).map((tag) {
                      return DropdownMenuItem<String>(
                        value: tag['value'],
                        child: Text(
                          tag['label']!,
                          overflow: TextOverflow.ellipsis,
                        ),
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
                  SizedBox(height: AppDimensions.spacingMD),

                  // Description
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: localizations.notes,
                      prefixIcon: Icon(Icons.description),
                      helperText: localizations.description,
                      alignLabelWithHint: true,
                    ),
                  ),
                  SizedBox(height: AppDimensions.spacingXL),

                  // Save Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(
                        double.infinity,
                        AppDimensions.buttonHeightLG,
                      ),
                    ),
                    child: _isLoading
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _isExpense
                                ? localizations.createExpense
                                : localizations.createReceivingRecord,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
