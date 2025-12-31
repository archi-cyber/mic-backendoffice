/// Utility functions for member-related operations
class MemberUtils {
  /// Calculate age category based on birthday
  /// Returns: 'child' (0-12), 'teenager' (13-17), or 'adult' (18+)
  static String getAgeCategory(DateTime? birthday) {
    if (birthday == null) return 'adult';

    final now = DateTime.now();
    int age = now.year - birthday.year;

    // Adjust age if birthday hasn't occurred this year
    if (now.month < birthday.month ||
        (now.month == birthday.month && now.day < birthday.day)) {
      age--;
    }

    if (age < 13) {
      return 'child';
    } else if (age < 18) {
      return 'teenager';
    } else {
      return 'adult';
    }
  }

  /// Get age category label for display
  static String getAgeCategoryLabel(DateTime? birthday) {
    final category = getAgeCategory(birthday);
    switch (category) {
      case 'child':
        return 'Child';
      case 'teenager':
        return 'Teenager';
      case 'adult':
        return 'Adult';
      default:
        return 'Adult';
    }
  }

  /// Calculate age in years
  static int? getAge(DateTime? birthday) {
    if (birthday == null) return null;

    final now = DateTime.now();
    int age = now.year - birthday.year;

    // Adjust age if birthday hasn't occurred this year
    if (now.month < birthday.month ||
        (now.month == birthday.month && now.day < birthday.day)) {
      age--;
    }

    return age;
  }
}
