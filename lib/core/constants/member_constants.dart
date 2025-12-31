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
}
