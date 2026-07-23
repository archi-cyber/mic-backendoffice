import 'package:flutter/material.dart';
import 'package:intl_phone_field/countries.dart';
import 'package:intl_phone_field/helpers.dart';

import '../core/localization/app_localizations.dart';
import '../core/utils/phone_number_utils.dart';

/// Holds national digits + selected country for [PhoneNumberField].
class PhoneNumberInputController {
  PhoneNumberInputController({String? countryIso})
    : countryIso = countryIso ?? PhoneNumberUtils.defaultCountryIso;

  final TextEditingController nationalController = TextEditingController();
  String countryIso;
  int _revision = 0;

  int get revision => _revision;

  bool get isEmpty => nationalController.text.trim().isEmpty;

  void dispose() => nationalController.dispose();

  void setFromStored(String? phone) {
    final parts = PhoneNumberUtils.parseParts(phone);
    if (parts == null) {
      if (phone == null || phone.trim().isEmpty) {
        nationalController.clear();
      } else {
        nationalController.text = phone.replaceAll(RegExp(r'\D'), '');
      }
      _revision++;
      return;
    }
    countryIso = parts.countryIso;
    nationalController.text = parts.nationalNumber;
    _revision++;
  }

  String? get storedValue {
    if (nationalController.text.trim().isEmpty) return null;
    return PhoneNumberUtils.compose(
      countryIso: countryIso,
      nationalNumber: nationalController.text,
    );
  }
}

/// Phone input with country code picker and validation.
class PhoneNumberField extends StatefulWidget {
  const PhoneNumberField({
    super.key,
    required this.controller,
    required this.decoration,
    this.optional = true,
    this.enabled = true,
    this.onChanged,
  });

  final PhoneNumberInputController controller;
  final InputDecoration decoration;
  final bool optional;
  final bool enabled;
  final void Function(String? e164)? onChanged;

  @override
  State<PhoneNumberField> createState() => _PhoneNumberFieldState();
}

class _PhoneNumberFieldState extends State<PhoneNumberField> {
  final MenuController _menuController = MenuController();
  final List<Country> _countryList = countries;

  Country get _selectedCountry =>
      _countryForIso(widget.controller.countryIso);

  @override
  void initState() {
    super.initState();
    widget.controller.nationalController.addListener(_notifyChanged);
  }

  @override
  void didUpdateWidget(covariant PhoneNumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller.revision != widget.controller.revision) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    widget.controller.nationalController.removeListener(_notifyChanged);
    super.dispose();
  }

  Country _countryForIso(String iso) {
    return _countryList.firstWhere(
      (country) => country.code == iso,
      orElse: () => _countryList.firstWhere(
        (country) => country.code == PhoneNumberUtils.defaultCountryIso,
        orElse: () => _countryList.first,
      ),
    );
  }

  void _notifyChanged() {
    widget.onChanged?.call(widget.controller.storedValue);
  }

  void _selectCountry(Country country) {
    setState(() => widget.controller.countryIso = country.code);
    _menuController.close();
    _notifyChanged();
  }

  String? _validate(String? value) {
    final national = value?.trim() ?? '';
    if (national.isEmpty) {
      return widget.optional ? null : context.tr('Phone number is required');
    }
    final e164 = PhoneNumberUtils.compose(
      countryIso: widget.controller.countryIso,
      nationalNumber: national,
    );
    if (e164 == null) {
      return context.tr('Invalid phone number');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final languageCode = Localizations.localeOf(context).languageCode;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: MenuAnchor(
            controller: _menuController,
            alignmentOffset: const Offset(0, 6),
            style: MenuStyle(
              padding: WidgetStateProperty.all(EdgeInsets.zero),
              elevation: WidgetStateProperty.all(6),
              shape: WidgetStateProperty.all(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              fixedSize: WidgetStateProperty.all(const Size(280, 268)),
            ),
            menuChildren: [
              _CountryCodeDropdown(
                countries: _countryList,
                languageCode: languageCode,
                selectedCountry: _selectedCountry,
                searchLabel: context.tr('Search country'),
                onSelected: _selectCountry,
              ),
            ],
            builder: (context, controller, child) {
              return OutlinedButton(
                onPressed: widget.enabled
                    ? () {
                        if (controller.isOpen) {
                          controller.close();
                        } else {
                          controller.open();
                        }
                      }
                    : null,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 14,
                  ),
                  minimumSize: const Size(0, 48),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  side: BorderSide(color: theme.colorScheme.outline),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _selectedCountry.flag,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '+${_selectedCountry.dialCode}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down, size: 20),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            controller: widget.controller.nationalController,
            enabled: widget.enabled,
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumberNational],
            decoration: widget.decoration,
            validator: _validate,
            onChanged: (_) => _notifyChanged(),
          ),
        ),
      ],
    );
  }
}

class _CountryCodeDropdown extends StatefulWidget {
  const _CountryCodeDropdown({
    required this.countries,
    required this.languageCode,
    required this.selectedCountry,
    required this.searchLabel,
    required this.onSelected,
  });

  final List<Country> countries;
  final String languageCode;
  final Country selectedCountry;
  final String searchLabel;
  final ValueChanged<Country> onSelected;

  @override
  State<_CountryCodeDropdown> createState() => _CountryCodeDropdownState();
}

class _CountryCodeDropdownState extends State<_CountryCodeDropdown> {
  final _searchController = TextEditingController();
  List<Country> _filteredCountries = countries;

  @override
  void initState() {
    super.initState();
    _filteredCountries = _sortedCountries(widget.countries);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Country> _sortedCountries(List<Country> source) {
    final copy = List<Country>.from(source);
    copy.sort(
      (a, b) => a
          .localizedName(widget.languageCode)
          .compareTo(b.localizedName(widget.languageCode)),
    );
    return copy;
  }

  void _filter(String query) {
    setState(() {
      _filteredCountries = _sortedCountries(
        query.trim().isEmpty
            ? widget.countries
            : widget.countries.stringSearch(query),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 280,
      height: 268,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: TextField(
              controller: _searchController,
              style: theme.textTheme.bodySmall,
              decoration: InputDecoration(
                isDense: true,
                hintText: widget.searchLabel,
                prefixIcon: const Icon(Icons.search, size: 18),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: _filter,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: _filteredCountries.length,
              itemBuilder: (context, index) {
                  final country = _filteredCountries[index];
                  final selected =
                      country.code == widget.selectedCountry.code;
                  return InkWell(
                    onTap: () => widget.onSelected(country),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Text(
                            country.flag,
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 44,
                            child: Text(
                              '+${country.dialCode}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: selected
                                    ? theme.colorScheme.primary
                                    : null,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              country.localizedName(widget.languageCode),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: selected
                                    ? theme.colorScheme.primary
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
            ),
          ),
        ],
      ),
    );
  }
}
