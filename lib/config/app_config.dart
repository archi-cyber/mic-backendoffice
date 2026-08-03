class AppConfig {
  // Supabase Configuration
  static const String supabaseUrl = 'https://wusgqajwogsmdtsytelt.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind1c2dxYWp3b2dzbWR0c3l0ZWx0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODUxNzkyODksImV4cCI6MjEwMDc1NTI4OX0.oBCkwu16XGwBalmyo1F4h7PHqGCwBOrbKO0kC8lEYm0';

  // App Configuration
  static const String appName = 'SysteMIC';
  static const String appVersion = '1.0.0';

  /// Default ISO country for phone numbers without a country code (e.g. CM, FR).
  static const String defaultPhoneCountryIso = 'CM';

  // Push Notifications
  // Push notifications are sent via Supabase Edge Functions
  // See: supabase/functions/send-push-notification/README.md for setup instructions
}
