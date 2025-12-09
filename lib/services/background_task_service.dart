import 'package:workmanager/workmanager.dart';
import 'birthday_scheduler_service.dart';
import 'supabase_service.dart';

/// Background task service for scheduled jobs
/// Note: For production, the birthday scheduler should run server-side
class BackgroundTaskService {
  static const String birthdayTaskName = 'birthdayScheduler';

  /// Initialize background tasks
  static Future<void> initialize() async {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  }

  /// Register daily birthday scheduler task
  /// Note: This is a client-side implementation
  /// For production, use server-side cron job or Supabase Edge Functions
  static Future<void> registerBirthdayScheduler({
    Duration? initialDelay,
  }) async {
    // Register periodic task (runs approximately every 24 hours)
    // Note: Exact timing depends on OS scheduling
    await Workmanager().registerPeriodicTask(
      birthdayTaskName,
      birthdayTaskName,
      frequency: const Duration(hours: 24),
      initialDelay: initialDelay ?? const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }

  /// Cancel birthday scheduler task
  static Future<void> cancelBirthdayScheduler() async {
    await Workmanager().cancelByUniqueName(birthdayTaskName);
  }
}

/// Callback dispatcher for background tasks
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      switch (task) {
        case BackgroundTaskService.birthdayTaskName:
          // Initialize Supabase in background
          // Note: You may need to pass credentials or use environment variables
          await SupabaseService.initialize();

          // Process birthday notifications
          await BirthdaySchedulerService.processBirthdayNotifications();
          return true;

        default:
          return false;
      }
    } catch (e) {
      // Log error but don't crash
      return false;
    }
  });
}
