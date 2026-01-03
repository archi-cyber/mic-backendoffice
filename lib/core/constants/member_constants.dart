/// Constants for member-related enums and values
class MemberConstants {
  // Profession types
  static const String primarySchoolStudent = 'primary_school_student';
  static const String secondarySchoolStudent = 'secondary_school_student';
  static const String universityStudent = 'university_student';
  static const String jobSeeking = 'job_seeking';
  static const String worker = 'worker';

  /// Get profession display label
  static String getProfessionLabel(String? profession) {
    switch (profession) {
      case primarySchoolStudent:
        return 'Primary School Student';
      case secondarySchoolStudent:
        return 'Secondary School Student';
      case universityStudent:
        return 'University Student';
      case jobSeeking:
        return 'Job Seeking';
      case worker:
        return 'Worker';
      default:
        return 'Not specified';
    }
  }

  /// Check if profession requires level_of_study
  static bool requiresLevelOfStudy(String? profession) {
    return profession == primarySchoolStudent ||
        profession == secondarySchoolStudent ||
        profession == universityStudent ||
        profession == jobSeeking ||
        profession == worker;
  }

  /// Check if profession requires last_diplomas
  static bool requiresLastDiplomas(String? profession) {
    return profession == secondarySchoolStudent ||
        profession == universityStudent ||
        profession == jobSeeking ||
        profession == worker;
  }

  /// Check if profession requires sector_of_studies
  static bool requiresSectorOfStudies(String? profession) {
    return profession == secondarySchoolStudent ||
        profession == universityStudent ||
        profession == jobSeeking ||
        profession == worker;
  }

  /// Check if profession requires domain_of_activity
  static bool requiresDomainOfActivity(String? profession) {
    return profession == jobSeeking || profession == worker;
  }

  /// Get all profession options
  static List<Map<String, String>> getProfessionOptions() {
    return [
      {'value': primarySchoolStudent, 'label': 'Primary School Student'},
      {'value': secondarySchoolStudent, 'label': 'Secondary School Student'},
      {'value': universityStudent, 'label': 'University Student'},
      {'value': jobSeeking, 'label': 'Job Seeking'},
      {'value': worker, 'label': 'Worker'},
    ];
  }

  /// Get levels of study based on profession
  static List<String> getLevelsOfStudy(String? profession) {
    if (profession == null) return [];

    switch (profession) {
      case primarySchoolStudent:
        return [
          'nursery',
          'primary 1',
          'primary 2',
          'primary 3',
          'primary 4',
          'primary 5',
          'primary 6',
        ];
      case secondarySchoolStudent:
        return [
          'form 1',
          'form 2',
          'form 3',
          'form 4',
          'form 5',
          'lower sixth',
          'upper sixth',
        ];
      case universityStudent:
      case jobSeeking:
      case worker:
        return [
          'level 1',
          'level 2',
          'level 3',
          'masters 1',
          'masters 2',
          'phd',
        ];
      default:
        return [];
    }
  }

  /// Get all diploma options
  static List<String> getDiplomaOptions() {
    return [
      'CEP',
      'GCE A levels',
      'GCE O levels',
      'BAC',
      'Probatoire',
      'BEPC',
      'Licence (Bachelors)',
      'Masters 1',
      'Masters 2',
      'PHD',
    ];
  }
}
