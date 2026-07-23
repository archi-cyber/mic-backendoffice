/// Fixed roles for Media Team service schedule columns.
class ServiceScheduleRoles {
  ServiceScheduleRoles._();

  static const projection = 'projection';
  static const callRecording = 'call_recording';
  static const principalCameraman = 'principal_cameraman';
  static const secondaryCameraman = 'secondary_cameraman';
  static const photographer = 'photographer';

  static const maxMembersPerRole = 3;

  static const List<String> all = [
    projection,
    callRecording,
    principalCameraman,
    secondaryCameraman,
    photographer,
  ];

  /// English label keys for [AppLocalizations] / context.tr.
  static const Map<String, String> labelKeys = {
    projection: 'Projection',
    callRecording: 'Call/Recording',
    principalCameraman: 'Principal cameraman',
    secondaryCameraman: 'Secondary cameraman',
    photographer: 'Photographer',
  };

  static String labelKey(String role) =>
      labelKeys[role] ?? role.replaceAll('_', ' ');
}
