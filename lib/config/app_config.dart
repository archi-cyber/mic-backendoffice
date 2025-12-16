class AppConfig {
  // Supabase Configuration
  // TODO: Replace with your Supabase project credentials
  static const String supabaseUrl = 'https://lihdbwqaacezrzfzjmhu.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxpaGRid3FhYWNlenJ6ZnpqbWh1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQyOTkwNDQsImV4cCI6MjA3OTg3NTA0NH0.4VZAsGTuLpypmVLwHji6bOhxWnG71khaa360vaw1voE';

  // App Configuration
  static const String appName = 'SysteMIC';
  static const String appVersion = '1.0.0';

  // Push Notifications
  // Push notifications are sent via Supabase Edge Functions
  // See: supabase/functions/send-push-notification/README.md for setup instructions
}
