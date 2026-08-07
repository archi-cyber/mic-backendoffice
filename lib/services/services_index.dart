/// Point d'entrée unique des services.
///
/// ```dart
/// import 'package:mic_backoffice/services/services_index.dart';
/// ```
///
/// Cette version reflète la migration vers l'API NestJS. Le découpage
/// d'origine est **conservé** : chaque service garde son nom et ses
/// signatures, seul l'intérieur change. Les écrans n'ont rien à modifier.
library;

// =============================================================================
// MIGRÉS — API NestJS
// =============================================================================

export 'auth_service.dart';

// Couche de compatibilite, transitoire — voir supabase_service.dart.
export 'supabase_service.dart';
export 'admin_service.dart';
export 'member_service.dart';
export 'department_service.dart';
export 'church_service_service.dart';
export 'church_attendance_service.dart';
export 'sunday_school_attendance_service.dart';
export 'visitor_service.dart';
export 'task_service.dart';
export 'project_service.dart';
export 'tag_service.dart';
export 'task_penalty_service.dart';
export 'teaching_service.dart';
export 'class_service.dart';
export 'event_service.dart';
export 'finance_service.dart';
export 'report_service.dart';
export 'department_report_service.dart';
export 'trainings_report_service.dart';
export 'chat_service.dart';
export 'notification_service.dart';
export 'leader_access_service.dart';
export 'role_service.dart';

// Ajouts de la migration : regroupements pratiques pour les nouveaux écrans.
// Les services historiques ci-dessus restent la voie normale.
export 'communication_service.dart';
export 'user_service.dart';

// =============================================================================
// À MIGRER — décommenter au fur et à mesure
// =============================================================================
//
// Ces services appellent encore Supabase et ne compilent plus. Ils suivront le
// même patron : remplacer `_client.from(...)` par un appel HTTP.

// export 'settings_service.dart';
export 'service_schedule_service.dart';
export 'member_account_service.dart';
export 'new_comer_service.dart';
export 'birthday_notification_service.dart';
export 'birthday_scheduler_service.dart';
// export 'user_management_service.dart';
// export 'user_member_sync_service.dart';
// export 'data_export_service.dart';
// export 'data_import_service.dart';

// =============================================================================
// FIREBASE ET STOCKAGE LOCAL
// =============================================================================
//
// Indépendants de l'API. `device_token_service` doit toutefois être adapté :
// il enregistrait le jeton d'appareil dans Supabase, il devra le poster sur
// `/users/me/devices`.

// export 'device_token_service.dart';
// export 'fcm_service.dart';
// export 'push_notification_handler.dart';
// export 'push_notification_service.dart';
// export 'background_task_service.dart';
export 'storage_service.dart';

// =============================================================================
// HORS LIGNE — chantier distinct
// =============================================================================
//
// Le mode hors ligne n'est pas repris en l'état : il demande une file
// d'opérations, une résolution de conflits et des identifiants temporaires.

// export 'offline_queue_service.dart';
// export 'offline_storage_service.dart';