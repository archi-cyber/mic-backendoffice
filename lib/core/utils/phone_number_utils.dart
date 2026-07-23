import 'package:phone_numbers_parser/phone_numbers_parser.dart';

import '../../config/app_config.dart';

/// Parses, validates, and normalizes phone numbers to E.164.
class PhoneNumberUtils {
  PhoneNumberUtils._();

  static IsoCode get defaultIso => _isoFromAlpha2(defaultCountryIso);

  static String get defaultCountryIso {
    final configured = AppConfig.defaultPhoneCountryIso.trim();
    if (configured.length == 2) {
      return configured.toUpperCase();
    }
    return 'CM';
  }

  static IsoCode _isoFromAlpha2(String alpha2) {
    final normalized = alpha2.trim().toUpperCase();
    for (final iso in IsoCode.values) {
      if (iso.name == normalized) return iso;
    }
    return IsoCode.CM;
  }

  static String alpha2FromIso(IsoCode iso) => iso.name;

  /// Parses a stored or user-entered phone number.
  static PhoneNumber? tryParse(
    String? raw, {
    IsoCode? destinationCountry,
  }) {
    if (raw == null) return null;
    final input = raw.trim();
    if (input.isEmpty) return null;

    final country = destinationCountry ?? defaultIso;

    try {
      if (input.startsWith('+')) {
        return PhoneNumber.parse(input);
      }
      final digits = input.replaceAll(RegExp(r'\D'), '');
      if (digits.isEmpty) return null;
      return PhoneNumber.parse(digits, destinationCountry: country);
    } catch (_) {
      return null;
    }
  }

  static bool isValid(String? raw, {IsoCode? destinationCountry}) {
    final parsed = tryParse(raw, destinationCountry: destinationCountry);
    return parsed != null && parsed.isValid();
  }

  /// Returns compact E.164 (e.g. +237612345678) or null when empty/invalid.
  static String? normalize(String? raw, {IsoCode? destinationCountry}) {
    final parsed = tryParse(raw, destinationCountry: destinationCountry);
    if (parsed == null) return null;
    if (!parsed.isValid()) return null;
    return parsed.international;
  }

  /// Normalizes when possible; returns null only for empty input.
  static String? normalizeOrNull(String? raw, {IsoCode? destinationCountry}) {
    if (raw == null || raw.trim().isEmpty) return null;
    return normalize(raw, destinationCountry: destinationCountry);
  }

  static String normalizeLoginIdentifier(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty || trimmed.contains('@')) return trimmed;
    return normalize(trimmed) ?? trimmed;
  }

  static ({String countryIso, String nationalNumber, String e164})? parseParts(
    String? raw, {
    IsoCode? destinationCountry,
  }) {
    final parsed = tryParse(raw, destinationCountry: destinationCountry);
    if (parsed == null) return null;
    return (
      countryIso: alpha2FromIso(parsed.isoCode),
      nationalNumber: parsed.nsn,
      e164: parsed.international,
    );
  }

  static String? compose({
    required String countryIso,
    required String nationalNumber,
  }) {
    final national = nationalNumber.replaceAll(RegExp(r'\D'), '');
    if (national.isEmpty) return null;
    final iso = _isoFromAlpha2(countryIso);
    final parsed = PhoneNumber(isoCode: iso, nsn: national);
    if (!parsed.isValid()) return null;
    return parsed.international;
  }

  static String digitsOnly(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    final normalized = normalize(raw);
    if (normalized != null) {
      return normalized.replaceAll(RegExp(r'\D'), '');
    }
    return raw.replaceAll(RegExp(r'\D'), '');
  }
}
