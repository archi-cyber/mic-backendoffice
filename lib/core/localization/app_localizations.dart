import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/settings_service.dart';

/// App localization delegate
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  /// Prefer the language saved in Settings over the device/browser locale.
  static AppLocalizations resolvedOf(BuildContext context) {
    Locale? settingsLocale;
    try {
      settingsLocale = Provider.of<SettingsProvider>(
        context,
        listen: false,
      ).locale;
    } catch (_) {
      settingsLocale = null;
    }

    final inherited = AppLocalizations.of(context);
    final locale = SettingsService.resolveLocale(
      settingsLocale ?? inherited?.locale,
    );
    if (inherited != null && inherited.locale.languageCode == locale.languageCode) {
      return inherited;
    }
    return AppLocalizations(locale);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('en'), // English
    Locale('fr'), // French
    Locale('es'), // Spanish
  ];

  String translate(String fallback, [Map<String, Object?> params = const {}]) {
    final value =
        _literalValues[locale.languageCode]?[fallback] ??
        _localizedByEnglishValue(fallback) ??
        _fallbackPhraseTranslation(fallback);
    return _interpolate(value, params);
  }

  String t(String fallback, [Map<String, Object?> params = const {}]) =>
      translate(fallback, params);

  String byKey(
    String key,
    String fallback, [
    Map<String, Object?> params = const {},
  ]) {
    return _interpolate(_g(key, fallback), params);
  }

  String statusLabel(String? status) {
    switch (status) {
      case 'in_progress':
        return translate('In progress');
      case 'completed':
        return translate('Completed');
      case 'cancelled':
        return translate('Cancelled');
      case 'pending':
      default:
        return translate('Pending');
    }
  }

  String priorityLabel(String? priority) {
    switch (priority) {
      case 'urgent':
        return translate('Urgent');
      case 'high':
        return translate('High');
      case 'low':
        return translate('Low');
      case 'medium':
      default:
        return translate('Medium');
    }
  }

  String? _localizedByEnglishValue(String fallback) {
    final englishEntries = _localizedValues['en']?.entries;
    if (englishEntries == null) return null;
    for (final entry in englishEntries) {
      if (entry.value == fallback) {
        return _localizedValues[locale.languageCode]?[entry.key];
      }
    }
    return null;
  }

  /// Keyed getter helper: keyed map → literal map → phrase fallback.
  String _g(String key, String english) {
    if (locale.languageCode == 'en') return english;
    return _localizedValues[locale.languageCode]?[key] ??
        _literalValues[locale.languageCode]?[english] ??
        _fallbackPhraseTranslation(english);
  }

  String _fallbackPhraseTranslation(String fallback) {
    final replacements = _fallbackPhraseReplacements[locale.languageCode];
    if (replacements == null) return fallback;
    var result = fallback;
    for (final entry in replacements.entries) {
      result = result.replaceAllMapped(
        RegExp('\\b${RegExp.escape(entry.key)}\\b'),
        (_) => entry.value,
      );
    }
    return result;
  }

  String _interpolate(String value, Map<String, Object?> params) {
    var result = value;
    for (final entry in params.entries) {
      result = result.replaceAll('{${entry.key}}', entry.value.toString());
    }
    return result;
  }

  // Common
  String get appName =>
      _g('appName', 'SysteMIC');
  String get welcome =>
      _g('welcome', 'Welcome');
  String get loading =>
      _g('loading', 'Loading...');
  String get error =>
      _g('error', 'Error');
  String get success =>
      _g('success', 'Success');
  String get cancel =>
      _g('cancel', 'Cancel');
  String get confirm =>
      _g('confirm', 'Confirm');
  String get save => _g('save', 'Save');
  String get delete =>
      _g('delete', 'Delete');
  String get edit => _g('edit', 'Edit');
  String get search =>
      _g('search', 'Search');
  String get filter =>
      _g('filter', 'Filter');
  String get close =>
      _g('close', 'Close');

  // Authentication
  String get login =>
      _g('login', 'Login');
  String get logout =>
      _g('logout', 'Logout');
  String get email =>
      _g('email', 'Email');
  String get password =>
      _g('password', 'Password');
  String get forgotPassword =>
      _g('forgotPassword', 'Forgot Password?');
  String get signIn =>
      _g('signIn', 'Sign In');
  String get signOut =>
      _g('signOut', 'Sign Out');
  String get emailRequired =>
      _g('emailRequired', 'Email is required');
  String get passwordRequired =>
      _g('passwordRequired', 'Password is required');
  String get invalidEmail =>
      _g('invalidEmail', 'Invalid email format');
  String get loginError =>
      _g('loginError', 'Login failed. Please try again.');

  // Dashboard
  String get dashboard =>
      _g('dashboard', 'Dashboard');
  String get home => _g('home', 'Home');
  String get overview =>
      _g('overview', 'Overview');
  String get statistics =>
      _g('statistics', 'Statistics');

  // Navigation
  String get members =>
      _g('members', 'Members');
  String get attendance =>
      _g('attendance', 'Attendance');
  String get giving =>
      _g('giving', 'Giving');
  String get events =>
      _g('events', 'Events');
  String get settings =>
      _g('settings', 'Settings');
  String get notifications =>
      _g('notifications', 'Notifications');
  String get profile =>
      _g('profile', 'Profile');

  // Messages
  String get noData =>
      _g('noData', 'No data available');
  String get networkError =>
      _g('networkError', 'Network error. Please check your connection.');
  String get genericError =>
      _g('genericError', 'An error occurred. Please try again.');

  // Finance
  String get finance =>
      _g('finance', 'Finance');
  String get addGivingRecord =>
      _g('addGivingRecord', 'Add Giving Record');
  String get givingRecord =>
      _g('givingRecord', 'Giving Record');
  String get givingRecordDetails =>
      _g('givingRecordDetails', 'Giving Record Details');
  String get transactionType =>
      _g('transactionType', 'Transaction Type');
  String get receiving =>
      _g('receiving', 'Receiving');
  String get expense =>
      _g('expense', 'Expense');
  String get giverType =>
      _g('giverType', 'Giver Type');
  String get member =>
      _g('member', 'Member');
  String get externalPerson =>
      _g('externalPerson', 'External Person');
  String get giverName =>
      _g('giverName', 'Giver Name');
  String get selectMember =>
      _g('selectMember', 'Select Member');
  String get amount =>
      _g('amount', 'Amount');
  String get tag => _g('tag', 'Tag');
  String get notes =>
      _g('notes', 'Notes');
  String get description =>
      _g('description', 'Description');
  String get date => _g('date', 'Date');
  String get category =>
      _g('category', 'Category');
  String get created =>
      _g('created', 'Created');
  String get lastUpdated =>
      _g('lastUpdated', 'Last Updated');
  String get recordInformation =>
      _g('recordInformation', 'Record Information');
  String get transactionDetails =>
      _g('transactionDetails', 'Transaction Details');
  String get noGivingRecords =>
      _g('noGivingRecords', 'No giving records yet');
  String get addFirstRecord =>
      _g('addFirstRecord', 'Add First Record');
  String get givingRecordCreated =>
      _g('givingRecordCreated', 'Giving record created successfully');
  String get givingRecordUpdated =>
      _g('givingRecordUpdated', 'Giving record updated successfully');
  String get givingRecordNotFound =>
      _g('givingRecordNotFound', 'Giving record not found');
  String get errorLoadingGivingRecord =>
      _g('errorLoadingGivingRecord', 'Error loading giving record');
  String get giverNameRequired =>
      _g('giverNameRequired', 'Giver name is required');
  String get pleaseSelectTag =>
      _g('pleaseSelectTag', 'Please select a tag');
  String get amountRequired =>
      _g('amountRequired', 'Amount is required');
  String get validAmountRequired =>
      _g('validAmountRequired', 'Please enter a valid amount greater than zero');
  String get createExpense =>
      _g('createExpense', 'Create Expense');
  String get createReceivingRecord =>
      _g('createReceivingRecord', 'Create Receiving Record');
  String get saveChanges =>
      _g('saveChanges', 'Save Changes');
  String get recordCanBeEdited =>
      _g('recordCanBeEdited', 'This record can be edited. Changes will be saved immediately.');
  String get recordCannotBeEdited =>
      _g('recordCannotBeEdited', 'This record was created more than 2 days ago and cannot be edited.');
  String get errorLoadingMembers =>
      _g('errorLoadingMembers', 'Error loading members');
  String get errorLoadingGivingRecords =>
      _g('errorLoadingGivingRecords', 'Error loading giving records');

  // Tag labels
  String get construction =>
      _g('construction', 'Construction');
  String get specialOperation =>
      _g('specialOperation', 'Special Operation');
  String get tithe =>
      _g('tithe', 'Tithe');
  String get offering =>
      _g('offering', 'Offering');
  String get gift => _g('gift', 'Gift');
  String get other =>
      _g('other', 'Other');

  // Dashboard
  String get upcomingSessions =>
      _g('upcomingSessions', 'Upcoming Sessions');
  String get upcomingEvents =>
      _g('upcomingEvents', 'Upcoming Events');
  String get tasks =>
      _g('tasks', 'Tasks');
  String get birthdays =>
      _g('birthdays', 'Birthdays');
  String get quickActions =>
      _g('quickActions', 'Quick Actions');
  String get departments =>
      _g('departments', 'Departments');
  String get classes =>
      _g('classes', 'Trainings');
  String get reports =>
      _g('reports', 'Reports');
  String get chat => _g('chat', 'Chat');
  String get errorLoadingDashboard =>
      _g('errorLoadingDashboard', 'Error loading dashboard');

  // Error Messages - Short and descriptive
  String get errorLoginFailed =>
      _g('errorLoginFailed', 'Login failed. Check your credentials.');
  String get errorEmailNotConfirmed =>
      _g('errorEmailNotConfirmed', 'Please confirm your email to continue.');
  String get errorUserNotFound =>
      _g('errorUserNotFound', 'User not found.');
  String get errorAccountCreationFailed =>
      _g('errorAccountCreationFailed', 'Failed to create account.');
  String get errorDuplicateEmail =>
      _g('errorDuplicateEmail', 'Email already in use.');
  String get errorPermissionDenied =>
      _g('errorPermissionDenied', 'You don\'t have permission for this action.');
  String get errorOperationFailed =>
      _g('errorOperationFailed', 'Operation failed. Please try again.');
  String get errorInvalidCredentials =>
      _g('errorInvalidCredentials', 'Invalid email or password.');
  String get errorPasswordResetFailed =>
      _g('errorPasswordResetFailed', 'Password reset failed.');
  String get errorMustBeLoggedIn =>
      _g('errorMustBeLoggedIn', 'Please log in to continue.');
  String get errorAdminOrLeaderRequired =>
      _g('errorAdminOrLeaderRequired', 'Only admins or leaders can perform this action.');
  String get errorMemberNotFound =>
      _g('errorMemberNotFound', 'Member not found.');
  String get errorEmailOrPhoneRequired =>
      _g('errorEmailOrPhoneRequired', 'Email or phone is required.');
  String get errorDepartmentNotFound =>
      _g('errorDepartmentNotFound', 'Department not found.');
  String get errorFailedToLoad =>
      _g('errorFailedToLoad', 'Failed to load data.');
  String get errorFailedToSave =>
      _g('errorFailedToSave', 'Failed to save. Please try again.');
  String get errorFailedToDelete =>
      _g('errorFailedToDelete', 'Failed to delete.');
  String get errorFileUploadFailed =>
      _g('errorFileUploadFailed', 'File upload failed.');
  String get errorInvalidInput =>
      _g('errorInvalidInput', 'Invalid input. Please check your data.');

  // Departments
  String get addDepartment =>
      _g('addDepartment', 'Add Department');
  String get editDepartment =>
      _g('editDepartment', 'Edit Department');
  String get departmentName =>
      _g('departmentName', 'Department Name');
  String get departmentNameRequired =>
      _g('departmentNameRequired', 'Department name is required');
  String get departmentDescription =>
      _g('departmentDescription', 'Description');
  String get departmentCreated =>
      _g('departmentCreated', 'Department created successfully');
  String get departmentUpdated =>
      _g('departmentUpdated', 'Department updated successfully');
  String get departmentDeleted =>
      _g('departmentDeleted', 'Department deleted successfully');
  String get errorCreatingDepartment =>
      _g('errorCreatingDepartment', 'Failed to create department');
  String get errorUpdatingDepartment =>
      _g('errorUpdatingDepartment', 'Failed to update department');
  String get errorDeletingDepartment =>
      _g('errorDeletingDepartment', 'Failed to delete department');
  String get errorLoadingDepartments =>
      _g('errorLoadingDepartments', 'Failed to load departments');
  String get noDepartments =>
      _g('noDepartments', 'No departments yet');
  String get noDepartmentsFound =>
      _g('noDepartmentsFound', 'No departments found');
  String get searchDepartments =>
      _g('searchDepartments', 'Search departments...');
  String get departmentFiles =>
      _g('departmentFiles', 'Department Files');
  String get noFilesUploaded =>
      _g('noFilesUploaded', 'No files uploaded');
  String get documents =>
      _g('documents', 'Documents');
  String get documentsOptional =>
      _g('documentsOptional', 'Documents (Optional)');
  String get document =>
      _g('document', 'Document');
  String get upload =>
      _g('upload', 'Upload');
  String get remove =>
      _g('remove', 'Remove');
  String get view => _g('view', 'View');
  String get newFile =>
      _g('newFile', 'New file');
  String get deleteDepartment =>
      _g('deleteDepartment', 'Delete Department');
  String get deleteDepartmentConfirm =>
      _g('deleteDepartmentConfirm', 'Are you sure you want to delete this department? This will deactivate it.');
  String get createDepartment =>
      _g('createDepartment', 'Create Department');
  String get updateDepartment =>
      _g('updateDepartment', 'Update Department');

  // Department Members
  String get addMember =>
      _g('addMember', 'Add Member');
  String get removeMember =>
      _g('removeMember', 'Remove Member');
  String get changeRole =>
      _g('changeRole', 'Change Role');
  String get role => _g('role', 'Role');
  String get leader =>
      _g('leader', 'Leader');
  String get subleader =>
      _g('subleader', 'Subleader');
  String get memberRole =>
      _g('memberRole', 'Member');
  String get selectRole =>
      _g('selectRole', 'Select Role');
  String get memberAdded =>
      _g('memberAdded', 'Member added successfully');
  String get memberRemoved =>
      _g('memberRemoved', 'Member removed successfully');
  String get deleteMember =>
      _g('deleteMember', 'Delete Member');
  String get deleteMemberConfirmation =>
      _g('deleteMemberConfirmation', 'Are you sure you want to delete {name}? This action cannot be undone.');
  String get memberDeletedSuccessfully =>
      _g('memberDeletedSuccessfully', 'Member deleted successfully');
  String get roleUpdated =>
      _g('roleUpdated', 'Role updated successfully');
  String get errorAddingMember =>
      _g('errorAddingMember', 'Failed to add member');
  String get errorRemovingMember =>
      _g('errorRemovingMember', 'Failed to remove member');
  String get errorUpdatingRole =>
      _g('errorUpdatingRole', 'Failed to update role');
  String get noMembersInDepartment =>
      _g('noMembersInDepartment', 'No members in this department');
  String get allMembersInDepartment =>
      _g('allMembersInDepartment', 'All members are already in this department');
  String get removeMemberConfirm =>
      _g('removeMemberConfirm', 'Are you sure you want to remove {name} from this department?');
  String removeMemberConfirmWithName(String name) =>
      removeMemberConfirm.replaceAll('{name}', name);

  // Password Change
  String get changePassword =>
      _g('changePassword', 'Change Password');
  String get changePasswordRequired =>
      _g('changePasswordRequired', 'Change Password Required');
  String get changePasswordMessage =>
      _g('changePasswordMessage', 'You must change your password before continuing.');
  String get newPassword =>
      _g('newPassword', 'New Password');
  String get confirmPassword =>
      _g('confirmPassword', 'Confirm New Password');
  String get newPasswordRequired =>
      _g('newPasswordRequired', 'New password is required');
  String get passwordMinLength =>
      _g('passwordMinLength', 'Password must be at least 6 characters');
  String get passwordsDoNotMatch =>
      _g('passwordsDoNotMatch', 'Passwords do not match');
  String get passwordChanged =>
      _g('passwordChanged', 'Password changed successfully');
  String get errorChangingPassword =>
      _g('errorChangingPassword', 'Failed to change password');

  // Tasks
  String get manageTasks =>
      _g('manageTasks', 'Manage Tasks');
  String get generateReport =>
      _g('generateReport', 'Generate Report');
  String get taskCompletion =>
      _g('taskCompletion', 'Task Completion');
  String get total =>
      _g('total', 'Total');
  String get completed =>
      _g('completed', 'Completed');
  String get pending =>
      _g('pending', 'Pending');
  String get inProgress =>
      _g('inProgress', 'In Progress');
  String get noTasks =>
      _g('noTasks', 'No tasks in this department');

  // Reports
  String get createReport =>
      _g('createReport', 'Create Report');
  String get generateSummaryReport =>
      _g('generateSummaryReport', 'Generate Summary Report');
  String get noReports =>
      _g('noReports', 'No reports yet');
  String get createFirstReport =>
      _g('createFirstReport', 'Create your first report to get started');
  String get generatePdf =>
      _g('generatePdf', 'Generate PDF');
  String get editReport =>
      _g('editReport', 'Edit');
  String get deleteReport =>
      _g('deleteReport', 'Delete');
  String get deleteReportConfirm =>
      _g('deleteReportConfirm', 'Are you sure you want to delete "{title}"?');
  String deleteReportConfirmWithTitle(String title) =>
      deleteReportConfirm.replaceAll('{title}', title);
  String get reportDeleted =>
      _g('reportDeleted', 'Report deleted successfully');
  String get errorDeletingReport =>
      _g('errorDeletingReport', 'Failed to delete report');
  String get reportGenerated =>
      _g('reportGenerated', 'Report generated successfully');
  String get errorGeneratingReport =>
      _g('errorGeneratingReport', 'Failed to generate report');
  String get generatingPdf =>
      _g('generatingPdf', 'Generating PDF...');
  String get generatingReport =>
      _g('generatingReport', 'Generating report...');
  String get pdfGenerated =>
      _g('pdfGenerated', 'PDF generated successfully');

  // Refresh
  String get refresh =>
      _g('refresh', 'Refresh');

  // Active/Inactive
  String get active =>
      _g('active', 'Active');
  String get inactive =>
      _g('inactive', 'Inactive');

  // Phone
  String get phone =>
      _g('phone', 'Phone');
  String get phoneOrEmail =>
      _g('phoneOrEmail', 'Email or Phone');

  // Update
  String get update =>
      _g('update', 'Update');
  String get add => _g('add', 'Add');
  String get name => _g('name', 'Name');
  String get nameRequired =>
      _g('nameRequired', 'Name is required');

  // Success messages
  String get successOperation =>
      _g('successOperation', 'Operation completed successfully');

  // Warning messages
  String get warning =>
      _g('warning', 'Warning');
  String get someDocumentsFailed =>
      _g('someDocumentsFailed', 'Department created, but some documents failed to upload');
  String get documentUploadErrors =>
      _g('documentUploadErrors', 'Document Upload Errors');
  String get documentsFailedMessage =>
      _g('documentsFailedMessage', 'The department was created, but the following documents failed to upload:');
  String get canAddDocumentsLater =>
      _g('canAddDocumentsLater', 'You can add these documents later by editing the department.');

  // OK button
  String get ok => _g('ok', 'OK');

  // Optional
  String get optional =>
      _g('optional', '(Optional)');

  // Enter text helpers
  String get enterDepartmentName =>
      _g('enterDepartmentName', 'Enter the name of the department');
  String get optionalDescription =>
      _g('optionalDescription', 'Optional description for the department');

  // Teachings
  String get teachings =>
      _g('teachings', 'Teachings');
  String get addTeaching =>
      _g('addTeaching', 'Add Teaching');
  String get editTeaching =>
      _g('editTeaching', 'Edit Teaching');
  String get teachingDetails =>
      _g('teachingDetails', 'Teaching Details');
  String get teachingTitle =>
      _g('teachingTitle', 'Title');
  String get teachingTitleRequired =>
      _g('teachingTitleRequired', 'Please enter a title');
  String get teachingDate =>
      _g('teachingDate', 'Teaching Date');
  String get teachingDateRequired =>
      _g('teachingDateRequired', 'Please select a date');
  String get speaker =>
      _g('speaker', 'Speaker');
  String get teachingDescription =>
      _g('teachingDescription', 'Description');
  String get updateTeaching =>
      _g('updateTeaching', 'Update Teaching');
  String get teachingAdded =>
      _g('teachingAdded', 'Teaching added successfully');
  String get teachingUpdated =>
      _g('teachingUpdated', 'Teaching updated successfully');
  String get teachingDeleted =>
      _g('teachingDeleted', 'Teaching deleted successfully');
  String get errorLoadingTeaching =>
      _g('errorLoadingTeaching', 'Error loading teaching');
  String get errorDeletingTeaching =>
      _g('errorDeletingTeaching', 'Error deleting teaching');
  String get deleteTeachingConfirm =>
      _g('deleteTeachingConfirm', 'Are you sure you want to delete "{title}"?');
  String deleteTeachingConfirmWithTitle(String title) =>
      deleteTeachingConfirm.replaceAll('{title}', title);
  String get searchTeachings =>
      _g('searchTeachings', 'Search teachings...');
  String get noTeachings =>
      _g('noTeachings', 'No teachings yet');
  String get noTeachingsFound =>
      _g('noTeachingsFound', 'No teachings found matching your search');
  String get listeners =>
      _g('listeners', 'Listeners');
  String get syncFromAttendance =>
      _g('syncFromAttendance', 'Sync from Church Attendance');
  String get searchPotentialListeners =>
      _g('searchPotentialListeners', 'Search potential listeners...');
  String get noListeners =>
      _g('noListeners', 'No listeners yet');
  String get addListener =>
      _g('addListener', 'Add');
  String get addListenerTitle =>
      _g('addListenerTitle', 'Add Listener');
  String get removeListener =>
      _g('removeListener', 'Remove Listener');
  String get removeListenerConfirm =>
      _g('removeListenerConfirm', 'Remove "{name}" from listeners?');
  String removeListenerConfirmWithName(String name) =>
      removeListenerConfirm.replaceAll('{name}', name);
  String get listenerAdded =>
      _g('listenerAdded', 'Listener added successfully');
  String get listenerRemoved =>
      _g('listenerRemoved', 'Listener removed successfully');
  String get errorAddingListener =>
      _g('errorAddingListener', 'Error adding listener');
  String get errorRemovingListener =>
      _g('errorRemovingListener', 'Error removing listener');
  String get errorSyncingListeners =>
      _g('errorSyncingListeners', 'Error syncing listeners');
  String get listenersSynced =>
      _g('listenersSynced', 'Synced {count} listener(s) from church attendance');
  String listenersSyncedWithCount(int count) =>
      listenersSynced.replaceAll('{count}', count.toString());
  String get allListenersAdded =>
      _g('allListenersAdded', 'All potential listeners are already added');
  String get useSyncOrAdd =>
      _g('useSyncOrAdd', 'Use "Sync from Church Attendance" or "Add" to add listeners');

  // Visitors
  String get visitors =>
      _g('visitors', 'Visitors');
  String get addVisitor =>
      _g('addVisitor', 'Add Visitor');
  String get editVisitor =>
      _g('editVisitor', 'Edit Visitor');
  String get updateVisitor =>
      _g('updateVisitor', 'Update Visitor');
  String get visitorFirstName =>
      _g('visitorFirstName', 'First Name');
  String get visitorFirstNameRequired =>
      _g('visitorFirstNameRequired', 'First name is required');
  String get visitorLastName =>
      _g('visitorLastName', 'Last Name');
  String get visitorLastNameRequired =>
      _g('visitorLastNameRequired', 'Last name is required');
  String get visitDate =>
      _g('visitDate', 'Visit Date');
  String get visitDateRequired =>
      _g('visitDateRequired', 'Visit date is required');
  String get visitorAdded =>
      _g('visitorAdded', 'Visitor added successfully');
  String get visitorUpdated =>
      _g('visitorUpdated', 'Visitor updated successfully');
  String get visitorDeleted =>
      _g('visitorDeleted', 'Visitor deleted successfully');
  String get errorLoadingVisitor =>
      _g('errorLoadingVisitor', 'Error loading visitor');
  String get errorDeletingVisitor =>
      _g('errorDeletingVisitor', 'Error deleting visitor');
  String get deleteVisitorConfirm =>
      _g('deleteVisitorConfirm', 'Are you sure you want to delete "{name}"?');
  String deleteVisitorConfirmWithName(String name) =>
      deleteVisitorConfirm.replaceAll('{name}', name);
  String get searchVisitors =>
      _g('searchVisitors', 'Search visitors...');
  String get noVisitors =>
      _g('noVisitors', 'No visitors yet');
  String get noVisitorsFound =>
      _g('noVisitorsFound', 'No visitors found matching your search');
  String get convertToMember =>
      _g('convertToMember', 'Convert to Member');
  String get convertVisitorToMember =>
      _g('convertVisitorToMember', 'Convert visitor to member');
  String convertVisitorToMemberConfirm(String name) =>
      (_localizedValues[locale
                  .languageCode]?['convertVisitorToMemberConfirm'] ??
              'Create a member profile for "{name}" using the visitor\'s contact details. The visitor record will be removed.')
          .replaceAll('{name}', name);
  String get visitorConvertedToMember =>
      _g('visitorConvertedToMember', 'Visitor converted to member successfully');
  String get errorConvertingVisitor =>
      _g('errorConvertingVisitor', 'Error converting visitor to member');

  // Workers & Departments
  String get workers =>
      _g('workers', 'Workers');
  String get searchWorkers =>
      _g('searchWorkers', 'Search workers...');
  String get noWorkers =>
      _g('noWorkers', 'No workers found');
  String get noWorkersFound =>
      _g('noWorkersFound', 'No workers found matching your search');
  String get noDepartmentsAssigned =>
      _g('noDepartmentsAssigned', 'No departments assigned');
  String get setMainDepartment =>
      _g('setMainDepartment', 'Set Main Department');
  String get setMainDepartmentFor =>
      _g('setMainDepartmentFor', 'Set Main Department for {name}');
  String setMainDepartmentForWithName(String name) =>
      setMainDepartmentFor.replaceAll('{name}', name);
  String get workerNoDepartments =>
      _g('workerNoDepartments', 'Worker has no departments assigned');
  String get updatingMainDepartment =>
      _g('updatingMainDepartment', 'Updating main department...');
  String get mainDepartmentUpdated =>
      _g('mainDepartmentUpdated', 'Main department updated successfully');
  String get errorUpdatingMainDepartment =>
      _g('errorUpdatingMainDepartment', 'Error updating main department');

  // Leader Access
  String get leaderAccessManagement =>
      _g('leaderAccessManagement', 'Leader Access Management');
  String get defineFeatureAccess =>
      _g('defineFeatureAccess', 'Define feature access for each leader');
  String get featureAccessPermissions =>
      _g('featureAccessPermissions', 'Feature Access Permissions');
  String get unsavedChanges =>
      _g('unsavedChanges', 'Unsaved changes');
  String get saveAllChanges =>
      _g('saveAllChanges', 'Save All Changes');
  String get allAccessSaved =>
      _g('allAccessSaved', 'All access permissions saved successfully');
  String get errorSavingAccess =>
      _g('errorSavingAccess', 'Error saving access');
  String get errorLoadingLeaders =>
      _g('errorLoadingLeaders', 'Error loading leaders');
  String get errorLoadingAccess =>
      _g('errorLoadingAccess', 'Error loading access');
  String get canView =>
      _g('canView', 'View');
  String get canCreate =>
      _g('canCreate', 'Create');
  String get canEdit =>
      _g('canEdit', 'Edit');
  String get canDelete =>
      _g('canDelete', 'Delete');

  // Settings
  String get adminSettings =>
      _g('adminSettings', 'Admin Settings');
  String get language =>
      _g('language', 'Language');
  String get theme =>
      _g('theme', 'Theme');
  String get enableNotifications =>
      _g('enableNotifications', 'Enable Notifications');
  String get receivePushNotifications =>
      _g('receivePushNotifications', 'Receive push notifications');
  String get exportAllData =>
      _g('exportAllData', 'Export All Data');
  String get exportAllDataSubtitle =>
      _g('exportAllDataSubtitle', 'Export all data to JSON file');
  String get importData =>
      _g('importData', 'Import Data');
  String get importDataSubtitle =>
      _g('importDataSubtitle', 'Import data from JSON file');
  String get exportMembers =>
      _g('exportMembers', 'Export Members');
  String get exportMembersSubtitle =>
      _g('exportMembersSubtitle', 'Export members to CSV');
  String get syncUsersMembers =>
      _g('syncUsersMembers', 'Sync Users & Members');
  String get generateAllUsersReport =>
      _g('generateAllUsersReport', 'Generate All Users Report');
  String get birthdayNotifications =>
      _g('birthdayNotifications', 'Birthday Notifications');
  String get configureBirthdayNotifications =>
      _localizedValues[locale
          .languageCode]?['configureBirthdayNotifications'] ??
      'Configure birthday notification settings';
  String get currentUser =>
      _g('currentUser', 'Current User');
  String get signOutAccount =>
      _g('signOutAccount', 'Sign out of your account');
  String get appVersion =>
      _g('appVersion', 'App Version');
  String get logoutConfirm =>
      _g('logoutConfirm', 'Are you sure you want to logout?');
  String get languageChanged =>
      _g('languageChanged', 'Language changed successfully');
  String get errorChangingLanguage =>
      _g('errorChangingLanguage', 'Failed to change language');
  String get themeChanged =>
      _g('themeChanged', 'Theme changed successfully');
  String get errorChangingTheme =>
      _g('errorChangingTheme', 'Failed to change theme');
  String get errorUpdatingNotifications =>
      _g('errorUpdatingNotifications', 'Failed to update notifications');
  String get export =>
      _g('export', 'Export');
  String get importing =>
      _g('importing', 'Importing data...');
  String get exporting =>
      _g('exporting', 'Exporting data...');
  String get dataExported =>
      _g('dataExported', 'Data exported successfully to:\n{path}');
  String dataExportedWithPath(String path) =>
      dataExported.replaceAll('{path}', path);
  String get exportCancelled =>
      _g('exportCancelled', 'Export cancelled');
  String get exportFailed =>
      _g('exportFailed', 'Export failed');
  String get membersExported =>
      _g('membersExported', 'Members exported successfully');
  String get sync => _g('sync', 'Sync');
  String get syncing =>
      _g('syncing', 'Syncing users and members...');
  String get syncFailed =>
      _g('syncFailed', 'Sync failed');
  String get reportSaved =>
      _g('reportSaved', 'Report saved successfully to:\n{path}');
  String reportSavedWithPath(String path) =>
      reportSaved.replaceAll('{path}', path);
  String get reportGenerationCancelled =>
      _g('reportGenerationCancelled', 'Report generation cancelled');
  String get reportGenerationFailed =>
      _g('reportGenerationFailed', 'Report generation failed');
  String get import =>
      _g('import', 'Import');
  String get importFailed =>
      _g('importFailed', 'Import failed');
  String get english =>
      _g('english', 'English');
  String get french =>
      _g('french', 'Français');
  String get selectTheme =>
      _g('selectTheme', 'Select Theme');
  String get light =>
      _g('light', 'Light');
  String get dark => _g('dark', 'Dark');
  String get systemDefault =>
      _g('systemDefault', 'System Default');
  String get birthdayNotificationsSettings =>
      _g('birthdayNotificationsSettings', 'Birthday Notifications');
  String get allChurchAppUsers =>
      _g('allChurchAppUsers', 'All Church App Users');
  String get defaultAllActiveMembers =>
      _g('defaultAllActiveMembers', 'Default: All active members');
  String get leadersOnly =>
      _g('leadersOnly', 'Leaders Only');
  String get onlyDepartmentLeadersAdmins =>
      _g('onlyDepartmentLeadersAdmins', 'Only department leaders and admins');
  String get optOutNoNotifications =>
      _g('optOutNoNotifications', 'Opt-Out (No Notifications)');
  String get usersCanOptIn =>
      _g('usersCanOptIn', 'Users can opt-in individually');
  String get note => _g('note', 'Note');
  String get saveSettings =>
      _g('saveSettings', 'Save Settings');
  String get settingsSaved =>
      _g('settingsSaved', 'Settings saved successfully');
  String get errorSavingConfig =>
      _g('errorSavingConfig', 'Error saving config');
  String get errorLoadingConfig =>
      _g('errorLoadingConfig', 'Error loading config');
  String get notificationsEnabled =>
      _g('notificationsEnabled', 'Notifications enabled');
  String get notificationsDisabled =>
      _g('notificationsDisabled', 'Notifications disabled');
  String get exportAllDataConfirm =>
      _g('exportAllDataConfirm', 'This will export all members, departments, classes, events, and tasks to a JSON file. You will be asked to select a save location. Continue?');
  String get syncUsersMembersConfirm =>
      _g('syncUsersMembersConfirm', 'This will:\n1. Create a member for every user\n2. Create a user (with default password "Password123") for every leader member\n\nLeaders will be required to change their password on first login.\n\nContinue?');
  String get syncCompleted =>
      _g('syncCompleted', 'Sync completed!');
  String get usersToMembers =>
      _g('usersToMembers', 'Users → Members');
  String get leadersToUsers =>
      _g('leadersToUsers', 'Leaders → Users');
  String get createdLabel =>
      _g('createdLabel', 'created');
  String get skippedLabel =>
      _g('skippedLabel', 'skipped');
  String get errorsLabel =>
      _g('errorsLabel', 'errors');
  String get importDataConfirm =>
      _g('importDataConfirm', 'This will import data from a JSON file. Existing members with the same email will be skipped. Continue?');
  String get importCompleted =>
      _g('importCompleted', 'Import completed');
  String get importedLabel =>
      _g('importedLabel', 'Imported');
  String get notLoggedIn =>
      _g('notLoggedIn', 'Not logged in');
  String get logoutFailed =>
      _g('logoutFailed', 'Logout failed');
  String get languageAndRegion =>
      _g('languageAndRegion', 'Language & Region');
  String get appearance =>
      _g('appearance', 'Appearance');
  String get dataManagement =>
      _g('dataManagement', 'Data Management');
  String get about =>
      _g('about', 'About');
  String get generateReportComprehensive =>
      _g('generateReportComprehensive', 'Generate comprehensive report for all users');
  String get account =>
      _g('account', 'Account');

  // Events
  String get addEvent =>
      _g('addEvent', 'Add Event');
  String get editEvent =>
      _g('editEvent', 'Edit Event');
  String get deleteEvent =>
      _g('deleteEvent', 'Delete Event');
  String get eventDeleted =>
      _g('eventDeleted', 'Event deleted successfully');
  String get errorDeletingEvent =>
      _g('errorDeletingEvent', 'Error deleting event');
  String get deleteEventConfirm =>
      _g('deleteEventConfirm', 'Are you sure you want to delete "{title}"?');
  String deleteEventConfirmWithTitle(String title) =>
      deleteEventConfirm.replaceAll('{title}', title);
  String get searchEvents =>
      _g('searchEvents', 'Search events...');
  String get noEvents =>
      _g('noEvents', 'No events yet');
  String get noEventsFound =>
      _g('noEventsFound', 'No events found matching your search');

  // Church Attendance
  String get churchAttendance =>
      _g('churchAttendance', 'Church Attendance');
  String get sundaySchool =>
      _g('sundaySchool', 'Sunday School');

  /// Church attendance PDF — column / chart strings
  String get churchAttendanceReportPdfTitle =>
      _localizedValues[locale
          .languageCode]?['churchAttendanceReportPdfTitle'] ??
      'Church attendance report';
  String get churchAttendanceReportPdfIntro =>
      _localizedValues[locale
          .languageCode]?['churchAttendanceReportPdfIntro'] ??
      'This report is organised by calendar month. Each month includes a member table (Onsite / Online / Absent per service) and monthly summary charts. '
          'The last column is left blank for notes.';
  String churchAttendanceReportPdfDiligenceNote(
    int pctDiligent,
    int pctModerate,
  ) =>
      (_localizedValues[locale
                  .languageCode]?['churchAttendanceReportPdfDiligenceNote'] ??
              'Diligence: ≥{d}% present = Diligent; ≥{m}% = Moderately diligent; below = Not diligent. '
                  'Present = onsite + online, denominator = number of scheduled services in the month.')
          .replaceAll('{d}', '$pctDiligent')
          .replaceAll('{m}', '$pctModerate');
  String get attendanceReportFullName =>
      _g('attendanceReportFullName', 'Full name');
  String get attendanceReportOnsiteTotal =>
      _g('attendanceReportOnsiteTotal', 'Onsite (total)');
  String get attendanceReportOnlineTotal =>
      _g('attendanceReportOnlineTotal', 'Online (total)');
  String get attendanceReportTotalPresent =>
      _g('attendanceReportTotalPresent', 'Total present');
  String get attendanceReportObservation =>
      _g('attendanceReportObservation', 'Observation');
  String get attendanceReportSpecificObservations =>
      _localizedValues[locale
          .languageCode]?['attendanceReportSpecificObservations'] ??
      'Specific observations';
  String get attendanceReportPresentAbbr =>
      _g('attendanceReportPresentAbbr', 'P');
  String get attendanceReportAbsentAbbr =>
      _g('attendanceReportAbsentAbbr', 'A');
  String get attendanceReportOnlineAbbr =>
      _g('attendanceReportOnlineAbbr', 'O');
  String get attendanceReportOnsite =>
      _g('attendanceReportOnsite', 'Onsite');
  String get attendanceReportOnline =>
      _g('attendanceReportOnline', 'Online');
  String get attendanceReportAbsent =>
      _g('attendanceReportAbsent', 'Absent');
  String get attendanceReportVisitor =>
      _g('attendanceReportVisitor', 'Visitor');
  String get attendanceReportVisitorsSection =>
      _localizedValues[locale
          .languageCode]?['attendanceReportVisitorsSection'] ??
      'Visitors';
  String get attendanceReportChildTag =>
      _g('attendanceReportChildTag', 'Child');
  String get attendanceReportNewComerTag =>
      _g('attendanceReportNewComerTag', 'New comer');
  String get attendanceReportMembersSection =>
      _localizedValues[locale
          .languageCode]?['attendanceReportMembersSection'] ??
      'Members';
  String get attendanceReportMonthlySummaryTitle =>
      _localizedValues[locale
          .languageCode]?['attendanceReportMonthlySummaryTitle'] ??
      'Monthly attendance (sum of present counts)';
  String get attendanceReportPresenceChartsSection =>
      _localizedValues[locale
          .languageCode]?['attendanceReportPresenceChartsSection'] ??
      'Monthly presence';
  String get attendanceReportSundayMonthlyPresenceChart =>
      _localizedValues[locale
          .languageCode]?['attendanceReportSundayMonthlyPresenceChart'] ??
      'Sunday — present count by service';
  String get attendanceReportWednesdayMonthlyPresenceChart =>
      _localizedValues[locale
          .languageCode]?['attendanceReportWednesdayMonthlyPresenceChart'] ??
      'Wednesday — present count by service';
  String get attendanceReportTotalMonthlyPresenceChart =>
      _localizedValues[locale
          .languageCode]?['attendanceReportTotalMonthlyPresenceChart'] ??
      'Total presence — by service date (chronological)';
  String get attendanceReportSundayMonthTotal =>
      _localizedValues[locale
          .languageCode]?['attendanceReportSundayMonthTotal'] ??
      'Sunday (month)';
  String get attendanceReportWednesdayMonthTotal =>
      _localizedValues[locale
          .languageCode]?['attendanceReportWednesdayMonthTotal'] ??
      'Wednesday (month)';
  String get attendanceReportAllServicesMonthTotal =>
      _localizedValues[locale
          .languageCode]?['attendanceReportAllServicesMonthTotal'] ??
      'All services (month)';
  String get attendanceReportChartNoData =>
      _g('attendanceReportChartNoData', 'No data');
  String get attendanceReportDiligent =>
      _g('attendanceReportDiligent', 'Diligent');
  String get attendanceReportModeratelyDiligent =>
      _localizedValues[locale
          .languageCode]?['attendanceReportModeratelyDiligent'] ??
      'Moderately diligent';
  String get attendanceReportNotDiligent =>
      _g('attendanceReportNotDiligent', 'Not diligent');
  String get attendanceReportSundayShort =>
      _g('attendanceReportSundayShort', 'Sun');
  String get attendanceReportWednesdayShort =>
      _localizedValues[locale
          .languageCode]?['attendanceReportWednesdayShort'] ??
      'Wed';
  String get churchAttendanceReportPdfGenerated =>
      _localizedValues[locale
          .languageCode]?['churchAttendanceReportPdfGenerated'] ??
      'Generated';
  String get churchAttendanceReportPdfPeriod =>
      _localizedValues[locale
          .languageCode]?['churchAttendanceReportPdfPeriod'] ??
      'Period';
  String get churchAttendanceReportPdfServiceFilter =>
      _localizedValues[locale
          .languageCode]?['churchAttendanceReportPdfServiceFilter'] ??
      'Service type';
  String get churchAttendanceReportPdfSundayService =>
      _localizedValues[locale
          .languageCode]?['churchAttendanceReportPdfSundayService'] ??
      'Sunday service';
  String get churchAttendanceReportPdfWednesdayService =>
      _localizedValues[locale
          .languageCode]?['churchAttendanceReportPdfWednesdayService'] ??
      'Wednesday service';

  // Reports
  String get trainingReport =>
      _g('trainingReport', 'Training Report');
  String get memberReport =>
      _g('memberReport', 'Member Report');
  String get updateReport =>
      _g('updateReport', 'Update Report');
  String get createReportTitle =>
      _g('createReportTitle', 'Create Report');
  String get reportTitle =>
      _g('reportTitle', 'Title');
  String get reportTitleRequired =>
      _g('reportTitleRequired', 'Title is required');
  String get monthlyReport =>
      _g('monthlyReport', 'Monthly Report');
  String get yearlyReport =>
      _g('yearlyReport', 'Yearly Report');
  String get year => _g('year', 'Year');
  String get month =>
      _g('month', 'Month');
  String get selectMonth =>
      _g('selectMonth', 'Select month');
  String get pleaseSelectMonth =>
      _g('pleaseSelectMonth', 'Please select a month');
  String get summaryReportGenerated =>
      _g('summaryReportGenerated', 'Summary report generated successfully');
  String get errorGeneratingSummaryReport =>
      _g('errorGeneratingSummaryReport', 'Error generating report');
  String get reportCreated =>
      _g('reportCreated', 'Report created successfully');
  String get reportUpdated =>
      _g('reportUpdated', 'Report updated successfully');
  String get errorCreatingReport =>
      _g('errorCreatingReport', 'Error creating report');
  String get errorUpdatingReport =>
      _g('errorUpdatingReport', 'Error updating report');
  String get errorLoadingReport =>
      _g('errorLoadingReport', 'Error loading report');
  String get errorLoadingData =>
      _g('errorLoadingData', 'Error loading data');
  String get failedToGetDepartment =>
      _g('failedToGetDepartment', 'Failed to get department');
  String get reportGeneratedWithPath =>
      _g('reportGeneratedWithPath', 'Report generated successfully: {path}');
  String reportGeneratedWithPathString(String path) =>
      reportGeneratedWithPath.replaceAll('{path}', path);

  static const Map<String, Map<String, String>> _literalValues = {
    'fr': {
      'Just now': 'À l\'instant',
      'Yesterday': 'Hier',
      '{count}m ago': 'Il y a {count} min',
      '{count}h ago': 'Il y a {count} h',
      '{count}d ago': 'Il y a {count} j',
      'Please enter event title': 'Veuillez saisir le titre de l\'événement',
      'Training name is required': 'Le nom de la formation est requis',
      'Add': 'Ajouter',
      'All': 'Tous',
      'All tasks': 'Toutes les tâches',
      'All members': 'Tous les membres',
      'All Priorities': 'Toutes les priorités',
      'All projects': 'Tous les projets',
      'All Statuses': 'Tous les statuts',
      'All tags': 'Toutes les étiquettes',
      'Absent': 'Absent',
      'Amount': 'Montant',
      'Back': 'Retour',
      'Backoffice': 'Backoffice',
      'Archive': 'Archiver',
      'Archived': 'Archivé',
      'Assigned': 'Assigné',
      'Assigned members': 'Membres assignés',
      'Assigned member': 'Membre assigné',
      'Attendance Report': 'Rapport de présence',
      'Attended': 'Présences',
      'Blocked from new task assignments':
          'Bloqué pour les nouvelles assignations de tâches',
      'Board': 'Tableau',
      'Cancel': 'Annuler',
      'Cancelled': 'Annulé',
      'Capture a teaching with its date, speaker, and notes.':
          'Enregistrez un enseignement avec sa date, son intervenant et ses notes.',
      'Category': 'Catégorie',
      'Charts': 'Graphiques',
      'Timeline': 'Chronologie',
      'No scheduled tasks to display on the timeline.':
          'Aucune tâche planifiée à afficher sur la chronologie.',
      'Zoom in': 'Zoom avant',
      'Zoom out': 'Zoom arrière',
      'Fit to width': 'Ajuster à la largeur',
      'Unassigned': 'Non assigné',
      'No tag': 'Aucun tag',
      'Create tag': 'Créer un tag',
      'Could not update task: {error}':
          'Impossible de mettre à jour la tâche : {error}',
      'Could not update assignment: {error}':
          'Impossible de mettre à jour l\'assignation : {error}',
      'Could not update tags: {error}':
          'Impossible de mettre à jour les tags : {error}',
      'Avg. lateness': 'Retard moyen',
      'Workload': 'Charge',
      'Current department': 'Département actuel',
      'Average lateness per member': 'Retard moyen par membre',
      'Average days late on scheduled tasks with assignees':
          'Nombre moyen de jours de retard sur les tâches planifiées avec assignés',
      'Department: {name}': 'Département : {name}',
      'Members tracked': 'Membres suivis',
      'Team average': 'Moyenne équipe',
      'Highest avg.': 'Retard max.',
      'Average days late': 'Jours de retard moyens',
      'Lateness trend by member': 'Tendance du retard par membre',
      'No lateness data for assigned tasks yet':
          'Aucune donnée de retard pour les tâches assignées',
      'Member workload': 'Charge par membre',
      'Open task load weighted by priority (urgent counts more)':
          'Charge des tâches ouvertes pondérée par priorité (urgent compte plus)',
      'Active members': 'Membres actifs',
      'Total load': 'Charge totale',
      'Busiest': 'Le plus chargé',
      'Workload share': 'Répartition de la charge',
      'Open tasks by member': 'Tâches ouvertes par membre',
      'No active assignments to chart yet':
          'Aucune assignation active à afficher',
      'Clear': 'Effacer',
      'Clear filters': 'Effacer les filtres',
      'Close': 'Fermer',
      'Completed': 'Terminé',
      'Confirm': 'Confirmer',
      'Create': 'Créer',
      'Create a training and optionally link it to a department.':
          'Créez une formation et associez-la éventuellement à un département.',
      'Date': 'Date',
      'Delete': 'Supprimer',
      'Description': 'Description',
      'Details': 'Détails',
      'Done': 'Terminé',
      'Drop tasks here': 'Déposez les tâches ici',
      'Drag to another project': 'Glisser vers un autre projet',
      'Could not move task: {error}':
          'Impossible de déplacer la tâche : {error}',
      'View details': 'Voir les détails',
      'Delete task': 'Supprimer la tâche',
      'Delete {count} tasks': 'Supprimer {count} tâches',
      'Delete task?': 'Supprimer la tâche ?',
      'Are you sure you want to delete "{title}"? This action cannot be undone.':
          'Voulez-vous vraiment supprimer « {title} » ? Cette action est irréversible.',
      'Task deleted': 'Tâche supprimée',
      'Could not delete task: {error}':
          'Impossible de supprimer la tâche : {error}',
      'Delete {count} tasks?': 'Supprimer {count} tâches ?',
      'This will permanently delete {count} selected tasks. This action cannot be undone.':
          'Cela supprimera définitivement {count} tâches sélectionnées. Cette action est irréversible.',
      'Delete all': 'Tout supprimer',
      '{count} tasks deleted': '{count} tâches supprimées',
      'Could not delete tasks: {error}':
          'Impossible de supprimer les tâches : {error}',
      '{count} selected': '{count} sélectionnée(s)',
      'Due date': 'Date limite',
      'Edit': 'Modifier',
      'Email': 'E-mail',
      'End date': 'Date de fin',
      'Enter a valid amount': 'Saisissez un montant valide',
      'Error': 'Erreur',
      'Error loading tasks: {error}':
          'Erreur lors du chargement des tâches : {error}',
      'Error recording payment: {error}':
          'Erreur lors de l\'enregistrement du paiement : {error}',
      'Error sending reminders: {error}':
          'Erreur lors de l\'envoi des rappels : {error}',
      'Export': 'Exporter',
      'Failed to generate PDF report: {error}':
          'Échec de la génération du rapport PDF : {error}',
      'Filter': 'Filtrer',
      'Filter Tasks': 'Filtrer les tâches',
      'Filters': 'Filtres',
      'Filters on': 'Filtres actifs',
      'Generate PDF Report': 'Générer le rapport PDF',
      'High': 'Élevée',
      'In progress': 'En cours',
      'Import': 'Importer',
      'Intention': 'Intention',
      'Joined': 'Arrivé',
      'Last attended': 'Dernière présence',
      'Loading...': 'Chargement...',
      'Low': 'Faible',
      'Manage projects': 'Gérer les projets',
      'Manage tags': 'Gérer les étiquettes',
      'Medium': 'Moyenne',
      'More': 'Plus',
      'Name': 'Nom',
      'New Comers': 'Nouveaux venus',
      'New Comers Report': 'Rapport des nouveaux venus',
      'Newcomer Attendance': 'Présence des nouveaux venus',
      'Newcomer Stats': 'Statistiques des nouveaux venus',
      'No data': 'Aucune donnée',
      'No data yet': 'Aucune donnée pour le moment',
      'No newcomer attendance found for this period.':
          'Aucune présence de nouveau venu trouvée pour cette période.',
      'No newcomer records found for this period.':
          'Aucun enregistrement de nouveau venu trouvé pour cette période.',
      'No project': 'Aucun projet',
      'No tasks found': 'Aucune tâche trouvée',
      'No tasks match this view': 'Aucune tâche ne correspond à cette vue',
      'No tasks yet': 'Aucune tâche pour le moment',
      'No unpaid penalties': 'Aucune pénalité impayée',
      'Note (optional)': 'Note (facultative)',
      'Notes': 'Notes',
      'Online': 'En ligne',
      'Open': 'Ouvrir',
      'Open tasks': 'Tâches ouvertes',
      'Onsite': 'Sur place',
      'Overdue': 'En retard',
      'PDF report generated: {path}': 'Rapport PDF généré : {path}',
      'Pending': 'En attente',
      'Penalties': 'Pénalités',
      'Penalty balance pending': 'Solde de pénalité en attente',
      'Priority': 'Priorité',
      'Project': 'Projet',
      'Project workload': 'Charge par projet',
      'Projects': 'Projets',
      'Record': 'Enregistrer',
      'Record payment': 'Enregistrer un paiement',
      'Record payment for {name}': 'Enregistrer un paiement pour {name}',
      'Refresh': 'Actualiser',
      'Reminder': 'Rappel',
      'Reminder sent for {count} task assignment(s)':
          'Rappel envoyé pour {count} assignation(s) de tâche',
      'Save': 'Enregistrer',
      'Search': 'Rechercher',
      'Search tasks, projects, assignees...':
          'Rechercher des tâches, projets, assignés...',
      'Search tasks...': 'Rechercher des tâches...',
      'Send general reminder': 'Envoyer un rappel général',
      'Send general task reminder?': 'Envoyer un rappel général de tâche ?',
      'Send reminder': 'Envoyer le rappel',
      'Select end date': 'Sélectionner la date de fin',
      'Select start date': 'Sélectionner la date de début',
      'Services': 'Cultes',
      'Start date': 'Date de début',
      'Status': 'Statut',
      'Success': 'Succès',
      'Tags': 'Étiquettes',
      'Task': 'Tâche',
      'Tasks': 'Tâches',
      'Tasks workspace': 'Espace des tâches',
      'This will notify all members who currently have pending or in-progress tasks.':
          'Cela notifiera tous les membres qui ont actuellement des tâches en attente ou en cours.',
      'Title': 'Titre',
      'Training details': 'Détails de la formation',
      'Try another filter or create a new task.':
          'Essayez un autre filtre ou créez une nouvelle tâche.',
      'Unknown': 'Inconnu',
      'Update the teaching details without leaving the current workspace.':
          'Mettez à jour les détails de l\'enseignement sans quitter l\'espace de travail actuel.',
      'Update the training details without leaving the current workspace.':
          'Mettez à jour les détails de la formation sans quitter l\'espace de travail actuel.',
      'Unnamed member': 'Membre sans nom',
      'Untitled project': 'Projet sans titre',
      'Untitled task': 'Tâche sans titre',
      'Urgent': 'Urgente',
      'View': 'Voir',
      'Visible tasks': 'Tâches visibles',
      'attendances': 'présences',
      'records': 'enregistrements',
      'saved': 'enregistré',
      '{completed}/{total} done': '{completed}/{total} terminées',
      '{visible} visible of {total} tasks':
          '{visible} visibles sur {total} tâches',
      '+{count} more tasks': '+{count} autres tâches',

      '(Optional)': '(Facultatif)',
      'Actions': 'Actions',
      'Active': 'Actif',
      'Activity Logs': 'Journaux d\'activité',
      'Add Department': 'Ajouter un département',
      'Add First Record': 'Ajouter le premier enregistrement',
      'Add Giving Record': 'Ajouter un enregistrement de don',
      'Add Listener': 'Ajouter un auditeur',
      'Add Member': 'Ajouter un membre',
      'Add Members': 'Ajouter des membres',
      'Add Members to Training': 'Ajouter des membres à la formation',
      'Add Task': 'Ajouter une tâche',
      'Add Visitor': 'Ajouter un visiteur',
      'Add skill': 'Ajouter une compétence',
      'Add task': 'Ajouter une tâche',
      'Add {count}': 'Ajouter {count}',
      'Additional comments or notes (optional)': 'Commentaires ou notes supplémentaires (facultatif)',
      'Address': 'Adresse',
      'Admin': 'Admin',
      'Admin Panel': 'Panneau d\'administration',
      'All church services': 'Tous les cultes',
      'Search by date...': 'Rechercher par date...',
      'Search results': 'Résultats de la recherche',
      'No matching services': 'Aucun culte ne correspond',
      'Try another date or clear the search': 'Essayez une autre date ou effacez la recherche',
      'Clear search': 'Effacer la recherche',
      'All members are already enrolled in this class': 'Tous les membres sont déjà inscrits à cette classe',
      'All potential listeners are already added': 'Tous les auditeurs potentiels sont déjà ajoutés',
      'Announcement created successfully': 'Annonce créée avec succès',
      'Choose a conversation to start messaging':
          'Choisissez une conversation pour commencer',
      'Church-wide messages': 'Messages pour toute l\'église',
      'Department chat': 'Discussion du département',
      'Direct messages': 'Messages directs',
      'Everyone': 'Tout le monde',
      'Messages sent to specific members':
          'Messages envoyés à des membres précis',
      'No conversations found': 'Aucune conversation trouvée',
      'No messages yet': 'Aucun message pour le moment',
      'Search conversations...': 'Rechercher des conversations...',
      'Select a conversation': 'Sélectionnez une conversation',
      'Select recipients': 'Sélectionner des destinataires',
      'Send': 'Envoyer',
      'Send the first message': 'Envoyez le premier message',
      'Today': 'Aujourd\'hui',
      'Type a message...': 'Écrire un message...',
      'You': 'Vous',
      'Video call': 'Appel vidéo',
      'Join video call': 'Rejoindre l\'appel vidéo',
      'Start video call': 'Démarrer un appel vidéo',
      'Video call in progress': 'Appel vidéo en cours',
      'Open in browser': 'Ouvrir dans le navigateur',
      'Could not start video call': 'Impossible de démarrer l\'appel vidéo',
      'A video call started in {channel}. Tap Join video call to join.':
          'Un appel vidéo a commencé dans {channel}. Appuyez sur Rejoindre l\'appel vidéo.',
      'Apply': 'Appliquer',
      'Are you sure you want to delete "{title}"?': 'Voulez-vous vraiment supprimer « {title} » ?',
      'Are you sure you want to delete this class? This will deactivate it.': 'Voulez-vous vraiment supprimer cette formation ? Elle sera désactivée.',
      'Are you sure you want to delete this event?': 'Êtes-vous sûr de vouloir supprimer cet événement ?',
      'Are you sure you want to delete this event? This will deactivate it.': 'Voulez-vous vraiment supprimer cet événement ? Il sera désactivé.',
      'Are you sure you want to delete this session?': 'Voulez-vous vraiment supprimer cette session ?',
      'Are you sure you want to remove this member from the class?': 'Voulez-vous vraiment retirer ce membre de la formation ?',
      'Are you sure you want to remove this registration?': 'Êtes-vous sûr de vouloir supprimer cette inscription ?',
      'Assign roles to users': 'Attribuer des rôles aux utilisateurs',
      'Assignee filter': 'Filtre par assigné',
      'At least email or phone is required': 'Au moins un e-mail ou un téléphone est requis',
      'Attendance': 'Présence',
      'Attendance Details': 'Détails de présence',
      'Attendance Records': 'Registre de présence',
      'Attendance Trend': 'Tendance de présence',
      'Attendance is tracked per session': 'La présence est suivie par session',
      'Attendance tracking coming soon': 'Suivi de présence bientôt disponible',
      'Avg attendance': 'Présence moyenne',
      'Back to Login': 'Retour à la connexion',
      'Basic information': 'Informations de base',
      'Birthday': 'Date de naissance',
      'Birthday *': 'Date de naissance *',
      'Birthday is required': 'La date de naissance est requise',
      'Change Password': 'Changer le mot de passe',
      'Change Password Required': 'Changement de mot de passe requis',
      'Check if this is a new comer. Status will automatically change to member after 9+ service attendances in 3 months.': 'Cochez si c\'est un nouveau venu. Le statut passera automatiquement à membre après 9+ présences aux cultes en 3 mois.',
      'Choose from gallery': 'Choisir dans la galerie',
      'Church Attendance': 'Présence au culte',
      'Church service': 'Culte',
      'City': 'Ville',
      'Clear All': 'Tout effacer',
      'Comments': 'Commentaires',
      'Confirm New Password': 'Confirmer le nouveau mot de passe',
      'Confirm Password': 'Confirmer le mot de passe',
      'Contact': 'Contact',
      'Convert to Member': 'Convertir en membre',
      'Convert visitor to member': 'Convertir le visiteur en membre',
      'Could not create task': 'Impossible de créer la tâche',
      'Could not move task': 'Impossible de déplacer la tâche',
      'Could not pick photo: \$e': 'Impossible de sélectionner la photo : \\\$e',
      'Could not update assignment': 'Impossible de mettre à jour l\'affectation',
      'Could not update tags': 'Impossible de mettre à jour les étiquettes',
      'Could not update task': 'Impossible de mettre à jour la tâche',
      'Could not update task status': 'Impossible de mettre à jour le statut de la tâche',
      'Country': 'Pays',
      'Create Announcement': 'Créer une annonce',
      'Create Department': 'Créer un département',
      'Create Member': 'Créer un membre',
      'Create Report': 'Créer un rapport',
      'Create Report - {name}': 'Créer un rapport - {name}',
      'Create User': 'Créer un utilisateur',
      'Create a department and attach reference documents': 'Créer un département et joindre des documents de référence',
      'Create a member profile for "{name}" using the visitor\'s contact details. The visitor record will be removed.': 'Créer un profil membre pour « {name} » avec les coordonnées du visiteur. L\'enregistrement visiteur sera supprimé.',
      'Create a new church member profile': 'Créer un nouveau profil de membre',
      'Create admin, pastor, or admin users': 'Créer des utilisateurs admin, pasteur ou admin',
      'Create your first report to get started': 'Créez votre premier rapport pour commencer',
      'Created {date}': 'Créé le {date}',
      'Date TBD': 'Date à confirmer',
      'Day': 'Jour',
      'Defined Objectives *': 'Objectifs définis *',
      'Defined objectives are required': 'Les objectifs définis sont requis',
      'Delete Class': 'Supprimer la classe',
      'Delete Event': 'Supprimer l\'événement',
      'Delete Report': 'Supprimer le rapport',
      'Delete Session': 'Supprimer la session',
      'Delete service attendance?': 'Supprimer la présence au culte ?',
      'Department': 'Département',
      'Department (Optional)': 'Département (facultatif)',
      'Department Name *': 'Nom du département *',
      'Department name is required': 'Le nom du département est requis',
      'Department updated successfully': 'Département mis à jour avec succès',
      'Describe any difficulties or challenges faced': 'Décrivez les difficultés ou défis rencontrés',
      'Deselect All': 'Tout désélectionner',
      'Difficulties Encountered *': 'Difficultés rencontrées *',
      'Difficulties encountered are required': 'Les difficultés rencontrées sont requises',
      'Disable birthday notifications for this member': 'Désactiver les notifications d\'anniversaire pour ce membre',
      'Divorced': 'Divorcé(e)',
      'Document Upload Errors': 'Erreurs de téléversement de documents',
      'Documents (Optional)': 'Documents (facultatif)',
      'Does not know yet': 'Ne sait pas encore',
      'Domain of Activity': 'Domaine d\'activité',
      'Domain of Activity *': 'Domaine d\'activité *',
      'Domain of activity is required': 'Le domaine d\'activité est requis',
      'Edit Department': 'Modifier le département',
      'Edit Event': 'Modifier l\'événement',
      'Edit Member': 'Modifier le membre',
      'Edit Record': 'Modifier l\'enregistrement',
      'Edit Report': 'Modifier le rapport',
      'Edit Training': 'Modifier la formation',
      'Email (Optional)': 'E-mail (facultatif)',
      'Email (recommended)': 'E-mail (recommandé)',
      'Email Sent!': 'E-mail envoyé !',
      'Email is required': 'L\'e-mail est requis',
      'Email: \$guestEmail': 'E-mail : \\\$guestEmail',
      'End Date': 'Date de fin',
      'Enter Reset Token': 'Saisir le jeton de réinitialisation',
      'Enter a descriptive title for this report': 'Saisissez un titre descriptif pour ce rapport',
      'Enter a skill': 'Saisissez une compétence',
      'Enter custom number of sessions': 'Saisissez le nombre personnalisé de sessions',
      'Enter number of sessions to generate': 'Saisissez le nombre de sessions à générer',
      'Enter the email address you used to request password reset': 'Saisissez l\'adresse e-mail utilisée pour demander la réinitialisation',
      'Enter the name of the department': 'Saisissez le nom du département',
      'Enter the token from your email and your new password.': 'Saisissez le jeton reçu par e-mail et votre nouveau mot de passe.',
      'Enter the token you received in your email': 'Saisissez le jeton reçu dans votre e-mail',
      'Enter your email address and we\'ll send you a token to reset your password.': 'Saisissez votre adresse e-mail et nous vous enverrons un jeton pour réinitialiser votre mot de passe.',
      'Error adding listener: {error}': 'Erreur lors de l\'ajout de l\'auditeur : {error}',
      'Error adding members: \$e': 'Erreur lors de l\'ajout des membres : \\\$e',
      'Error converting visitor to member: \$e': 'Erreur lors de la conversion du visiteur : \$e',
      'Error creating announcement: \$e': 'Erreur lors de la création de l\'annonce : \\\$e',
      'Error creating report: \${e.toString()}': 'Erreur lors de la création du rapport : \\\${e.toString()}',
      'Error deleting class: \$e': 'Erreur lors de la suppression de la classe : \\\$e',
      'Error deleting event: \$e': 'Erreur lors de la suppression de l\'événement : \\\$e',
      'Error deleting report: \$e': 'Erreur lors de la suppression du rapport : \\\$e',
            'Error deleting session: {error}': 'Erreur lors de la suppression de la session : {error}',
      'Error deleting teaching: {error}': 'Erreur lors de la suppression de l\'enseignement : {error}',
      'Error deleting visitor: \$e': 'Erreur lors de la suppression du visiteur : \$e',
            'Error generating sessions: \$e': 'Erreur lors de la génération des sessions : \\\$e',
      'Error loading data: \$e': 'Erreur lors du chargement des données : \\\$e',
      'Error loading department: \$e': 'Erreur lors du chargement du département : \\\$e',
      'Error loading event: \$e': 'Erreur lors du chargement de l\'événement : \\\$e',
      'Error loading giving records': 'Erreur lors du chargement des dons',
      'Error loading listeners: {error}': 'Erreur lors du chargement des auditeurs : {error}',
      'Error loading member: \$e': 'Erreur lors du chargement du membre : \\\$e',
      'Error loading members': 'Erreur lors du chargement des membres',
      'Error loading members: \$e': 'Erreur lors du chargement des membres : \\\$e',
      'Error loading registrations: \$e': 'Erreur lors du chargement des inscriptions : \\\$e',
      'Error loading report: \$e': 'Erreur lors du chargement du rapport : \\\$e',
            'Error loading sessions: \$e': 'Erreur lors du chargement des sessions : \\\$e',
      'Error loading tasks': 'Erreur lors du chargement des tâches',
      'Error loading teaching: {error}': 'Erreur lors du chargement de l\'enseignement : {error}',
      'Error loading training: \$e': 'Erreur lors du chargement de la formation : \\\$e',
      'Error loading visitors: \$e': 'Erreur lors du chargement des visiteurs : \$e',
      'Error picking file: \$e': 'Erreur lors de la sélection du fichier : \\\$e',
      'Error recording payment': 'Erreur lors de l\'enregistrement du paiement',
      'Error registering guest: \$e': 'Erreur lors de l\'inscription de l\'invité : \\\$e',
      'Error registering members: \$e': 'Erreur lors de l\'inscription des membres : \\\$e',
      'Error removing listener: {error}': 'Erreur lors du retrait de l\'auditeur : {error}',
      'Error removing member: \$e': 'Erreur lors du retrait du membre : \\\$e',
      'Error removing registration: \$e': 'Erreur lors de la suppression de l\'inscription : \\\$e',
      'Error saving report': 'Erreur lors de l\'enregistrement du rapport',
      'Error sending reminders': 'Erreur lors de l\'envoi des rappels',
      'Error syncing: {error}': 'Erreur de synchronisation : {error}',
      'Error updating report: \${e.toString()}': 'Erreur lors de la mise à jour du rapport : \\\${e.toString()}',
      'Error: \$e': 'Erreur : \\\$e',
      'Event': 'Événement',
      'Event Sessions': 'Sessions de l\'événement',
      'Event deleted successfully': 'Événement supprimé avec succès',
      'Event information': 'Informations sur l\'événement',
      'Event not found': 'Événement introuvable',
      'Export failed: \$e': 'Échec de l\'exportation : \\\$e',
      'Export to CSV': 'Exporter en CSV',
      'Failed to change password': 'Échec du changement de mot de passe',
      'Failed to get department: \$e': 'Impossible d\'obtenir le département : \\\$e',
      'Female': 'Féminin',
      'Filter Services': 'Filtrer les cultes',
      'Filtered church services': 'Cultes filtrés',
      'Finance': 'Finances',
      'First Name': 'Prénom',
      'First Name *': 'Prénom *',
      'First name is required': 'Le prénom est requis',
      'Forgot Password': 'Mot de passe oublié',
      'From': 'Du',
      'Full Name *': 'Nom complet *',
      'Gender': 'Sexe',
      'Generate': 'Générer',
      'Generate 4': 'Générer 4',
      'Generate Church Attendance Report': 'Générer le rapport de présence au culte',
      'Generate Next Sessions': 'Générer les prochaines sessions',
      'Generate PDF': 'Générer le PDF',
      'Generate Report': 'Générer le rapport',
      'Generate Sessions': 'Générer les sessions',
      'Generate Summary Report': 'Générer le rapport de synthèse',
      'Generated \$numberOfSessions sessions': '\\\$numberOfSessions sessions générées',
      'Generating PDF report...': 'Génération du rapport PDF...',
      'Generating PDF...': 'Génération du PDF...',
      'Generating summary report...': 'Génération du rapport de synthèse...',
      'Giver': 'Donateur',
      'Global Announcement': 'Annonce générale',
      'Go to Login': 'Aller à la connexion',
      'Guest': 'Invité',
      'How many sessions would you like to generate?': 'Combien de sessions souhaitez-vous générer ?',
      'How many weeks between each session': 'Nombre de semaines entre chaque session',
      'Inactive': 'Inactif',
      'Invalid email format': 'Format d\'e-mail invalide',
      'Is this member active?': 'Ce membre est-il actif ?',
      'Just passing': 'De passage',
      'Key Skills': 'Compétences clés',
      'Last Diplomas': 'Derniers diplômes',
      'Last Name': 'Nom',
      'Last Name *': 'Nom *',
      'Last name is required': 'Le nom est requis',
      'Leader': 'Responsable',
      'Level of Study': 'Niveau d\'études',
      'List positive achievements or points': 'Listez les réalisations ou points positifs',
      'List the objectives that were defined': 'Listez les objectifs qui ont été définis',
      'Listener added successfully': 'Auditeur ajouté avec succès',
      'Listener removed successfully': 'Auditeur retiré avec succès',
      'Listeners': 'Auditeurs',
      'Male': 'Masculin',
      'Marital Status': 'État civil',
      'Mark Attendance': 'Marquer la présence',
      'Mark New Attendance': 'Marquer une nouvelle présence',
      'Mark attendance for a new church service': 'Marquer la présence pour un nouveau culte',
      'Married': 'Marié(e)',
      'Member': 'Membre',
      'Member Report': 'Rapport de membre',
      'Member added successfully': 'Membre ajouté avec succès',
      'Member created successfully': 'Membre créé avec succès',
      'Member must have at least email or phone for password reset capability. Email is strongly recommended.': 'Le membre doit avoir au moins un e-mail ou un téléphone pour la réinitialisation du mot de passe. L\'e-mail est fortement recommandé.',
      'Member removed successfully': 'Membre retiré avec succès',
      'Member updated successfully': 'Membre mis à jour avec succès',
      'Members': 'Membres',
      'Message *': 'Message *',
      'N/A': 'N/D',
      'New Comer': 'Nouveau venu',
      'New Password': 'Nouveau mot de passe',
      'New password is required': 'Le nouveau mot de passe est requis',
      'Newcomer': 'Nouveau venu',
      'Newcomer Intention': 'Intention du nouveau venu',
      'Newcomer Join Date': 'Date d\'adhésion du nouveau venu',
      'No Department': 'Aucun département',
      'No attendance records found': 'Aucun enregistrement de présence trouvé',
      'No date selected': 'Aucune date sélectionnée',
      'No giving records yet': 'Aucun don enregistré',
      'No listeners yet': 'Aucun auditeur pour le moment',
      'No members enrolled': 'Aucun membre inscrit',
      'No members found in this department': 'Aucun membre trouvé dans ce département',
      'No registrations yet': 'Aucune inscription pour le moment',
      'No reports yet': 'Aucun rapport pour le moment',
      'No services found': 'Aucun culte trouvé',
      'No sessions generated yet': 'Aucune session générée pour le moment',
      'No sessions yet': 'Aucune session pour le moment',
      'No visitors found matching your search': 'Aucun visiteur trouvé correspondant à votre recherche',
      'No visitors yet': 'Aucun visiteur pour le moment',
      'Not set': 'Non défini',
      'Not specified': 'Non précisé',
      'Number of Sessions': 'Nombre de sessions',
      'OK': 'OK',
      'Opt out of birthday notifications': 'Se désabonner des notifications d\'anniversaire',
      'Optional description for the department': 'Description facultative du département',
      'Other': 'Autre',
      'Overview': 'Aperçu',
      'PDF generated successfully': 'PDF généré avec succès',
      'PDF report saved successfully': 'Rapport PDF enregistré avec succès',
            'Password': 'Mot de passe',
      'Password Reset': 'Réinitialisation du mot de passe',
      'Password Reset Successful!': 'Réinitialisation du mot de passe réussie !',
      'Password changed successfully': 'Mot de passe modifié avec succès',
      'Password is required': 'Le mot de passe est requis',
      'Password must be at least 6 characters': 'Le mot de passe doit comporter au moins 6 caractères',
      'Passwords do not match': 'Les mots de passe ne correspondent pas',
      'Pastor': 'Pasteur',
      'Payment recorded': 'Paiement enregistré',
      'Personal information': 'Informations personnelles',
      'Phone': 'Téléphone',
      'Phone (Optional)': 'Téléphone (facultatif)',
      'Phone: \$guestPhone': 'Téléphone : \\\$guestPhone',
      'Please check your email for the password reset token. You\'ll need to enter it on the next screen.': 'Vérifiez votre e-mail pour le jeton de réinitialisation. Vous devrez le saisir à l\'écran suivant.',
      'Please confirm your password': 'Veuillez confirmer votre mot de passe',
      'Please enter announcement message': 'Veuillez saisir le message de l\'annonce',
      'Please enter announcement title': 'Veuillez saisir le titre de l\'annonce',
      'Please enter first name': 'Veuillez saisir le prénom',
      'Please enter guest name': 'Veuillez saisir le nom de l\'invité',
      'Please enter last name': 'Veuillez saisir le nom',
      'Please select at least one member for targeted announcement': 'Veuillez sélectionner au moins un membre pour une annonce ciblée',
      'Positive Points *': 'Points positifs *',
      'Positive points are required': 'Les points positifs sont requis',
      'Profession': 'Profession',
      'Professional details': 'Informations professionnelles',
      'Profile photo (optional)': 'Photo de profil (facultatif)',
      'Provide suggestions for improvement': 'Proposez des suggestions d\'amélioration',
      'Quarter': 'Trimestre',
      'Record someone who visited the church': 'Enregistrer une personne ayant visité l\'église',
      'Recorded: {datetime}': 'Enregistré : {datetime}',
      'Register': 'S\'inscrire',
      'Register Guest': 'Inscrire un invité',
      'Register Members': 'Inscrire des membres',
      'Register for Event': 'S\'inscrire à l\'événement',
      'Registering...': 'Inscription...',
      'Registration failed: \$e': 'Échec de l\'inscription : \\\$e',
      'Registration removed successfully': 'Inscription supprimée avec succès',
      'Registrations': 'Inscriptions',
      'Remove': 'Retirer',
      'Remove "{name}" from listeners?': 'Retirer « {name} » des auditeurs ?',
      'Remove Listener': 'Retirer l\'auditeur',
      'Remove Member': 'Retirer le membre',
      'Remove Registration': 'Supprimer l\'inscription',
      'Remove from training': 'Retirer de la formation',
      'Remove photo': 'Supprimer la photo',
      'Repeated Event': 'Événement récurrent',
      'Report': 'Rapport',
      'Report Title *': 'Titre du rapport *',
      'Report created successfully': 'Rapport créé avec succès',
      'Report deleted successfully': 'Rapport supprimé avec succès',
      'Report exported successfully': 'Rapport exporté avec succès',
            'Report updated successfully': 'Rapport mis à jour avec succès',
      'Required': 'Requis',
      'Required for job seeking and workers': 'Requis pour les demandeurs d\'emploi et les travailleurs',
      'Reset Password': 'Réinitialiser le mot de passe',
      'Reset Token': 'Jeton de réinitialisation',
      'Role': 'Rôle',
      'Role & status': 'Rôle et statut',
      'Role *': 'Rôle *',
      'Role Assignment': 'Attribution des rôles',
      'Role is required': 'Le rôle est requis',
      'Search members...': 'Rechercher des membres...',
      'Search potential listeners...': 'Rechercher des auditeurs potentiels...',
      'Search visitors...': 'Rechercher des visiteurs...',
      'Sector of Studies': 'Secteur d\'études',
      'Select': 'Sélectionner',
      'Select All': 'Tout sélectionner',
      'Select Birthday': 'Sélectionner la date de naissance',
      'Select Date Range': 'Sélectionner la plage de dates',
      'Select Date Range for Report': 'Sélectionner la plage de dates du rapport',
      'Select End Date': 'Sélectionner la date de fin',
      'Select Join Date': 'Sélectionner la date d\'arrivée',
      'Select Members': 'Sélectionner des membres',
      'Select Start Date': 'Sélectionner la date de début',
      'Select birthday': 'Sélectionner la date de naissance',
      'Select date range for report': 'Sélectionner la plage de dates pour le rapport',
      'Select join date': 'Sélectionner la date d\'arrivée',
      'Select member role': 'Sélectionner le rôle du membre',
      'Select members to add:': 'Sélectionner les membres à ajouter :',
      'Select the date when the newcomer joined': 'Sélectionnez la date d\'arrivée du nouveau venu',
      'Select the newcomer\'s intention': 'Sélectionner l\'intention du nouveau venu',
      'Select your current profession/status': 'Sélectionner votre profession/statut actuel',
      'Selecting "Just passing" creates a Visitor, not a Member.': 'Choisir « De passage » crée un visiteur, pas un membre.',
      'Send Reset Link': 'Envoyer le lien de réinitialisation',
      'Send to all members. If disabled, select specific members.': 'Envoyer à tous les membres. Si désactivé, sélectionnez des membres spécifiques.',
      'Service': 'Culte',
      'Service attendance deleted': 'Présence au culte supprimée',
      'Service name': 'Nom du culte',
      'Session {number}': 'Session {number}',
      'Sessions': 'Sessions',
      'Sessions generated successfully': 'Sessions générées avec succès',
      'Set New Password': 'Définir un nouveau mot de passe',
      'Showing': 'Affichage de',
      'Single': 'Célibataire',
      'Sort': 'Trier',
      'Sort ascending': 'Tri croissant',
      'Sort descending': 'Tri décroissant',
      'Speaker': 'Orateur',
      'Start Date': 'Date de début',
      'State': 'Région',
      'Status will change to member after 9+ service attendances in 3 months.': 'Le statut passera à membre après 9+ présences aux cultes en 3 mois.',
      'Successfully registered for event': 'Inscription à l\'événement réussie',
      'Successfully registered guest': 'Invité inscrit avec succès',
      'Successfully registered {count} member(s)': '{count} membre(s) inscrit(s) avec succès',
      'Successfully unregistered from event': 'Désinscription de l\'événement réussie',
      'Suggestions *': 'Suggestions *',
      'Suggestions are required': 'Les suggestions sont requises',
      'Summary report generated successfully': 'Rapport de synthèse généré avec succès',
      'Sympathiser': 'Sympathisant',
      'Sync from Church Attendance': 'Synchroniser depuis la présence aux cultes',
      'Synced {count} listener(s) from church attendance': '{count} auditeur(s) synchronisé(s) depuis la présence aux cultes',
      'Tag': 'Étiquette',
      'Tag filter': 'Filtre par étiquette',
      'Take a photo': 'Prendre une photo',
      'Tap to select date': 'Appuyez pour sélectionner une date',
      'Task has no department; cannot add tags': 'La tâche n\'a pas de département ; impossible d\'ajouter des étiquettes',
      'Task must be assigned to a department first': 'La tâche doit d\'abord être affectée à un département',
      'Task title': 'Titre de la tâche',
      'Task title is required': 'Le titre de la tâche est requis',
      'Teaching': 'Enseignement',
      'Teaching Details': 'Détails de l\'enseignement',
      'This month': 'Ce mois-ci',
      'This will permanently remove all attendance records for {label}, including visitors logged for that service.': 'Cela supprimera définitivement toutes les présences pour {label}, y compris les visiteurs enregistrés pour ce culte.',
      'Title *': 'Titre *',
      'Title is required': 'Le titre est requis',
      'To': 'Au',
      'Token is required': 'Le jeton est requis',
      'Total': 'Total',
      'Total Giving': 'Total des dons',
      'Track and follow up with church visitors': 'Suivre et assurer le suivi des visiteurs de l\'église',
      'Track church service attendance': 'Suivre la présence au culte',
      'Training': 'Formation',
      'Training deleted successfully': 'Formation supprimée avec succès',
      'Training not found': 'Formation introuvable',
      'Type': 'Type',
      'Unnamed': 'Sans nom',
      'Unnamed Visitor': 'Visiteur sans nom',
      'Unregister': 'Se désinscrire',
      'Untitled Report': 'Rapport sans titre',
      'Untitled Teaching': 'Enseignement sans titre',
      'Update Department': 'Mettre à jour le département',
      'Update Member': 'Mettre à jour le membre',
      'Update Report': 'Mettre à jour le rapport',
      'Update department details and documents': 'Mettre à jour les détails et documents du département',
      'Update member profile and details': 'Mettre à jour le profil et les détails du membre',
      'Upload': 'Téléverser',
      'Use "Sync from Church Attendance" or "Add" to add listeners': 'Utilisez « Synchroniser depuis la présence aux cultes » ou « Ajouter » pour ajouter des auditeurs',
      'User created successfully': 'Utilisateur créé avec succès',
      'View system activity logs': 'Consulter les journaux d\'activité du système',
      'Visit Date': 'Date de visite',
      'Visit date is required': 'La date de visite est requise',
      'Visit details': 'Détails de la visite',
      'Visitor': 'Visiteur',
      'Visitor added successfully': 'Visiteur ajouté avec succès',
      'Visitor converted to member successfully': 'Visiteur converti en membre avec succès',
      'Visitor created successfully': 'Visiteur créé avec succès',
      'Visitor deleted successfully': 'Visiteur supprimé avec succès',
      'Visitors': 'Visiteurs',
      'Wants to stay': 'Souhaite rester',
      'Weeks': 'Semaines',
      'Weeks between sessions:': 'Semaines entre les sessions :',
      'Widowed': 'Veuf/Veuve',
      'Worker': 'Travailleur',
      'You can now sign in with your new password.': 'Vous pouvez maintenant vous connecter avec votre nouveau mot de passe.',
      'You must change your password before continuing.': 'Vous devez changer votre mot de passe avant de continuer.',
      'Your password has been successfully reset. You can now log in with your new password.': 'Votre mot de passe a été réinitialisé avec succès. Vous pouvez maintenant vous connecter avec votre nouveau mot de passe.',
      'Zip Code': 'Code postal',
      'attended': 'présent',
      'e.g., 20': 'p. ex., 20',
      'member': 'membre',
      '{count} member(s) selected': '{count} membre(s) sélectionné(s)',
      '{name} Reports': 'Rapports {name}',
      '—': '—',
    
      // Extra UI strings
      'Manage preferences, data, and admin tools': 'Gérer les préférences, les données et les outils d\'administration',
      'Receive push notifications': 'Recevoir des notifications push',
      'Export all data to JSON file': 'Exporter toutes les données vers un fichier JSON',
      'Import data from JSON file': 'Importer des données depuis un fichier JSON',
      'Export members to CSV': 'Exporter les membres vers CSV',
      'Create login accounts for members and manage their access': 'Créer des comptes de connexion pour les membres et gérer leur accès',
      'Member Accounts': 'Comptes membres',
      'Sign out of your account': 'Se déconnecter de votre compte',
      'On': 'Activé',
      'Off': 'Désactivé',
      'Church Administration': 'Administration de l\'église',
      'Manage Tasks': 'Gérer les tâches',
      'Manage Projects': 'Gérer les projets',
      'Manage Tags': 'Gérer les étiquettes',
      'Create Task': 'Créer une tâche',
      'Quick actions': 'Actions rapides',
      'Service schedule': 'Planning des cultes',
      'Church attendance': 'Présence aux cultes',
      'Daily presence': 'Présence quotidienne',
      'View all': 'Voir tout',
      'Newcomers': 'Nouveaux venus',
      'Manage church members, roles, and profiles': 'Gérer les membres, rôles et profils de l\'église',
      'Organize teams, leaders, and ministry work': 'Organiser les équipes, les leaders et le travail ministériel',
      'Check for updates': 'Vérifier les mises à jour',
      'Download the latest release': 'Télécharger la dernière version',
      'You are on the latest version.': 'Vous utilisez la dernière version.',
      'Checking for updates...': 'Recherche de mises à jour...',
      'Downloading… {percent}%': 'Téléchargement… {percent} %',
      'Installing update...': 'Installation de la mise à jour...',
      'Open install settings': 'Ouvrir les paramètres d\'installation',
      'Allow installing apps from SysteMIC, then return to finish the update.':
          'Autorisez l\'installation d\'applications depuis SysteMIC, puis revenez pour terminer la mise à jour.',
      'Installer opened. Follow the prompts to finish.':
          'Programme d\'installation ouvert. Suivez les instructions pour terminer.',
      'Dismiss': 'Fermer',
      'Update available': 'Mise à jour disponible',
      'Update now': 'Mettre à jour',
      'Refresh now': 'Actualiser maintenant',
      'Later': 'Plus tard',
      'What\'s new': 'Nouveautés',
      'Downloading update...': 'Téléchargement de la mise à jour...',
      'Downloading update ({version})...':
          'Téléchargement de la mise à jour ({version})...',
      'Refreshing app...': 'Actualisation de l\'application...',
      'Update failed': 'Échec de la mise à jour',
      'Downloading...': 'Téléchargement...',
      'Refreshing...': 'Actualisation...',
      'Update {version}': 'Mise à jour {version}',
      'Update': 'Mettre à jour',
      'Preferences': 'Préférences',
      'Data & tools': 'Données et outils',
      'Choose how SysteMIC looks and speaks.': 'Choisissez l\'apparence et la langue de SysteMIC.',
      'Workspace tools': 'Outils de l\'espace de travail',
      'Export, import, sync, and reports': 'Exporter, importer, synchroniser et rapports',
      'Signed in as': 'Connecté en tant que',
      'Configure birthday notification settings': 'Configurer les notifications d\'anniversaire',
      'Create members for all users and users for all leaders': 'Créer des membres pour tous les utilisateurs et des utilisateurs pour tous les leaders',
      'Generate comprehensive report for all users': 'Générer un rapport complet pour tous les utilisateurs',
      'Define feature access for each leader': 'Définir l\'accès aux fonctionnalités pour chaque leader',
      'Select Theme': 'Sélectionner le thème',
      'No tasks in this department': 'Aucune tâche dans ce département',
      'You can only create tasks for departments you lead': 'Vous ne pouvez créer des tâches que pour les départements que vous dirigez',
      'A new version ({version}) is available.': 'Une nouvelle version ({version}) est disponible.',
      'Update failed: {error}': 'Échec de la mise à jour : {error}',
      'Weekly attendance': 'Présence hebdomadaire',
      'Language': 'Langue',
      'Light': 'Clair',
      'Dark': 'Sombre',
      'System Default': 'Par défaut du système',
      'Account': 'Compte',
      'App Version': 'Version de l\'application',
      'English': 'English',
      'Français': 'Français',
      'Español': 'Español',
      'No chart data': 'Aucune donnée de graphique',
      'Not logged in': 'Non connecté',
      'Theme': 'Thème',
      'Enable Notifications': 'Activer les notifications',
      'Birthday Notifications': 'Notifications d\'anniversaire',
      'Export All Data': 'Exporter toutes les données',
      'Import Data': 'Importer des données',
      'Export Members': 'Exporter les membres',
      'Sync Users & Members': 'Synchroniser utilisateurs et membres',
      'Generate All Users Report': 'Générer le rapport de tous les utilisateurs',
      'Leader Access Management': 'Gestion des accès leaders',
      'Logout': 'Déconnexion',
      'Settings': 'Paramètres',
      'Page {current} of {total}': 'Page {current} sur {total}',
      'Error loading services: {error}': 'Erreur lors du chargement des cultes : {error}',
      'Error deleting service: {error}': 'Erreur lors de la suppression du culte : {error}',
      'Error generating report: {error}': 'Erreur lors de la génération du rapport : {error}',
      'Report generated successfully: {path}': 'Rapport généré avec succès : {path}',
      '{count} member attended': '{count} membre présent',
      '{count} members attended': '{count} membres présents',
      ', {count} visitor': ', {count} visiteur',
      ', {count} visitors': ', {count} visiteurs',
      'Absent ({count})': 'Absents ({count})',
      'Absent PDF generated successfully: {path}': 'PDF des absents généré avec succès : {path}',
      'Absent people': 'Personnes absentes',
      'Absent people ({count})': 'Personnes absentes ({count})',
      'Adults': 'Adultes',
      'Adults attended': 'Adultes présents',
      'All ({count})': 'Tous ({count})',
      'Are you sure you want to remove this attendance record?': 'Voulez-vous vraiment supprimer cet enregistrement de présence ?',
      'Arrived late': 'Arrivé en retard',
      'Attendance removed successfully': 'Présence supprimée avec succès',
      'Attendance saved successfully': 'Présence enregistrée avec succès',
      'Attendance updated successfully': 'Présence mise à jour avec succès',
      'Attended in person': 'Présent en personne',
      'Attended virtually': 'Présent en ligne',
      'Attendees': 'Participants',
      'Away': 'Absent(e)',
      'Children': 'Enfants',
      'Children ({count})': 'Enfants ({count})',
      'Children attended': 'Enfants présents',
      'Could not load visitors: {error}': 'Impossible de charger les visiteurs : {error}',
      'Could not open WhatsApp. Make sure it is installed on this device.': 'Impossible d\'ouvrir WhatsApp. Vérifiez qu\'il est installé sur cet appareil.',
      'Edit Attendance': 'Modifier la présence',
      'Edit Attendance Type': 'Modifier le type de présence',
      'Edit Visitor Attendance': 'Modifier la présence du visiteur',
      'Edit attendance': 'Modifier la présence',
      'Email: {email}': 'E-mail : {email}',
      'Error adding visitor: {error}': 'Erreur lors de l\'ajout du visiteur : {error}',
      'Error generating absent PDF: {error}': 'Erreur lors de la génération du PDF des absents : {error}',
      'Error loading members: {error}': 'Erreur lors du chargement des membres : {error}',
      'Error removing attendance: {error}': 'Erreur lors de la suppression de la présence : {error}',
      'Error removing visitor: {error}': 'Erreur lors de la suppression du visiteur : {error}',
      'Error saving attendance: {error}': 'Erreur lors de l\'enregistrement de la présence : {error}',
      'Error saving observation: {error}': 'Erreur lors de l\'enregistrement de l\'observation : {error}',
      'Error updating attendance: {error}': 'Erreur lors de la mise à jour de la présence : {error}',
      'Error updating visitor: {error}': 'Erreur lors de la mise à jour du visiteur : {error}',
      'Export PDF': 'Exporter le PDF',
      'Export absent PDF': 'Exporter le PDF des absents',
      'Filter attendees': 'Filtrer les participants',
      'Filter:': 'Filtrer :',
      'First name *': 'Prénom *',
      'Last name *': 'Nom *',
      'Logged: {datetime}': 'Enregistré : {datetime}',
      'Members & Visitors': 'Membres et visiteurs',
      'New comer': 'Nouveau venu',
      'New comer children': 'Enfants nouveaux venus',
      'New comer children attended': 'Enfants nouveaux venus présents',
      'New comers': 'Nouveaux venus',
      'New comers attended': 'Nouveaux venus présents',
      'No absent people': 'Aucune personne absente',
      'No active members found': 'Aucun membre actif trouvé',
      'No attendance recorded for this service': 'Aucune présence enregistrée pour ce culte',
      'No results found': 'Aucun résultat',
      'Notes (optional)': 'Notes (facultatif)',
      'Observation removed': 'Observation supprimée',
      'Observation saved': 'Observation enregistrée',
      'Online ({count})': 'En ligne ({count})',
      'Online attendance': 'Présence en ligne',
      'Onsite ({count})': 'Sur place ({count})',
      'Onsite breakdown': 'Répartition sur place',
      'Open WhatsApp': 'Ouvrir WhatsApp',
      'Other visit date': 'Autre date de visite',
      'Phone (optional)': 'Téléphone (facultatif)',
      'Phone: {phone}': 'Téléphone : {phone}',
      'Quick add': 'Ajout rapide',
      'Remove Attendance': 'Supprimer la présence',
      'Remove Visitor': 'Supprimer le visiteur',
      'Remove attendance': 'Supprimer la présence',
      'Remove note': 'Supprimer la note',
      'Remove this visitor from today\'s visit log?': 'Retirer ce visiteur du journal de visite d\'aujourd\'hui ?',
      'Remove visitor': 'Supprimer le visiteur',
      'Save Attendance': 'Enregistrer la présence',
      'Save attendance before exporting PDF': 'Enregistrez la présence avant d\'exporter le PDF',
      'Save note': 'Enregistrer la note',
      'Search members and visitors...': 'Rechercher des membres et visiteurs...',
      'Search…': 'Rechercher…',
      'Select Service Date': 'Sélectionner la date du culte',
      'Service Date': 'Date du culte',
      'Service Details': 'Détails du culte',
      'Service note': 'Note du culte',
      'Sick': 'Malade',
      'Specific observation': 'Observation particulière',
      'Summary': 'Résumé',
      'Tap Edit to mark attendance or add visitors': 'Appuyez sur Modifier pour marquer les présences ou ajouter des visiteurs',
      'Total (excluding online)': 'Total (hors en ligne)',
      'Traveling': 'En voyage',
      'Try adjusting search or filters': 'Essayez de modifier la recherche ou les filtres',
      'Try adjusting your search': 'Essayez de modifier votre recherche',
      'Visitor added': 'Visiteur ajouté',
      'Visitor attendance updated': 'Présence du visiteur mise à jour',
      'Visitor removed': 'Visiteur retiré',
      'Visitors ({count})': 'Visiteurs ({count})',
      'Visitors attended': 'Visiteurs présents',
      'Was not present': 'N\'était pas présent',
      'Write a note for this service…': 'Écrire une note pour ce culte…',
      'onsite attendees': 'présents sur place',
      'Onsite attendees': 'Présents sur place',
      '{attended} attended, {absent} absent{visitors}': '{attended} présents, {absent} absents{visitors}',
      '{count} left': '{count} restants',
      'Account created': 'Compte créé',
      'Add email for member': 'Ajouter un e-mail pour le membre',
      'Save & create account': 'Enregistrer et créer le compte',
      'member@example.com': 'membre@exemple.com',
      'This member has no email. Enter one to create a login account.': 'Ce membre n\'a pas d\'e-mail. Saisissez-en un pour créer un compte.',
      '{name} has no email. Enter one to create a login account.': '{name} n\'a pas d\'e-mail. Saisissez-en un pour créer un compte.',
      'A login account was created for {name}.\n\nEmail: {email}\nDefault password: {password}\n\nThey must change their password on first login. An email with these credentials has been sent.': 'Un compte de connexion a été créé pour {name}.\n\nE-mail : {email}\nMot de passe par défaut : {password}\n\nIl devra changer son mot de passe à la première connexion. Un e-mail avec ces identifiants a été envoyé.',
      'Task assigned, but login was not created (no email).': 'Tâche assignée, mais le compte n\'a pas été créé (pas d\'e-mail).',
      'Task assigned, but login was not created: could not save email.': 'Tâche assignée, mais le compte n\'a pas été créé : impossible d\'enregistrer l\'e-mail.',
      'Task assigned, but login was not created: {error}': 'Tâche assignée, mais le compte n\'a pas été créé : {error}',
      'Could not create login account: member not found.': 'Impossible de créer le compte : membre introuvable.',
      'Please enter a valid email address.': 'Veuillez saisir une adresse e-mail valide.',
      'Email cannot be empty.': 'L\'e-mail ne peut pas être vide.',
},
    'es': {
      'Just now': 'Justo ahora',
      'Yesterday': 'Ayer',
      '{count}m ago': 'Hace {count} min',
      '{count}h ago': 'Hace {count} h',
      '{count}d ago': 'Hace {count} d',
      'Please enter event title': 'Introduzca el título del evento',
      'Training name is required': 'El nombre de la formación es obligatorio',
      'Add': 'Agregar',
      'All': 'Todos',
      'All tasks': 'Todas las tareas',
      'All members': 'Todos los miembros',
      'All Priorities': 'Todas las prioridades',
      'All projects': 'Todos los proyectos',
      'All Statuses': 'Todos los estados',
      'All tags': 'Todas las etiquetas',
      'Absent': 'Ausente',
      'Amount': 'Cantidad',
      'Back': 'Atrás',
      'Backoffice': 'Backoffice',
      'Archive': 'Archivar',
      'Archived': 'Archivado',
      'Assigned': 'Asignado',
      'Assigned members': 'Miembros asignados',
      'Assigned member': 'Miembro asignado',
      'Attendance Report': 'Informe de asistencia',
      'Attended': 'Asistencias',
      'Blocked from new task assignments':
          'Bloqueado para nuevas asignaciones de tareas',
      'Board': 'Tablero',
      'Cancel': 'Cancelar',
      'Cancelled': 'Cancelado',
      'Capture a teaching with its date, speaker, and notes.':
          'Registra una enseñanza con su fecha, orador y notas.',
      'Category': 'Categoría',
      'Charts': 'Gráficos',
      'Timeline': 'Cronología',
      'No scheduled tasks to display on the timeline.':
          'No hay tareas programadas para mostrar en la cronología.',
      'Zoom in': 'Acercar',
      'Zoom out': 'Alejar',
      'Fit to width': 'Ajustar al ancho',
      'Unassigned': 'Sin asignar',
      'No tag': 'Sin etiqueta',
      'Create tag': 'Crear etiqueta',
      'Could not update task: {error}':
          'No se pudo actualizar la tarea: {error}',
      'Could not update assignment: {error}':
          'No se pudo actualizar la asignación: {error}',
      'Could not update tags: {error}':
          'No se pudieron actualizar las etiquetas: {error}',
      'Avg. lateness': 'Retraso medio',
      'Workload': 'Carga',
      'Current department': 'Departamento actual',
      'Average lateness per member': 'Retraso medio por miembro',
      'Average days late on scheduled tasks with assignees':
          'Días medios de retraso en tareas programadas con asignados',
      'Department: {name}': 'Departamento: {name}',
      'Members tracked': 'Miembros seguidos',
      'Team average': 'Promedio del equipo',
      'Highest avg.': 'Retraso máx.',
      'Average days late': 'Días de retraso medios',
      'Lateness trend by member': 'Tendencia de retraso por miembro',
      'No lateness data for assigned tasks yet':
          'Sin datos de retraso para tareas asignadas',
      'Member workload': 'Carga por miembro',
      'Open task load weighted by priority (urgent counts more)':
          'Carga de tareas abiertas ponderada por prioridad (urgente cuenta más)',
      'Active members': 'Miembros activos',
      'Total load': 'Carga total',
      'Busiest': 'Más ocupado',
      'Workload share': 'Distribución de carga',
      'Open tasks by member': 'Tareas abiertas por miembro',
      'No active assignments to chart yet':
          'Sin asignaciones activas para mostrar',
      'Clear': 'Limpiar',
      'Clear filters': 'Limpiar filtros',
      'Close': 'Cerrar',
      'Completed': 'Completado',
      'Confirm': 'Confirmar',
      'Create': 'Crear',
      'Create a training and optionally link it to a department.':
          'Crea una formación y, opcionalmente, vincúlala a un departamento.',
      'Date': 'Fecha',
      'Delete': 'Eliminar',
      'Description': 'Descripción',
      'Details': 'Detalles',
      'Done': 'Hecho',
      'Drop tasks here': 'Suelta las tareas aquí',
      'Drag to another project': 'Arrastrar a otro proyecto',
      'Could not move task: {error}':
          'No se pudo mover la tarea: {error}',
      'View details': 'Ver detalles',
      'Delete task': 'Eliminar tarea',
      'Delete {count} tasks': 'Eliminar {count} tareas',
      'Delete task?': '¿Eliminar tarea?',
      'Are you sure you want to delete "{title}"? This action cannot be undone.':
          '¿Seguro que deseas eliminar "{title}"? Esta acción no se puede deshacer.',
      'Task deleted': 'Tarea eliminada',
      'Could not delete task: {error}':
          'No se pudo eliminar la tarea: {error}',
      'Delete {count} tasks?': '¿Eliminar {count} tareas?',
      'This will permanently delete {count} selected tasks. This action cannot be undone.':
          'Esto eliminará permanentemente {count} tareas seleccionadas. Esta acción no se puede deshacer.',
      'Delete all': 'Eliminar todo',
      '{count} tasks deleted': '{count} tareas eliminadas',
      'Could not delete tasks: {error}':
          'No se pudieron eliminar las tareas: {error}',
      '{count} selected': '{count} seleccionada(s)',
      'Due date': 'Fecha límite',
      'Edit': 'Editar',
      'Email': 'Correo electrónico',
      'End date': 'Fecha de fin',
      'Enter a valid amount': 'Ingresa una cantidad válida',
      'Error': 'Error',
      'Error loading tasks: {error}': 'Error al cargar las tareas: {error}',
      'Error recording payment: {error}': 'Error al registrar el pago: {error}',
      'Error sending reminders: {error}':
          'Error al enviar recordatorios: {error}',
      'Export': 'Exportar',
      'Failed to generate PDF report: {error}':
          'Error al generar el informe PDF: {error}',
      'Filter': 'Filtrar',
      'Filter Tasks': 'Filtrar tareas',
      'Filters': 'Filtros',
      'Filters on': 'Filtros activos',
      'Generate PDF Report': 'Generar informe PDF',
      'High': 'Alta',
      'In progress': 'En progreso',
      'Import': 'Importar',
      'Intention': 'Intención',
      'Joined': 'Llegó',
      'Last attended': 'Última asistencia',
      'Loading...': 'Cargando...',
      'Low': 'Baja',
      'Manage projects': 'Gestionar proyectos',
      'Manage tags': 'Gestionar etiquetas',
      'Medium': 'Media',
      'More': 'Más',
      'Name': 'Nombre',
      'New Comers': 'Nuevos visitantes',
      'New Comers Report': 'Informe de nuevos visitantes',
      'Newcomer Attendance': 'Asistencia de nuevos visitantes',
      'Newcomer Stats': 'Estadísticas de nuevos visitantes',
      'No data': 'Sin datos',
      'No data yet': 'Aún no hay datos',
      'No newcomer attendance found for this period.':
          'No se encontró asistencia de nuevos visitantes para este período.',
      'No newcomer records found for this period.':
          'No se encontraron registros de nuevos visitantes para este período.',
      'No project': 'Sin proyecto',
      'No tasks found': 'No se encontraron tareas',
      'No tasks match this view': 'Ninguna tarea coincide con esta vista',
      'No tasks yet': 'Aún no hay tareas',
      'No unpaid penalties': 'No hay penalizaciones pendientes',
      'Note (optional)': 'Nota (opcional)',
      'Notes': 'Notas',
      'Online': 'En línea',
      'Open': 'Abrir',
      'Open tasks': 'Tareas abiertas',
      'Onsite': 'Presencial',
      'Overdue': 'Atrasadas',
      'PDF report generated: {path}': 'Informe PDF generado: {path}',
      'Pending': 'Pendiente',
      'Penalties': 'Penalizaciones',
      'Penalty balance pending': 'Saldo de penalización pendiente',
      'Priority': 'Prioridad',
      'Project': 'Proyecto',
      'Project workload': 'Carga por proyecto',
      'Projects': 'Proyectos',
      'Record': 'Registrar',
      'Record payment': 'Registrar pago',
      'Record payment for {name}': 'Registrar pago para {name}',
      'Refresh': 'Actualizar',
      'Reminder': 'Recordatorio',
      'Reminder sent for {count} task assignment(s)':
          'Recordatorio enviado para {count} asignación(es) de tarea',
      'Save': 'Guardar',
      'Search': 'Buscar',
      'Search tasks, projects, assignees...':
          'Buscar tareas, proyectos, asignados...',
      'Search tasks...': 'Buscar tareas...',
      'Send general reminder': 'Enviar recordatorio general',
      'Send general task reminder?': '¿Enviar recordatorio general de tareas?',
      'Send reminder': 'Enviar recordatorio',
      'Select end date': 'Seleccionar fecha de fin',
      'Select start date': 'Seleccionar fecha de inicio',
      'Services': 'Cultos',
      'Start date': 'Fecha de inicio',
      'Status': 'Estado',
      'Success': 'Éxito',
      'Tags': 'Etiquetas',
      'Task': 'Tarea',
      'Tasks': 'Tareas',
      'Tasks workspace': 'Espacio de tareas',
      'This will notify all members who currently have pending or in-progress tasks.':
          'Esto notificará a todos los miembros que actualmente tienen tareas pendientes o en progreso.',
      'Title': 'Título',
      'Training details': 'Detalles de la formación',
      'Try another filter or create a new task.':
          'Prueba otro filtro o crea una nueva tarea.',
      'Unknown': 'Desconocido',
      'Update the teaching details without leaving the current workspace.':
          'Actualiza los detalles de la enseñanza sin salir del espacio de trabajo actual.',
      'Update the training details without leaving the current workspace.':
          'Actualiza los detalles de la formación sin salir del espacio de trabajo actual.',
      'Unnamed member': 'Miembro sin nombre',
      'Untitled project': 'Proyecto sin título',
      'Untitled task': 'Tarea sin título',
      'Urgent': 'Urgente',
      'View': 'Ver',
      'Visible tasks': 'Tareas visibles',
      'attendances': 'asistencias',
      'records': 'registros',
      'saved': 'guardado',
      '{completed}/{total} done': '{completed}/{total} completadas',
      '{visible} visible of {total} tasks':
          '{visible} visibles de {total} tareas',
      '+{count} more tasks': '+{count} tareas más',

      '(Optional)': '(Opcional)',
      'Actions': 'Acciones',
      'Active': 'Activo',
      'Activity Logs': 'Registros de actividad',
      'Add Department': 'Agregar departamento',
      'Add First Record': 'Agregar primer registro',
      'Add Giving Record': 'Agregar registro de ofrenda',
      'Add Listener': 'Agregar oyente',
      'Add Member': 'Agregar miembro',
      'Add Members': 'Agregar miembros',
      'Add Members to Training': 'Agregar miembros a la formación',
      'Add Task': 'Agregar tarea',
      'Add Visitor': 'Agregar visitante',
      'Add skill': 'Agregar habilidad',
      'Add task': 'Agregar tarea',
      'Add {count}': 'Agregar {count}',
      'Additional comments or notes (optional)': 'Comentarios o notas adicionales (opcional)',
      'Address': 'Dirección',
      'Admin': 'Administrador',
      'Admin Panel': 'Panel de administración',
      'All church services': 'Todos los servicios de la iglesia',
      'Search by date...': 'Buscar por fecha...',
      'Search results': 'Resultados de búsqueda',
      'No matching services': 'No hay cultos coincidentes',
      'Try another date or clear the search': 'Prueba otra fecha o borra la búsqueda',
      'Clear search': 'Borrar búsqueda',
      'All members are already enrolled in this class': 'Todos los miembros ya están inscritos en esta clase',
      'All potential listeners are already added': 'Todos los oyentes potenciales ya están agregados',
      'Announcement created successfully': 'Anuncio creado correctamente',
      'Choose a conversation to start messaging':
          'Elige una conversación para empezar',
      'Church-wide messages': 'Mensajes para toda la iglesia',
      'Department chat': 'Chat del departamento',
      'Direct messages': 'Mensajes directos',
      'Everyone': 'Todos',
      'Messages sent to specific members':
          'Mensajes enviados a miembros específicos',
      'No conversations found': 'No se encontraron conversaciones',
      'No messages yet': 'Aún no hay mensajes',
      'Search conversations...': 'Buscar conversaciones...',
      'Select a conversation': 'Selecciona una conversación',
      'Select recipients': 'Seleccionar destinatarios',
      'Send': 'Enviar',
      'Send the first message': 'Envía el primer mensaje',
      'Today': 'Hoy',
      'Type a message...': 'Escribe un mensaje...',
      'You': 'Tú',
      'Video call': 'Videollamada',
      'Join video call': 'Unirse a la videollamada',
      'Start video call': 'Iniciar videollamada',
      'Video call in progress': 'Videollamada en curso',
      'Open in browser': 'Abrir en el navegador',
      'Could not start video call': 'No se pudo iniciar la videollamada',
      'A video call started in {channel}. Tap Join video call to join.':
          'Se inició una videollamada en {channel}. Toca Unirse a la videollamada.',
      'Apply': 'Aplicar',
      'Are you sure you want to delete "{title}"?': '¿Está seguro de que desea eliminar « {title} »?',
      'Are you sure you want to delete this class? This will deactivate it.': '¿Está seguro de que desea eliminar esta formación? Se desactivará.',
      'Are you sure you want to delete this event?': '¿Está seguro de que desea eliminar este evento?',
      'Are you sure you want to delete this event? This will deactivate it.': '¿Está seguro de que desea eliminar este evento? Se desactivará.',
      'Are you sure you want to delete this session?': '¿Está seguro de que desea eliminar esta sesión?',
      'Are you sure you want to remove this member from the class?': '¿Está seguro de que desea quitar a este miembro de la formación?',
      'Are you sure you want to remove this registration?': '¿Está seguro de que desea eliminar este registro?',
      'Assign roles to users': 'Asignar roles a usuarios',
      'Assignee filter': 'Filtro por asignado',
      'At least email or phone is required': 'Se requiere al menos un correo electrónico o un teléfono',
      'Attendance': 'Asistencia',
      'Attendance Details': 'Detalles de asistencia',
      'Attendance Records': 'Registro de presencia',
      'Attendance Trend': 'Tendencia de asistencia',
      'Attendance is tracked per session': 'La asistencia se registra por sesión',
      'Attendance tracking coming soon': 'Seguimiento de asistencia próximamente',
      'Avg attendance': 'Asistencia promedio',
      'Back to Login': 'Volver al inicio de sesión',
      'Basic information': 'Información básica',
      'Birthday': 'Fecha de nacimiento',
      'Birthday *': 'Fecha de nacimiento *',
      'Birthday is required': 'La fecha de nacimiento es obligatoria',
      'Change Password': 'Cambiar contraseña',
      'Change Password Required': 'Cambio de contraseña requerido',
      'Check if this is a new comer. Status will automatically change to member after 9+ service attendances in 3 months.': 'Marque si es recién llegado. El estado cambiará automáticamente a miembro tras 9+ asistencias a cultos en 3 meses.',
      'Choose from gallery': 'Elegir de la galería',
      'Church Attendance': 'Asistencia a la iglesia',
      'Church service': 'Servicio de la iglesia',
      'City': 'Ciudad',
      'Clear All': 'Borrar todo',
      'Comments': 'Comentarios',
      'Confirm New Password': 'Confirmar nueva contraseña',
      'Confirm Password': 'Confirmar contraseña',
      'Contact': 'Contacto',
      'Convert to Member': 'Convertir a miembro',
      'Convert visitor to member': 'Convertir visitante a miembro',
      'Could not create task': 'No se pudo crear la tarea',
      'Could not move task': 'No se pudo mover la tarea',
      'Could not pick photo: \$e': 'No se pudo seleccionar la foto: \\\$e',
      'Could not update assignment': 'No se pudo actualizar la asignación',
      'Could not update tags': 'No se pudieron actualizar las etiquetas',
      'Could not update task': 'No se pudo actualizar la tarea',
      'Could not update task status': 'No se pudo actualizar el estado de la tarea',
      'Country': 'País',
      'Create Announcement': 'Crear anuncio',
      'Create Department': 'Crear departamento',
      'Create Member': 'Crear miembro',
      'Create Report': 'Crear informe',
      'Create Report - {name}': 'Crear informe - {name}',
      'Create User': 'Crear usuario',
      'Create a department and attach reference documents': 'Crear un departamento y adjuntar documentos de referencia',
      'Create a member profile for "{name}" using the visitor\'s contact details. The visitor record will be removed.': 'Crear un perfil de miembro para « {name} » con los datos del visitante. Se eliminará el registro del visitante.',
      'Create a new church member profile': 'Crear un nuevo perfil de miembro de la iglesia',
      'Create admin, pastor, or admin users': 'Crear usuarios admin, pastor o admin',
      'Create your first report to get started': 'Cree su primer informe para comenzar',
      'Created {date}': 'Creado el {date}',
      'Date TBD': 'Fecha por confirmar',
      'Day': 'Día',
      'Defined Objectives *': 'Objetivos definidos *',
      'Defined objectives are required': 'Los objetivos definidos son obligatorios',
      'Delete Class': 'Eliminar clase',
      'Delete Event': 'Eliminar evento',
      'Delete Report': 'Eliminar informe',
      'Delete Session': 'Eliminar sesión',
      'Delete service attendance?': '¿Eliminar la asistencia al servicio?',
      'Department': 'Departamento',
      'Department (Optional)': 'Departamento (opcional)',
      'Department Name *': 'Nombre del departamento *',
      'Department name is required': 'El nombre del departamento es obligatorio',
      'Department updated successfully': 'Departamento actualizado correctamente',
      'Describe any difficulties or challenges faced': 'Describa las dificultades o desafíos enfrentados',
      'Deselect All': 'Deseleccionar todo',
      'Difficulties Encountered *': 'Dificultades encontradas *',
      'Difficulties encountered are required': 'Las dificultades encontradas son obligatorias',
      'Disable birthday notifications for this member': 'Desactivar notificaciones de cumpleaños para este miembro',
      'Divorced': 'Divorciado/a',
      'Document Upload Errors': 'Errores al subir documentos',
      'Documents (Optional)': 'Documentos (opcional)',
      'Does not know yet': 'Aún no lo sabe',
      'Domain of Activity': 'Ámbito de actividad',
      'Domain of Activity *': 'Ámbito de actividad *',
      'Domain of activity is required': 'El dominio de actividad es obligatorio',
      'Edit Department': 'Editar departamento',
      'Edit Event': 'Editar evento',
      'Edit Member': 'Editar miembro',
      'Edit Record': 'Editar registro',
      'Edit Report': 'Editar informe',
      'Edit Training': 'Editar formación',
      'Email (Optional)': 'Correo electrónico (opcional)',
      'Email (recommended)': 'Correo electrónico (recomendado)',
      'Email Sent!': '¡Correo enviado!',
      'Email is required': 'El correo electrónico es obligatorio',
      'Email: \$guestEmail': 'Correo electrónico: \\\$guestEmail',
      'End Date': 'Fecha de fin',
      'Enter Reset Token': 'Ingresar token de restablecimiento',
      'Enter a descriptive title for this report': 'Introduzca un título descriptivo para este informe',
      'Enter a skill': 'Introduzca una habilidad',
      'Enter custom number of sessions': 'Introduzca el número personalizado de sesiones',
      'Enter number of sessions to generate': 'Introduzca el número de sesiones a generar',
      'Enter the email address you used to request password reset': 'Ingrese el correo utilizado para solicitar el restablecimiento',
      'Enter the name of the department': 'Introduzca el nombre del departamento',
      'Enter the token from your email and your new password.': 'Ingrese el token de su correo y su nueva contraseña.',
      'Enter the token you received in your email': 'Ingrese el token recibido en su correo',
      'Enter your email address and we\'ll send you a token to reset your password.': 'Ingrese su correo y le enviaremos un token para restablecer su contraseña.',
      'Error adding listener: {error}': 'Error al agregar oyente: {error}',
      'Error adding members: \$e': 'Error al agregar miembros: \\\$e',
      'Error converting visitor to member: \$e': 'Error al convertir visitante a miembro: \$e',
      'Error creating announcement: \$e': 'Error al crear el anuncio: \\\$e',
      'Error creating report: \${e.toString()}': 'Error al crear el informe: \\\${e.toString()}',
      'Error deleting class: \$e': 'Error al eliminar la clase: \\\$e',
      'Error deleting event: \$e': 'Error al eliminar el evento: \\\$e',
      'Error deleting report: \$e': 'Error al eliminar el informe: \\\$e',
            'Error deleting session: {error}': 'Error al eliminar sesión: {error}',
      'Error deleting teaching: {error}': 'Error al eliminar enseñanza: {error}',
      'Error deleting visitor: \$e': 'Error al eliminar visitante: \$e',
            'Error generating sessions: \$e': 'Error al generar las sesiones: \\\$e',
      'Error loading data: \$e': 'Error al cargar los datos: \\\$e',
      'Error loading department: \$e': 'Error al cargar el departamento: \\\$e',
      'Error loading event: \$e': 'Error al cargar el evento: \\\$e',
      'Error loading giving records': 'Error al cargar registros de ofrendas',
      'Error loading listeners: {error}': 'Error al cargar oyentes: {error}',
      'Error loading member: \$e': 'Error al cargar el miembro: \\\$e',
      'Error loading members': 'Error al cargar los miembros',
      'Error loading members: \$e': 'Error al cargar los miembros: \\\$e',
      'Error loading registrations: \$e': 'Error al cargar las inscripciones: \\\$e',
      'Error loading report: \$e': 'Error al cargar el informe: \\\$e',
            'Error loading sessions: \$e': 'Error al cargar las sesiones: \\\$e',
      'Error loading tasks': 'Error al cargar las tareas',
      'Error loading teaching: {error}': 'Error al cargar enseñanza: {error}',
      'Error loading training: \$e': 'Error al cargar la formación: \\\$e',
      'Error loading visitors: \$e': 'Error al cargar visitantes: \$e',
      'Error picking file: \$e': 'Error al seleccionar el archivo: \\\$e',
      'Error recording payment': 'Error al registrar el pago',
      'Error registering guest: \$e': 'Error al registrar al invitado: \\\$e',
      'Error registering members: \$e': 'Error al registrar a los miembros: \\\$e',
      'Error removing listener: {error}': 'Error al eliminar oyente: {error}',
      'Error removing member: \$e': 'Error al eliminar al miembro: \\\$e',
      'Error removing registration: \$e': 'Error al eliminar el registro: \\\$e',
      'Error saving report': 'Error al guardar el informe',
      'Error sending reminders': 'Error al enviar los recordatorios',
      'Error syncing: {error}': 'Error de sincronización: {error}',
      'Error updating report: \${e.toString()}': 'Error al actualizar el informe: \\\${e.toString()}',
      'Error: \$e': 'Error: \\\$e',
      'Event': 'Evento',
      'Event Sessions': 'Sesiones del evento',
      'Event deleted successfully': 'Evento eliminado correctamente',
      'Event information': 'Información del evento',
      'Event not found': 'Evento no encontrado',
      'Export failed: \$e': 'Error al exportar: \\\$e',
      'Export to CSV': 'Exportar a CSV',
      'Failed to change password': 'Error al cambiar la contraseña',
      'Failed to get department: \$e': 'No se pudo obtener el departamento: \\\$e',
      'Female': 'Femenino',
      'Filter Services': 'Filtrar servicios',
      'Filtered church services': 'Servicios de la iglesia filtrados',
      'Finance': 'Finanzas',
      'First Name': 'Nombre',
      'First Name *': 'Nombre *',
      'First name is required': 'El nombre es obligatorio',
      'Forgot Password': 'Olvidé mi contraseña',
      'From': 'Desde',
      'Full Name *': 'Nombre completo *',
      'Gender': 'Género',
      'Generate': 'Generar',
      'Generate 4': 'Generar 4',
      'Generate Church Attendance Report': 'Generar informe de asistencia a la iglesia',
      'Generate Next Sessions': 'Generar próximas sesiones',
      'Generate PDF': 'Generar PDF',
      'Generate Report': 'Generar informe',
      'Generate Sessions': 'Generar sesiones',
      'Generate Summary Report': 'Generar informe resumido',
      'Generated \$numberOfSessions sessions': 'Se generaron \\\$numberOfSessions sesiones',
      'Generating PDF report...': 'Generando informe PDF...',
      'Generating PDF...': 'Generando PDF...',
      'Generating summary report...': 'Generando informe resumido...',
      'Giver': 'Donante',
      'Global Announcement': 'Anuncio global',
      'Go to Login': 'Ir al inicio de sesión',
      'Guest': 'Invitado',
      'How many sessions would you like to generate?': '¿Cuántas sesiones desea generar?',
      'How many weeks between each session': 'Cuántas semanas hay entre cada sesión',
      'Inactive': 'Inactivo',
      'Invalid email format': 'Formato de correo electrónico no válido',
      'Is this member active?': '¿Este miembro está activo?',
      'Just passing': 'Solo de paso',
      'Key Skills': 'Habilidades clave',
      'Last Diplomas': 'Últimos diplomas',
      'Last Name': 'Apellido',
      'Last Name *': 'Apellido *',
      'Last name is required': 'El apellido es obligatorio',
      'Leader': 'Líder',
      'Level of Study': 'Nivel de estudios',
      'List positive achievements or points': 'Enumere los logros o puntos positivos',
      'List the objectives that were defined': 'Enumere los objetivos que se definieron',
      'Listener added successfully': 'Oyente agregado correctamente',
      'Listener removed successfully': 'Oyente eliminado correctamente',
      'Listeners': 'Oyentes',
      'Male': 'Masculino',
      'Marital Status': 'Estado civil',
      'Mark Attendance': 'Registrar asistencia',
      'Mark New Attendance': 'Registrar nueva asistencia',
      'Mark attendance for a new church service': 'Registrar la asistencia de un nuevo culto',
      'Married': 'Casado/a',
      'Member': 'Miembro',
      'Member Report': 'Informe de miembro',
      'Member added successfully': 'Miembro agregado correctamente',
      'Member created successfully': 'Miembro creado correctamente',
      'Member must have at least email or phone for password reset capability. Email is strongly recommended.': 'El miembro debe tener al menos correo o teléfono para restablecer la contraseña. Se recomienda el correo.',
      'Member removed successfully': 'Miembro eliminado correctamente',
      'Member updated successfully': 'Miembro actualizado correctamente',
      'Members': 'Miembros',
      'Message *': 'Mensaje *',
      'N/A': 'N/D',
      'New Comer': 'Nuevo visitante',
      'New Password': 'Nueva contraseña',
      'New password is required': 'La nueva contraseña es obligatoria',
      'Newcomer': 'Nuevo visitante',
      'Newcomer Intention': 'Intención del nuevo visitante',
      'Newcomer Join Date': 'Fecha de ingreso del nuevo visitante',
      'No Department': 'Sin departamento',
      'No attendance records found': 'No se encontraron registros de asistencia',
      'No date selected': 'Ninguna fecha seleccionada',
      'No giving records yet': 'Aún no hay registros de ofrendas',
      'No listeners yet': 'Aún no hay oyentes',
      'No members enrolled': 'Ningún miembro inscrito',
      'No members found in this department': 'No se encontraron miembros en este departamento',
      'No registrations yet': 'Aún no hay registros',
      'No reports yet': 'Aún no hay informes',
      'No services found': 'No se encontraron servicios',
      'No sessions generated yet': 'Aún no se han generado sesiones',
      'No sessions yet': 'Aún no hay sesiones',
      'No visitors found matching your search': 'No se encontraron visitantes que coincidan con su búsqueda',
      'No visitors yet': 'Aún no hay visitantes',
      'Not set': 'No establecido',
      'Not specified': 'No especificado',
      'Number of Sessions': 'Número de sesiones',
      'OK': 'OK',
      'Opt out of birthday notifications': 'Optar por no recibir notificaciones de cumpleaños',
      'Optional description for the department': 'Descripción opcional del departamento',
      'Other': 'Otro',
      'Overview': 'Resumen',
      'PDF generated successfully': 'PDF generado correctamente',
      'PDF report saved successfully': 'Informe PDF guardado correctamente',
            'Password': 'Contraseña',
      'Password Reset': 'Restablecimiento de contraseña',
      'Password Reset Successful!': '¡Restablecimiento de contraseña exitoso!',
      'Password changed successfully': 'Contraseña cambiada correctamente',
      'Password is required': 'La contraseña es obligatoria',
      'Password must be at least 6 characters': 'La contraseña debe tener al menos 6 caracteres',
      'Passwords do not match': 'Las contraseñas no coinciden',
      'Pastor': 'Pastor',
      'Payment recorded': 'Pago registrado',
      'Personal information': 'Información personal',
      'Phone': 'Teléfono',
      'Phone (Optional)': 'Teléfono (opcional)',
      'Phone: \$guestPhone': 'Teléfono: \\\$guestPhone',
      'Please check your email for the password reset token. You\'ll need to enter it on the next screen.': 'Revise su correo para el token de restablecimiento. Deberá ingresarlo en la siguiente pantalla.',
      'Please confirm your password': 'Confirme su contraseña',
      'Please enter announcement message': 'Ingrese el mensaje del anuncio',
      'Please enter announcement title': 'Ingrese el título del anuncio',
      'Please enter first name': 'Introduzca el nombre',
      'Please enter guest name': 'Ingrese el nombre del invitado',
      'Please enter last name': 'Introduzca el apellido',
      'Please select at least one member for targeted announcement': 'Seleccione al menos un miembro para un anuncio dirigido',
      'Positive Points *': 'Puntos positivos *',
      'Positive points are required': 'Los puntos positivos son obligatorios',
      'Profession': 'Profesión',
      'Professional details': 'Detalles profesionales',
      'Profile photo (optional)': 'Foto de perfil (opcional)',
      'Provide suggestions for improvement': 'Proporcione sugerencias de mejora',
      'Quarter': 'Trimestre',
      'Record someone who visited the church': 'Registrar a alguien que visitó la iglesia',
      'Recorded: {datetime}': 'Registrado: {datetime}',
      'Register': 'Registrar',
      'Register Guest': 'Registrar invitado',
      'Register Members': 'Registrar miembros',
      'Register for Event': 'Inscribirse al evento',
      'Registering...': 'Inscribiendo...',
      'Registration failed: \$e': 'Error en el registro: \\\$e',
      'Registration removed successfully': 'Registro eliminado correctamente',
      'Registrations': 'Inscripciones',
      'Remove': 'Eliminar',
      'Remove "{name}" from listeners?': '¿Eliminar a « {name} » de los oyentes?',
      'Remove Listener': 'Eliminar oyente',
      'Remove Member': 'Eliminar miembro',
      'Remove Registration': 'Eliminar registro',
      'Remove from training': 'Eliminar de la formación',
      'Remove photo': 'Eliminar foto',
      'Repeated Event': 'Evento recurrente',
      'Report': 'Informe',
      'Report Title *': 'Título del informe *',
      'Report created successfully': 'Informe creado correctamente',
      'Report deleted successfully': 'Informe eliminado correctamente',
      'Report exported successfully': 'Informe exportado correctamente',
            'Report updated successfully': 'Informe actualizado correctamente',
      'Required': 'Obligatorio',
      'Required for job seeking and workers': 'Requerido para quienes buscan empleo y trabajadores',
      'Reset Password': 'Restablecer contraseña',
      'Reset Token': 'Token de restablecimiento',
      'Role': 'Rol',
      'Role & status': 'Rol y estado',
      'Role *': 'Rol *',
      'Role Assignment': 'Asignación de roles',
      'Role is required': 'El rol es obligatorio',
      'Search members...': 'Buscar miembros...',
      'Search potential listeners...': 'Buscar oyentes potenciales...',
      'Search visitors...': 'Buscar visitantes...',
      'Sector of Studies': 'Sector de estudios',
      'Select': 'Seleccionar',
      'Select All': 'Seleccionar todo',
      'Select Birthday': 'Seleccionar cumpleaños',
      'Select Date Range': 'Seleccionar rango de fechas',
      'Select Date Range for Report': 'Seleccionar rango de fechas del informe',
      'Select End Date': 'Seleccionar fecha de fin',
      'Select Join Date': 'Seleccionar fecha de ingreso',
      'Select Members': 'Seleccionar miembros',
      'Select Start Date': 'Seleccionar fecha de inicio',
      'Select birthday': 'Seleccionar cumpleaños',
      'Select date range for report': 'Seleccionar rango de fechas para el informe',
      'Select join date': 'Seleccionar fecha de ingreso',
      'Select member role': 'Seleccionar rol del miembro',
      'Select members to add:': 'Seleccionar miembros para agregar:',
      'Select the date when the newcomer joined': 'Seleccione la fecha de ingreso del recién llegado',
      'Select the newcomer\'s intention': 'Seleccionar la intención del nuevo visitante',
      'Select your current profession/status': 'Seleccionar su profesión/estado actual',
      'Selecting "Just passing" creates a Visitor, not a Member.': 'Seleccionar « De paso » crea un visitante, no un miembro.',
      'Send Reset Link': 'Enviar enlace de restablecimiento',
      'Send to all members. If disabled, select specific members.': 'Enviar a todos los miembros. Si está desactivado, seleccione miembros específicos.',
      'Service': 'Servicio',
      'Service attendance deleted': 'Asistencia al servicio eliminada',
      'Service name': 'Nombre del servicio',
      'Session {number}': 'Sesión {number}',
      'Sessions': 'Sesiones',
      'Sessions generated successfully': 'Sesiones generadas correctamente',
      'Set New Password': 'Establecer nueva contraseña',
      'Showing': 'Mostrando',
      'Single': 'Soltero/a',
      'Sort': 'Ordenar',
      'Sort ascending': 'Orden ascendente',
      'Sort descending': 'Orden descendente',
      'Speaker': 'Orador',
      'Start Date': 'Fecha de inicio',
      'State': 'Estado/Provincia',
      'Status will change to member after 9+ service attendances in 3 months.': 'El estado cambiará a miembro tras 9+ asistencias a cultos en 3 meses.',
      'Successfully registered for event': 'Inscripción al evento exitosa',
      'Successfully registered guest': 'Invitado registrado correctamente',
      'Successfully registered {count} member(s)': '{count} miembro(s) registrado(s) correctamente',
      'Successfully unregistered from event': 'Cancelación de inscripción exitosa',
      'Suggestions *': 'Sugerencias *',
      'Suggestions are required': 'Las sugerencias son obligatorias',
      'Summary report generated successfully': 'Informe resumido generado correctamente',
      'Sympathiser': 'Simpatizante',
      'Sync from Church Attendance': 'Sincronizar desde asistencia a cultos',
      'Synced {count} listener(s) from church attendance': '{count} oyente(s) sincronizado(s) desde asistencia a cultos',
      'Tag': 'Etiqueta',
      'Tag filter': 'Filtro por etiqueta',
      'Take a photo': 'Tomar una foto',
      'Tap to select date': 'Toque para seleccionar la fecha',
      'Task has no department; cannot add tags': 'La tarea no tiene departamento; no se pueden agregar etiquetas',
      'Task must be assigned to a department first': 'La tarea debe asignarse primero a un departamento',
      'Task title': 'Título de la tarea',
      'Task title is required': 'El título de la tarea es obligatorio',
      'Teaching': 'Enseñanza',
      'Teaching Details': 'Detalles de la enseñanza',
      'This month': 'Este mes',
      'This will permanently remove all attendance records for {label}, including visitors logged for that service.': 'Esto eliminará permanentemente todos los registros de asistencia de {label}, incluidos los visitantes registrados para ese culto.',
      'Title *': 'Título *',
      'Title is required': 'El título es obligatorio',
      'To': 'Hasta',
      'Token is required': 'El token es obligatorio',
      'Total': 'Total',
      'Total Giving': 'Total de ofrendas',
      'Track and follow up with church visitors': 'Hacer seguimiento de los visitantes de la iglesia',
      'Track church service attendance': 'Registrar la asistencia a los servicios de la iglesia',
      'Training': 'Formación',
      'Training deleted successfully': 'Formación eliminada correctamente',
      'Training not found': 'Formación no encontrada',
      'Type': 'Tipo',
      'Unnamed': 'Sin nombre',
      'Unnamed Visitor': 'Visitante sin nombre',
      'Unregister': 'Cancelar inscripción',
      'Untitled Report': 'Informe sin título',
      'Untitled Teaching': 'Enseñanza sin título',
      'Update Department': 'Actualizar departamento',
      'Update Member': 'Actualizar miembro',
      'Update Report': 'Actualizar informe',
      'Update department details and documents': 'Actualizar detalles y documentos del departamento',
      'Update member profile and details': 'Actualizar perfil y detalles del miembro',
      'Upload': 'Subir',
      'Use "Sync from Church Attendance" or "Add" to add listeners': 'Use « Sincronizar desde asistencia a cultos » o « Agregar » para añadir oyentes',
      'User created successfully': 'Usuario creado correctamente',
      'View system activity logs': 'Ver registros de actividad del sistema',
      'Visit Date': 'Fecha de visita',
      'Visit date is required': 'La fecha de visita es obligatoria',
      'Visit details': 'Detalles de la visita',
      'Visitor': 'Visitante',
      'Visitor added successfully': 'Visitante agregado correctamente',
      'Visitor converted to member successfully': 'Visitante convertido a miembro correctamente',
      'Visitor created successfully': 'Visitante creado correctamente',
      'Visitor deleted successfully': 'Visitante eliminado correctamente',
      'Visitors': 'Visitantes',
      'Wants to stay': 'Desea quedarse',
      'Weeks': 'Semanas',
      'Weeks between sessions:': 'Semanas entre sesiones:',
      'Widowed': 'Viudo/a',
      'Worker': 'Trabajador',
      'You can now sign in with your new password.': 'Ahora puede iniciar sesión con su nueva contraseña.',
      'You must change your password before continuing.': 'Debe cambiar su contraseña antes de continuar.',
      'Your password has been successfully reset. You can now log in with your new password.': 'Su contraseña se restableció correctamente. Ahora puede iniciar sesión con su nueva contraseña.',
      'Zip Code': 'Código postal',
      'attended': 'asistió',
      'e.g., 20': 'p. ej., 20',
      'member': 'miembro',
      '{count} member(s) selected': '{count} miembro(s) seleccionado(s)',
      '{name} Reports': 'Informes {name}',
      '—': '—',
    
      // Extra UI strings
      'Manage preferences, data, and admin tools': 'Administrar preferencias, datos y herramientas de administración',
      'Receive push notifications': 'Recibir notificaciones push',
      'Export all data to JSON file': 'Exportar todos los datos a un archivo JSON',
      'Import data from JSON file': 'Importar datos desde un archivo JSON',
      'Export members to CSV': 'Exportar miembros a CSV',
      'Create login accounts for members and manage their access': 'Crear cuentas de acceso para miembros y gestionar su acceso',
      'Member Accounts': 'Cuentas de miembros',
      'Sign out of your account': 'Cerrar sesión de su cuenta',
      'On': 'Activado',
      'Off': 'Desactivado',
      'Church Administration': 'Administración de la iglesia',
      'Manage Tasks': 'Gestionar tareas',
      'Manage Projects': 'Gestionar proyectos',
      'Manage Tags': 'Gestionar etiquetas',
      'Create Task': 'Crear tarea',
      'Quick actions': 'Acciones rápidas',
      'Service schedule': 'Horario de cultes',
      'Church attendance': 'Asistencia a cultos',
      'Daily presence': 'Presencia diaria',
      'View all': 'Ver todo',
      'Newcomers': 'Recién llegados',
      'Manage church members, roles, and profiles': 'Gestionar miembros, roles y perfiles de la iglesia',
      'Organize teams, leaders, and ministry work': 'Organizar equipos, líderes y trabajo ministerial',
      'Check for updates': 'Buscar actualizaciones',
      'Download the latest release': 'Descargar la última versión',
      'You are on the latest version.': 'Está en la última versión.',
      'Checking for updates...': 'Buscando actualizaciones...',
      'Downloading… {percent}%': 'Descargando… {percent} %',
      'Installing update...': 'Instalando actualización...',
      'Open install settings': 'Abrir ajustes de instalación',
      'Allow installing apps from SysteMIC, then return to finish the update.':
          'Permita instalar aplicaciones desde SysteMIC y vuelva para terminar la actualización.',
      'Installer opened. Follow the prompts to finish.':
          'Se abrió el instalador. Siga las instrucciones para terminar.',
      'Dismiss': 'Cerrar',
      'Update available': 'Actualización disponible',
      'Update now': 'Actualizar ahora',
      'Refresh now': 'Actualizar ahora',
      'Later': 'Más tarde',
      'What\'s new': 'Novedades',
      'Downloading update...': 'Descargando actualización...',
      'Downloading update ({version})...':
          'Descargando actualización ({version})...',
      'Refreshing app...': 'Actualizando la aplicación...',
      'Update failed': 'Error de actualización',
      'Downloading...': 'Descargando...',
      'Refreshing...': 'Actualizando...',
      'Update {version}': 'Actualización {version}',
      'Update': 'Actualizar',
      'Preferences': 'Preferencias',
      'Data & tools': 'Datos y herramientas',
      'Choose how SysteMIC looks and speaks.': 'Elija el aspecto y el idioma de SysteMIC.',
      'Workspace tools': 'Herramientas del espacio de trabajo',
      'Export, import, sync, and reports': 'Exportar, importar, sincronizar e informes',
      'Signed in as': 'Sesión iniciada como',
      'Configure birthday notification settings': 'Configurar notificaciones de cumpleaños',
      'Create members for all users and users for all leaders': 'Crear miembros para todos los usuarios y usuarios para todos los líderes',
      'Generate comprehensive report for all users': 'Generar un informe completo para todos los usuarios',
      'Define feature access for each leader': 'Definir el acceso a funciones para cada líder',
      'Select Theme': 'Seleccionar tema',
      'No tasks in this department': 'No hay tareas en este departamento',
      'You can only create tasks for departments you lead': 'Solo puede crear tareas para los departamentos que dirige',
      'A new version ({version}) is available.': 'Hay una nueva versión ({version}) disponible.',
      'Update failed: {error}': 'Error de actualización: {error}',
      'Weekly attendance': 'Asistencia semanal',
      'Language': 'Idioma',
      'Light': 'Claro',
      'Dark': 'Oscuro',
      'System Default': 'Predeterminado del sistema',
      'Account': 'Cuenta',
      'App Version': 'Versión de la aplicación',
      'English': 'English',
      'Français': 'Français',
      'Español': 'Español',
      'No chart data': 'Sin datos del gráfico',
      'Not logged in': 'No ha iniciado sesión',
      'Theme': 'Tema',
      'Enable Notifications': 'Activar notificaciones',
      'Birthday Notifications': 'Notificaciones de cumpleaños',
      'Export All Data': 'Exportar todos los datos',
      'Import Data': 'Importar datos',
      'Export Members': 'Exportar miembros',
      'Sync Users & Members': 'Sincronizar usuarios y miembros',
      'Generate All Users Report': 'Generar informe de todos los usuarios',
      'Leader Access Management': 'Gestión de acceso de líderes',
      'Logout': 'Cerrar sesión',
      'Settings': 'Configuración',
      'Page {current} of {total}': 'Página {current} de {total}',
      'Error loading services: {error}': 'Error al cargar los cultos: {error}',
      'Error deleting service: {error}': 'Error al eliminar el culto: {error}',
      'Error generating report: {error}': 'Error al generar el informe: {error}',
      'Report generated successfully: {path}': 'Informe generado correctamente: {path}',
      '{count} member attended': '{count} miembro presente',
      '{count} members attended': '{count} miembros presentes',
      ', {count} visitor': ', {count} visitante',
      ', {count} visitors': ', {count} visitantes',
      'Absent ({count})': 'Ausentes ({count})',
      'Absent PDF generated successfully: {path}': 'PDF de ausentes generado correctamente: {path}',
      'Absent people': 'Personas ausentes',
      'Absent people ({count})': 'Personas ausentes ({count})',
      'Adults': 'Adultos',
      'Adults attended': 'Adultos presentes',
      'All ({count})': 'Todos ({count})',
      'Are you sure you want to remove this attendance record?': '¿Seguro que desea eliminar este registro de asistencia?',
      'Arrived late': 'Llegó tarde',
      'Attendance removed successfully': 'Asistencia eliminada correctamente',
      'Attendance saved successfully': 'Asistencia guardada correctamente',
      'Attendance updated successfully': 'Asistencia actualizada correctamente',
      'Attended in person': 'Presente en persona',
      'Attended virtually': 'Presente en línea',
      'Attendees': 'Asistentes',
      'Away': 'Ausente',
      'Children': 'Niños',
      'Children ({count})': 'Niños ({count})',
      'Children attended': 'Niños presentes',
      'Could not load visitors: {error}': 'No se pudieron cargar los visitantes: {error}',
      'Could not open WhatsApp. Make sure it is installed on this device.': 'No se pudo abrir WhatsApp. Asegúrese de que esté instalado en este dispositivo.',
      'Edit Attendance': 'Editar asistencia',
      'Edit Attendance Type': 'Editar tipo de asistencia',
      'Edit Visitor Attendance': 'Editar asistencia del visitante',
      'Edit attendance': 'Editar asistencia',
      'Email: {email}': 'Correo: {email}',
      'Error adding visitor: {error}': 'Error al agregar el visitante: {error}',
      'Error generating absent PDF: {error}': 'Error al generar el PDF de ausentes: {error}',
      'Error loading members: {error}': 'Error al cargar los miembros: {error}',
      'Error removing attendance: {error}': 'Error al eliminar la asistencia: {error}',
      'Error removing visitor: {error}': 'Error al eliminar el visitante: {error}',
      'Error saving attendance: {error}': 'Error al guardar la asistencia: {error}',
      'Error saving observation: {error}': 'Error al guardar la observación: {error}',
      'Error updating attendance: {error}': 'Error al actualizar la asistencia: {error}',
      'Error updating visitor: {error}': 'Error al actualizar el visitante: {error}',
      'Export PDF': 'Exportar PDF',
      'Export absent PDF': 'Exportar PDF de ausentes',
      'Filter attendees': 'Filtrar asistentes',
      'Filter:': 'Filtro:',
      'First name *': 'Nombre *',
      'Last name *': 'Apellido *',
      'Logged: {datetime}': 'Registrado: {datetime}',
      'Members & Visitors': 'Miembros y visitantes',
      'New comer': 'Recién llegado',
      'New comer children': 'Niños recién llegados',
      'New comer children attended': 'Niños recién llegados presentes',
      'New comers': 'Recién llegados',
      'New comers attended': 'Recién llegados presentes',
      'No absent people': 'No hay personas ausentes',
      'No active members found': 'No se encontraron miembros activos',
      'No attendance recorded for this service': 'No hay asistencia registrada para este culto',
      'No results found': 'No se encontraron resultados',
      'Notes (optional)': 'Notas (opcional)',
      'Observation removed': 'Observación eliminada',
      'Observation saved': 'Observación guardada',
      'Online ({count})': 'En línea ({count})',
      'Online attendance': 'Asistencia en línea',
      'Onsite ({count})': 'Presencial ({count})',
      'Onsite breakdown': 'Desglose presencial',
      'Open WhatsApp': 'Abrir WhatsApp',
      'Other visit date': 'Otra fecha de visita',
      'Phone (optional)': 'Teléfono (opcional)',
      'Phone: {phone}': 'Teléfono: {phone}',
      'Quick add': 'Añadir rápido',
      'Remove Attendance': 'Eliminar asistencia',
      'Remove Visitor': 'Eliminar visitante',
      'Remove attendance': 'Eliminar asistencia',
      'Remove note': 'Eliminar nota',
      'Remove this visitor from today\'s visit log?': '¿Eliminar este visitante del registro de visitas de hoy?',
      'Remove visitor': 'Eliminar visitante',
      'Save Attendance': 'Guardar asistencia',
      'Save attendance before exporting PDF': 'Guarde la asistencia antes de exportar el PDF',
      'Save note': 'Guardar nota',
      'Search members and visitors...': 'Buscar miembros y visitantes...',
      'Search…': 'Buscar…',
      'Select Service Date': 'Seleccionar fecha del culto',
      'Service Date': 'Fecha del culto',
      'Service Details': 'Detalles del culto',
      'Service note': 'Nota del culto',
      'Sick': 'Enfermo',
      'Specific observation': 'Observación específica',
      'Summary': 'Resumen',
      'Tap Edit to mark attendance or add visitors': 'Toque Editar para marcar asistencia o agregar visitantes',
      'Total (excluding online)': 'Total (sin en línea)',
      'Traveling': 'De viaje',
      'Try adjusting search or filters': 'Intente ajustar la búsqueda o los filtros',
      'Try adjusting your search': 'Intente ajustar su búsqueda',
      'Visitor added': 'Visitante agregado',
      'Visitor attendance updated': 'Asistencia del visitante actualizada',
      'Visitor removed': 'Visitante eliminado',
      'Visitors ({count})': 'Visitantes ({count})',
      'Visitors attended': 'Visitantes presentes',
      'Was not present': 'No estuvo presente',
      'Write a note for this service…': 'Escriba una nota para este culto…',
      'onsite attendees': 'asistentes presenciales',
      'Onsite attendees': 'Asistentes presenciales',
      '{attended} attended, {absent} absent{visitors}': '{attended} presentes, {absent} ausentes{visitors}',
      '{count} left': '{count} restantes',
      'Account created': 'Cuenta creada',
      'Add email for member': 'Agregar correo para el miembro',
      'Save & create account': 'Guardar y crear cuenta',
      'member@example.com': 'miembro@ejemplo.com',
      'This member has no email. Enter one to create a login account.': 'Este miembro no tiene correo. Ingrese uno para crear una cuenta.',
      '{name} has no email. Enter one to create a login account.': '{name} no tiene correo. Ingrese uno para crear una cuenta.',
      'A login account was created for {name}.\n\nEmail: {email}\nDefault password: {password}\n\nThey must change their password on first login. An email with these credentials has been sent.': 'Se creó una cuenta de acceso para {name}.\n\nCorreo: {email}\nContraseña predeterminada: {password}\n\nDeberá cambiar la contraseña en el primer inicio de sesión. Se envió un correo con estas credenciales.',
      'Task assigned, but login was not created (no email).': 'Tarea asignada, pero no se creó el acceso (sin correo).',
      'Task assigned, but login was not created: could not save email.': 'Tarea asignada, pero no se creó el acceso: no se pudo guardar el correo.',
      'Task assigned, but login was not created: {error}': 'Tarea asignada, pero no se creó el acceso: {error}',
      'Could not create login account: member not found.': 'No se pudo crear la cuenta: miembro no encontrado.',
      'Please enter a valid email address.': 'Introduzca una dirección de correo válida.',
      'Email cannot be empty.': 'El correo no puede estar vacío.',
},
  };

  static const Map<String, Map<String, String>> _fallbackPhraseReplacements = {
    'fr': {
      'Action': 'Action',
      'Actions': 'Actions',
      'Active': 'Actif',
      'Add': 'Ajouter',
      'Address': 'Adresse',
      'Admin': 'Admin',
      'All': 'Tous',
      'Amount': 'Montant',
      'Announcement': 'Annonce',
      'Announcements': 'Annonces',
      'Apply': 'Appliquer',
      'Archive': 'Archiver',
      'Assignment': 'Assignation',
      'Attendance': 'Présence',
      'Back': 'Retour',
      'Birthday': 'Anniversaire',
      'Cancel': 'Annuler',
      'Cancelled': 'Annulé',
      'Category': 'Catégorie',
      'Chart': 'Graphique',
      'Choose': 'Choisir',
      'City': 'Ville',
      'Class': 'Formation',
      'Clear': 'Effacer',
      'Close': 'Fermer',
      'Comments': 'Commentaires',
      'Completed': 'Terminé',
      'Confirm': 'Confirmer',
      'Country': 'Pays',
      'Create': 'Créer',
      'Current': 'Actuel',
      'Custom': 'Personnalisé',
      'Daily': 'Quotidien',
      'Date': 'Date',
      'Days': 'Jours',
      'Delete': 'Supprimer',
      'Department': 'Département',
      'Description': 'Description',
      'Details': 'Détails',
      'Difficulties': 'Difficultés',
      'Disable': 'Désactiver',
      'Divorced': 'Divorcé',
      'Domain': 'Domaine',
      'Due': 'Échéance',
      'Edit': 'Modifier',
      'Email': 'E-mail',
      'End': 'Fin',
      'Enter': 'Saisir',
      'Error': 'Erreur',
      'Event': 'Événement',
      'Export': 'Exporter',
      'Failed': 'Échec',
      'File': 'Fichier',
      'Filter': 'Filtrer',
      'First': 'Prénom',
      'From': 'Depuis',
      'Generate': 'Générer',
      'Giving': 'Don',
      'Guest': 'Invité',
      'High': 'Élevé',
      'Import': 'Importer',
      'Inactive': 'Inactif',
      'Last': 'Nom',
      'Leader': 'Dirigeant',
      'Loading': 'Chargement',
      'Low': 'Faible',
      'Manage': 'Gérer',
      'Member': 'Membre',
      'Members': 'Membres',
      'Name': 'Nom',
      'New': 'Nouveau',
      'No': 'Aucun',
      'Note': 'Note',
      'Notes': 'Notes',
      'Notification': 'Notification',
      'Notifications': 'Notifications',
      'Open': 'Ouvrir',
      'Optional': 'Facultatif',
      'Overview': 'Aperçu',
      'Password': 'Mot de passe',
      'Payment': 'Paiement',
      'Pending': 'En attente',
      'Penalty': 'Pénalité',
      'Phone': 'Téléphone',
      'Photo': 'Photo',
      'Priority': 'Priorité',
      'Profession': 'Profession',
      'Project': 'Projet',
      'Projects': 'Projets',
      'Record': 'Enregistrer',
      'Register': 'Inscrire',
      'Registration': 'Inscription',
      'Remove': 'Retirer',
      'Report': 'Rapport',
      'Reports': 'Rapports',
      'Required': 'Requis',
      'Reset': 'Réinitialiser',
      'Role': 'Rôle',
      'Save': 'Enregistrer',
      'Search': 'Rechercher',
      'Select': 'Sélectionner',
      'Service': 'Culte',
      'Session': 'Session',
      'Settings': 'Paramètres',
      'Skill': 'Compétence',
      'Start': 'Début',
      'Status': 'Statut',
      'Success': 'Succès',
      'Summary': 'Résumé',
      'Tag': 'Étiquette',
      'Task': 'Tâche',
      'Tasks': 'Tâches',
      'Teaching': 'Enseignement',
      'Title': 'Titre',
      'Token': 'Jeton',
      'Training': 'Formation',
      'Update': 'Mettre à jour',
      'User': 'Utilisateur',
      'Visitor': 'Visiteur',
      'Visitors': 'Visiteurs',
    },
    'es': {
      'Action': 'Acción',
      'Actions': 'Acciones',
      'Active': 'Activo',
      'Add': 'Agregar',
      'Address': 'Dirección',
      'Admin': 'Admin',
      'All': 'Todos',
      'Amount': 'Cantidad',
      'Announcement': 'Anuncio',
      'Announcements': 'Anuncios',
      'Apply': 'Aplicar',
      'Archive': 'Archivar',
      'Assignment': 'Asignación',
      'Attendance': 'Asistencia',
      'Back': 'Atrás',
      'Birthday': 'Cumpleaños',
      'Cancel': 'Cancelar',
      'Cancelled': 'Cancelado',
      'Category': 'Categoría',
      'Chart': 'Gráfico',
      'Choose': 'Elegir',
      'City': 'Ciudad',
      'Class': 'Formación',
      'Clear': 'Limpiar',
      'Close': 'Cerrar',
      'Comments': 'Comentarios',
      'Completed': 'Completado',
      'Confirm': 'Confirmar',
      'Country': 'País',
      'Create': 'Crear',
      'Current': 'Actual',
      'Custom': 'Personalizado',
      'Daily': 'Diario',
      'Date': 'Fecha',
      'Days': 'Días',
      'Delete': 'Eliminar',
      'Department': 'Departamento',
      'Description': 'Descripción',
      'Details': 'Detalles',
      'Difficulties': 'Dificultades',
      'Disable': 'Desactivar',
      'Divorced': 'Divorciado',
      'Domain': 'Dominio',
      'Due': 'Vencimiento',
      'Edit': 'Editar',
      'Email': 'Correo electrónico',
      'End': 'Fin',
      'Enter': 'Ingresar',
      'Error': 'Error',
      'Event': 'Evento',
      'Export': 'Exportar',
      'Failed': 'Falló',
      'File': 'Archivo',
      'Filter': 'Filtrar',
      'First': 'Nombre',
      'From': 'Desde',
      'Generate': 'Generar',
      'Giving': 'Donación',
      'Guest': 'Invitado',
      'High': 'Alta',
      'Import': 'Importar',
      'Inactive': 'Inactivo',
      'Last': 'Apellido',
      'Leader': 'Líder',
      'Loading': 'Cargando',
      'Low': 'Baja',
      'Manage': 'Gestionar',
      'Member': 'Miembro',
      'Members': 'Miembros',
      'Name': 'Nombre',
      'New': 'Nuevo',
      'No': 'Sin',
      'Note': 'Nota',
      'Notes': 'Notas',
      'Notification': 'Notificación',
      'Notifications': 'Notificaciones',
      'Open': 'Abrir',
      'Optional': 'Opcional',
      'Overview': 'Resumen',
      'Password': 'Contraseña',
      'Payment': 'Pago',
      'Pending': 'Pendiente',
      'Penalty': 'Penalización',
      'Phone': 'Teléfono',
      'Photo': 'Foto',
      'Priority': 'Prioridad',
      'Profession': 'Profesión',
      'Project': 'Proyecto',
      'Projects': 'Proyectos',
      'Record': 'Registrar',
      'Register': 'Registrar',
      'Registration': 'Registro',
      'Remove': 'Eliminar',
      'Report': 'Informe',
      'Reports': 'Informes',
      'Required': 'Requerido',
      'Reset': 'Restablecer',
      'Role': 'Rol',
      'Save': 'Guardar',
      'Search': 'Buscar',
      'Select': 'Seleccionar',
      'Service': 'Servicio',
      'Session': 'Sesión',
      'Settings': 'Configuración',
      'Skill': 'Habilidad',
      'Start': 'Inicio',
      'Status': 'Estado',
      'Success': 'Éxito',
      'Summary': 'Resumen',
      'Tag': 'Etiqueta',
      'Task': 'Tarea',
      'Tasks': 'Tareas',
      'Teaching': 'Enseñanza',
      'Title': 'Título',
      'Token': 'Token',
      'Training': 'Formación',
      'Update': 'Actualizar',
      'User': 'Usuario',
      'Visitor': 'Visitante',
      'Visitors': 'Visitantes',
    },
  };

  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'appName': 'SysteMIC',
      'welcome': 'Welcome',
      'loading': 'Loading...',
      'error': 'Error',
      'success': 'Success',
      'cancel': 'Cancel',
      'confirm': 'Confirm',
      'save': 'Save',
      'delete': 'Delete',
      'edit': 'Edit',
      'search': 'Search',
      'filter': 'Filter',
      'close': 'Close',
      'login': 'Login',
      'logout': 'Logout',
      'email': 'Email',
      'password': 'Password',
      'forgotPassword': 'Forgot Password?',
      'signIn': 'Sign In',
      'signOut': 'Sign Out',
      'emailRequired': 'Email is required',
      'passwordRequired': 'Password is required',
      'invalidEmail': 'Invalid email format',
      'loginError': 'Login failed. Please try again.',
      'dashboard': 'Dashboard',
      'home': 'Home',
      'overview': 'Overview',
      'statistics': 'Statistics',
      'members': 'Members',
      'attendance': 'Attendance',
      'giving': 'Giving',
      'events': 'Events',
      'settings': 'Settings',
      'notifications': 'Notifications',
      'profile': 'Profile',
      'noData': 'No data available',
      'networkError': 'Network error. Please check your connection.',
      'genericError': 'An error occurred. Please try again.',
      // Finance
      'finance': 'Finance',
      'addGivingRecord': 'Add Giving Record',
      'givingRecord': 'Giving Record',
      'givingRecordDetails': 'Giving Record Details',
      'transactionType': 'Transaction Type',
      'receiving': 'Receiving',
      'expense': 'Expense',
      'giverType': 'Giver Type',
      'member': 'Member',
      'externalPerson': 'External Person',
      'giverName': 'Giver Name',
      'selectMember': 'Select Member',
      'amount': 'Amount',
      'tag': 'Tag',
      'notes': 'Notes',
      'description': 'Description',
      'date': 'Date',
      'category': 'Category',
      'created': 'Created',
      'lastUpdated': 'Last Updated',
      'recordInformation': 'Record Information',
      'transactionDetails': 'Transaction Details',
      'noGivingRecords': 'No giving records yet',
      'addFirstRecord': 'Add First Record',
      'givingRecordCreated': 'Giving record created successfully',
      'givingRecordUpdated': 'Giving record updated successfully',
      'givingRecordNotFound': 'Giving record not found',
      'errorLoadingGivingRecord': 'Error loading giving record',
      'giverNameRequired': 'Giver name is required',
      'pleaseSelectTag': 'Please select a tag',
      'amountRequired': 'Amount is required',
      'validAmountRequired': 'Please enter a valid amount greater than zero',
      'createExpense': 'Create Expense',
      'createReceivingRecord': 'Create Receiving Record',
      'saveChanges': 'Save Changes',
      'recordCanBeEdited':
          'This record can be edited. Changes will be saved immediately.',
      'recordCannotBeEdited':
          'This record was created more than 2 days ago and cannot be edited.',
      'errorLoadingGivingRecords': 'Error loading giving records',
      // Tag labels
      'construction': 'Construction',
      'specialOperation': 'Special Operation',
      'tithe': 'Tithe',
      'offering': 'Offering',
      'gift': 'Gift',
      'other': 'Other',
      // Dashboard
      'upcomingSessions': 'Upcoming Sessions',
      'upcomingEvents': 'Upcoming Events',
      'tasks': 'Tasks',
      'birthdays': 'Birthdays',
      'quickActions': 'Quick Actions',
      'departments': 'Departments',
      'classes': 'Trainings',
      'reports': 'Reports',
      'chat': 'Chat',
      'errorLoadingDashboard': 'Error loading dashboard',
      // Error Messages
      'errorLoginFailed': 'Login failed. Check your credentials.',
      'errorEmailNotConfirmed': 'Please confirm your email to continue.',
      'errorUserNotFound': 'User not found.',
      'errorAccountCreationFailed': 'Failed to create account.',
      'errorDuplicateEmail': 'Email already in use.',
      'errorPermissionDenied': 'You don\'t have permission for this action.',
      'errorOperationFailed': 'Operation failed. Please try again.',
      'errorInvalidCredentials': 'Invalid email or password.',
      'errorPasswordResetFailed': 'Password reset failed.',
      'errorMustBeLoggedIn': 'Please log in to continue.',
      'errorAdminOrLeaderRequired':
          'Only admins or leaders can perform this action.',
      'errorMemberNotFound': 'Member not found.',
      'errorEmailOrPhoneRequired': 'Email or phone is required.',
      'errorDepartmentNotFound': 'Department not found.',
      'errorFailedToLoad': 'Failed to load data.',
      'errorFailedToSave': 'Failed to save. Please try again.',
      'errorFailedToDelete': 'Failed to delete.',
      'errorFileUploadFailed': 'File upload failed.',
      'errorInvalidInput': 'Invalid input. Please check your data.',
      // Departments
      'addDepartment': 'Add Department',
      'editDepartment': 'Edit Department',
      'departmentName': 'Department Name',
      'departmentNameRequired': 'Department name is required',
      'departmentDescription': 'Description',
      'departmentCreated': 'Department created successfully',
      'departmentUpdated': 'Department updated successfully',
      'departmentDeleted': 'Department deleted successfully',
      'errorCreatingDepartment': 'Failed to create department',
      'errorUpdatingDepartment': 'Failed to update department',
      'errorDeletingDepartment': 'Failed to delete department',
      'errorLoadingDepartments': 'Failed to load departments',
      'noDepartments': 'No departments yet',
      'noDepartmentsFound': 'No departments found',
      'searchDepartments': 'Search departments...',
      'departmentFiles': 'Department Files',
      'noFilesUploaded': 'No files uploaded',
      'documents': 'Documents',
      'documentsOptional': 'Documents (Optional)',
      'document': 'Document',
      'upload': 'Upload',
      'remove': 'Remove',
      'view': 'View',
      'newFile': 'New file',
      'deleteDepartment': 'Delete Department',
      'deleteDepartmentConfirm':
          'Are you sure you want to delete this department? This will deactivate it.',
      'createDepartment': 'Create Department',
      'updateDepartment': 'Update Department',
      // Department Members
      'addMember': 'Add Member',
      'removeMember': 'Remove Member',
      'changeRole': 'Change Role',
      'role': 'Role',
      'leader': 'Leader',
      'subleader': 'Subleader',
      'memberRole': 'Member',
      'selectRole': 'Select Role',
      'memberAdded': 'Member added successfully',
      'memberRemoved': 'Member removed successfully',
      'roleUpdated': 'Role updated successfully',
      'errorAddingMember': 'Failed to add member',
      'errorRemovingMember': 'Failed to remove member',
      'errorUpdatingRole': 'Failed to update role',
      'errorLoadingMembers': 'Failed to load members',
      'noMembersInDepartment': 'No members in this department',
      'allMembersInDepartment': 'All members are already in this department',
      'removeMemberConfirm':
          'Are you sure you want to remove {name} from this department?',
      'deleteMember': 'Delete Member',
      'deleteMemberConfirmation':
          'Are you sure you want to delete {name}? This action cannot be undone.',
      'memberDeletedSuccessfully': 'Member deleted successfully',
      // Password Change
      'changePassword': 'Change Password',
      'changePasswordRequired': 'Change Password Required',
      'changePasswordMessage':
          'You must change your password before continuing.',
      'newPassword': 'New Password',
      'confirmPassword': 'Confirm New Password',
      'newPasswordRequired': 'New password is required',
      'passwordMinLength': 'Password must be at least 6 characters',
      'passwordsDoNotMatch': 'Passwords do not match',
      'passwordChanged': 'Password changed successfully',
      'errorChangingPassword': 'Failed to change password',
      // Tasks
      'manageTasks': 'Manage Tasks',
      'generateReport': 'Generate Report',
      'taskCompletion': 'Task Completion',
      'total': 'Total',
      'completed': 'Completed',
      'pending': 'Pending',
      'inProgress': 'In Progress',
      'noTasks': 'No tasks in this department',
      // Reports
      'createReport': 'Create Report',
      'generateSummaryReport': 'Generate Summary Report',
      'noReports': 'No reports yet',
      'createFirstReport': 'Create your first report to get started',
      'generatePdf': 'Generate PDF',
      'editReport': 'Edit',
      'deleteReport': 'Delete',
      'deleteReportConfirm': 'Are you sure you want to delete "{title}"?',
      'reportDeleted': 'Report deleted successfully',
      'errorDeletingReport': 'Failed to delete report',
      'reportGenerated': 'Report generated successfully',
      'errorGeneratingReport': 'Failed to generate report',
      'generatingPdf': 'Generating PDF...',
      'generatingReport': 'Generating report...',
      'pdfGenerated': 'PDF generated successfully',
      // Common
      'refresh': 'Refresh',
      'active': 'Active',
      'inactive': 'Inactive',
      'phone': 'Phone',
      'phoneOrEmail': 'Email or Phone',
      'update': 'Update',
      'add': 'Add',
      'name': 'Name',
      'nameRequired': 'Name is required',
      'successOperation': 'Operation completed successfully',
      'warning': 'Warning',
      'someDocumentsFailed':
          'Department created, but some documents failed to upload',
      'documentUploadErrors': 'Document Upload Errors',
      'documentsFailedMessage':
          'The department was created, but the following documents failed to upload:',
      'canAddDocumentsLater':
          'You can add these documents later by editing the department.',
      'ok': 'OK',
      'optional': '(Optional)',
      'enterDepartmentName': 'Enter the name of the department',
      'optionalDescription': 'Optional description for the department',
      // Teachings
      'teachings': 'Teachings',
      'addTeaching': 'Add Teaching',
      'editTeaching': 'Edit Teaching',
      'teachingDetails': 'Teaching Details',
      'teachingTitle': 'Title',
      'teachingTitleRequired': 'Please enter a title',
      'teachingDate': 'Teaching Date',
      'teachingDateRequired': 'Please select a date',
      'speaker': 'Speaker',
      'teachingDescription': 'Description',
      'updateTeaching': 'Update Teaching',
      'teachingAdded': 'Teaching added successfully',
      'teachingUpdated': 'Teaching updated successfully',
      'teachingDeleted': 'Teaching deleted successfully',
      'errorLoadingTeaching': 'Error loading teaching',
      'errorDeletingTeaching': 'Error deleting teaching',
      'deleteTeachingConfirm': 'Are you sure you want to delete "{title}"?',
      'searchTeachings': 'Search teachings...',
      'noTeachings': 'No teachings yet',
      'noTeachingsFound': 'No teachings found matching your search',
      'listeners': 'Listeners',
      'syncFromAttendance': 'Sync from Church Attendance',
      'searchPotentialListeners': 'Search potential listeners...',
      'noListeners': 'No listeners yet',
      'addListener': 'Add',
      'addListenerTitle': 'Add Listener',
      'removeListener': 'Remove Listener',
      'removeListenerConfirm': 'Remove "{name}" from listeners?',
      'listenerAdded': 'Listener added successfully',
      'listenerRemoved': 'Listener removed successfully',
      'errorAddingListener': 'Error adding listener',
      'errorRemovingListener': 'Error removing listener',
      'errorSyncingListeners': 'Error syncing listeners',
      'listenersSynced': 'Synced {count} listener(s) from church attendance',
      'allListenersAdded': 'All potential listeners are already added',
      'useSyncOrAdd':
          'Use "Sync from Church Attendance" or "Add" to add listeners',
      // Visitors
      'visitors': 'Visitors',
      'addVisitor': 'Add Visitor',
      'editVisitor': 'Edit Visitor',
      'updateVisitor': 'Update Visitor',
      'visitorFirstName': 'First Name',
      'visitorFirstNameRequired': 'First name is required',
      'visitorLastName': 'Last Name',
      'visitorLastNameRequired': 'Last name is required',
      'visitDate': 'Visit Date',
      'visitDateRequired': 'Visit date is required',
      'visitorAdded': 'Visitor added successfully',
      'visitorUpdated': 'Visitor updated successfully',
      'visitorDeleted': 'Visitor deleted successfully',
      'errorLoadingVisitor': 'Error loading visitor',
      'errorDeletingVisitor': 'Error deleting visitor',
      'deleteVisitorConfirm': 'Are you sure you want to delete "{name}"?',
      'searchVisitors': 'Search visitors...',
      'noVisitors': 'No visitors yet',
      'noVisitorsFound': 'No visitors found matching your search',
      'convertToMember': 'Convert to Member',
      'convertVisitorToMember': 'Convert visitor to member',
      'convertVisitorToMemberConfirm':
          'Create a member profile for "{name}" using the visitor\'s contact details. The visitor record will be removed.',
      'visitorConvertedToMember': 'Visitor converted to member successfully',
      'errorConvertingVisitor': 'Error converting visitor to member',
      // Workers & Departments
      'workers': 'Workers',
      'searchWorkers': 'Search workers...',
      'noWorkers': 'No workers found',
      'noWorkersFound': 'No workers found matching your search',
      'noDepartmentsAssigned': 'No departments assigned',
      'setMainDepartment': 'Set Main Department',
      'setMainDepartmentFor': 'Set Main Department for {name}',
      'workerNoDepartments': 'Worker has no departments assigned',
      'updatingMainDepartment': 'Updating main department...',
      'mainDepartmentUpdated': 'Main department updated successfully',
      'errorUpdatingMainDepartment': 'Error updating main department',
      // Leader Access
      'leaderAccessManagement': 'Leader Access Management',
      'defineFeatureAccess': 'Define feature access for each leader',
      'featureAccessPermissions': 'Feature Access Permissions',
      'unsavedChanges': 'Unsaved changes',
      'saveAllChanges': 'Save All Changes',
      'allAccessSaved': 'All access permissions saved successfully',
      'errorSavingAccess': 'Error saving access',
      'errorLoadingLeaders': 'Error loading leaders',
      'errorLoadingAccess': 'Error loading access',
      'canView': 'View',
      'canCreate': 'Create',
      'canEdit': 'Edit',
      'canDelete': 'Delete',
      // Settings
      'adminSettings': 'Admin Settings',
      'language': 'Language',
      'theme': 'Theme',
      'enableNotifications': 'Enable Notifications',
      'receivePushNotifications': 'Receive push notifications',
      'exportAllData': 'Export All Data',
      'exportAllDataSubtitle': 'Export all data to JSON file',
      'importData': 'Import Data',
      'importDataSubtitle': 'Import data from JSON file',
      'exportMembers': 'Export Members',
      'exportMembersSubtitle': 'Export members to CSV',
      'syncUsersMembers': 'Sync Users & Members',
      'generateAllUsersReport': 'Generate All Users Report',
      'birthdayNotifications': 'Birthday Notifications',
      'configureBirthdayNotifications':
          'Configure birthday notification settings',
      'currentUser': 'Current User',
      'signOutAccount': 'Sign out of your account',
      'appVersion': 'App Version',
      'logoutConfirm': 'Are you sure you want to logout?',
      'languageChanged': 'Language changed successfully',
      'errorChangingLanguage': 'Failed to change language',
      'themeChanged': 'Theme changed successfully',
      'errorChangingTheme': 'Failed to change theme',
      'errorUpdatingNotifications': 'Failed to update notifications',
      'export': 'Export',
      'importing': 'Importing data...',
      'exporting': 'Exporting data...',
      'dataExported': 'Data exported successfully to:\n{path}',
      'exportCancelled': 'Export cancelled',
      'exportFailed': 'Export failed',
      'membersExported': 'Members exported successfully',
      'sync': 'Sync',
      'syncing': 'Syncing users and members...',
      'syncFailed': 'Sync failed',
      'reportSaved': 'Report saved successfully to:\n{path}',
      'reportGenerationCancelled': 'Report generation cancelled',
      'reportGenerationFailed': 'Report generation failed',
      'import': 'Import',
      'importFailed': 'Import failed',
      'english': 'English',
      'french': 'Français',
      'selectTheme': 'Select Theme',
      'light': 'Light',
      'dark': 'Dark',
      'systemDefault': 'System Default',
      'birthdayNotificationsSettings': 'Birthday Notifications',
      'allChurchAppUsers': 'All Church App Users',
      'defaultAllActiveMembers': 'Default: All active members',
      'leadersOnly': 'Leaders Only',
      'onlyDepartmentLeadersAdmins': 'Only department leaders and admins',
      'optOutNoNotifications': 'Opt-Out (No Notifications)',
      'usersCanOptIn': 'Users can opt-in individually',
      'note': 'Note',
      'saveSettings': 'Save Settings',
      'settingsSaved': 'Settings saved successfully',
      'errorSavingConfig': 'Error saving config',
      'errorLoadingConfig': 'Error loading config',
      'notificationsEnabled': 'Notifications enabled',
      'notificationsDisabled': 'Notifications disabled',
      'exportAllDataConfirm':
          'This will export all members, departments, classes, events, and tasks to a JSON file. You will be asked to select a save location. Continue?',
      'syncUsersMembersConfirm':
          'This will:\n1. Create a member for every user\n2. Create a user (with default password "Password123") for every leader member\n\nLeaders will be required to change their password on first login.\n\nContinue?',
      'syncCompleted': 'Sync completed!',
      'usersToMembers': 'Users → Members',
      'leadersToUsers': 'Leaders → Users',
      'createdLabel': 'created',
      'skippedLabel': 'skipped',
      'errorsLabel': 'errors',
      'importDataConfirm':
          'This will import data from a JSON file. Existing members with the same email will be skipped. Continue?',
      'importCompleted': 'Import completed',
      'importedLabel': 'Imported',
      'notLoggedIn': 'Not logged in',
      'logoutFailed': 'Logout failed',
      'languageAndRegion': 'Language & Region',
      'appearance': 'Appearance',
      'dataManagement': 'Data Management',
      'about': 'About',
      'generateReportComprehensive':
          'Generate comprehensive report for all users',
      'account': 'Account',
      // Events
      'addEvent': 'Add Event',
      'editEvent': 'Edit Event',
      'deleteEvent': 'Delete Event',
      'eventDeleted': 'Event deleted successfully',
      'errorDeletingEvent': 'Error deleting event',
      'deleteEventConfirm': 'Are you sure you want to delete "{title}"?',
      'searchEvents': 'Search events...',
      'noEvents': 'No events yet',
      'noEventsFound': 'No events found matching your search',
      // Church Attendance
      'churchAttendance': 'Church Attendance',
      'sundaySchool': 'Sunday School',
      'churchAttendanceReportPdfTitle': 'Church attendance report',
      'churchAttendanceReportPdfIntro':
          'This report is organised by calendar month. Each month includes a member table (Onsite / Online / Absent per service) and monthly summary charts. The last column is left blank for notes.',
      'churchAttendanceReportPdfDiligenceNote':
          'Diligence: ≥{d}% present = Diligent; ≥{m}% = Moderately diligent; below = Not diligent. Present = onsite + online, denominator = number of scheduled services in the month.',
      'attendanceReportFullName': 'Full name',
      'attendanceReportOnsiteTotal': 'Onsite (total)',
      'attendanceReportOnlineTotal': 'Online (total)',
      'attendanceReportTotalPresent': 'Total present',
      'attendanceReportObservation': 'Observation',
      'attendanceReportSpecificObservations': 'Specific observations',
      'attendanceReportPresentAbbr': 'P',
      'attendanceReportAbsentAbbr': 'A',
      'attendanceReportOnlineAbbr': 'O',
      'attendanceReportOnsite': 'Onsite',
      'attendanceReportOnline': 'Online',
      'attendanceReportAbsent': 'Absent',
      'attendanceReportVisitor': 'Visitor',
      'attendanceReportVisitorsSection': 'Visitors',
      'attendanceReportChildTag': 'Child',
      'attendanceReportNewComerTag': 'New comer',
      'attendanceReportMembersSection': 'Members',
      'attendanceReportMonthlySummaryTitle':
          'Monthly attendance (sum of present counts)',
      'attendanceReportPresenceChartsSection': 'Monthly presence',
      'attendanceReportSundayMonthlyPresenceChart':
          'Sunday — present count by service',
      'attendanceReportWednesdayMonthlyPresenceChart':
          'Wednesday — present count by service',
      'attendanceReportTotalMonthlyPresenceChart':
          'Total presence — by service date (chronological)',
      'attendanceReportSundayMonthTotal': 'Sunday (month)',
      'attendanceReportWednesdayMonthTotal': 'Wednesday (month)',
      'attendanceReportAllServicesMonthTotal': 'All services (month)',
      'attendanceReportChartNoData': 'No data',
      'attendanceReportDiligent': 'Diligent',
      'attendanceReportModeratelyDiligent': 'Moderately diligent',
      'attendanceReportNotDiligent': 'Not diligent',
      'attendanceReportSundayShort': 'Sun',
      'attendanceReportWednesdayShort': 'Wed',
      'churchAttendanceReportPdfGenerated': 'Generated',
      'churchAttendanceReportPdfPeriod': 'Period',
      'churchAttendanceReportPdfServiceFilter': 'Service type',
      'churchAttendanceReportPdfSundayService': 'Sunday service',
      'churchAttendanceReportPdfWednesdayService': 'Wednesday service',
      // Reports
      'trainingReport': 'Training Report',
      'memberReport': 'Member Report',
      'updateReport': 'Update Report',
      'createReportTitle': 'Create Report',
      'reportTitle': 'Title',
      'reportTitleRequired': 'Title is required',
      'monthlyReport': 'Monthly Report',
      'yearlyReport': 'Yearly Report',
      'year': 'Year',
      'month': 'Month',
      'selectMonth': 'Select month',
      'pleaseSelectMonth': 'Please select a month',
      'summaryReportGenerated': 'Summary report generated successfully',
      'errorGeneratingSummaryReport': 'Error generating report',
      'reportCreated': 'Report created successfully',
      'reportUpdated': 'Report updated successfully',
      'errorCreatingReport': 'Error creating report',
      'errorUpdatingReport': 'Error updating report',
      'errorLoadingReport': 'Error loading report',
      'errorLoadingData': 'Error loading data',
      'failedToGetDepartment': 'Failed to get department',
      'reportGeneratedWithPath': 'Report generated successfully: {path}',
    },
    'es': {
      'appName': 'SysteMIC',
      'welcome': 'Bienvenido',
      'loading': 'Cargando...',
      'error': 'Error',
      'success': 'Éxito',
      'cancel': 'Cancelar',
      'confirm': 'Confirmar',
      'save': 'Guardar',
      'delete': 'Eliminar',
      'edit': 'Editar',
      'search': 'Buscar',
      'filter': 'Filtrar',
      'close': 'Cerrar',
      'login': 'Iniciar sesión',
      'logout': 'Cerrar sesión',
      'email': 'Correo electrónico',
      'password': 'Contraseña',
      'forgotPassword': '¿Olvidaste tu contraseña?',
      'signIn': 'Iniciar sesión',
      'signOut': 'Cerrar sesión',
      'emailRequired': 'El correo electrónico es obligatorio',
      'passwordRequired': 'La contraseña es obligatoria',
      'invalidEmail': 'Formato de correo electrónico inválido',
      'loginError': 'Error al iniciar sesión. Por favor, inténtalo de nuevo.',
      'dashboard': 'Panel de control',
      'home': 'Inicio',
      'overview': 'Resumen',
      'statistics': 'Estadísticas',
      'members': 'Miembros',
      'attendance': 'Asistencia',
      'giving': 'Ofrendas',
      'events': 'Eventos',
      'settings': 'Configuración',
      'profile': 'Perfil',
      'noData': 'No hay datos disponibles',
      'networkError': 'Error de red. Por favor, verifica tu conexión.',
      'genericError': 'Ocurrió un error. Por favor, inténtalo de nuevo.',
      // Error Messages
      'errorLoginFailed': 'Error al iniciar sesión. Verifica tus credenciales.',
      'errorEmailNotConfirmed': 'Por favor, confirma tu correo para continuar.',
      'errorUserNotFound': 'Usuario no encontrado.',
      'errorAccountCreationFailed': 'Error al crear la cuenta.',
      'errorDuplicateEmail': 'El correo ya está en uso.',
      'errorPermissionDenied': 'No tienes permiso para esta acción.',
      'errorOperationFailed': 'Operación fallida. Inténtalo de nuevo.',
      'errorInvalidCredentials': 'Correo o contraseña inválidos.',
      'errorPasswordResetFailed': 'Error al restablecer la contraseña.',
      'errorMustBeLoggedIn': 'Por favor, inicia sesión para continuar.',
      'errorAdminOrLeaderRequired':
          'Solo administradores o líderes pueden realizar esta acción.',
      'errorMemberNotFound': 'Miembro no encontrado.',
      'errorEmailOrPhoneRequired': 'Se requiere correo o teléfono.',
      'errorDepartmentNotFound': 'Departamento no encontrado.',
      'errorFailedToLoad': 'Error al cargar datos.',
      'errorFailedToSave': 'Error al guardar. Inténtalo de nuevo.',
      'errorFailedToDelete': 'Error al eliminar.',
      'errorFileUploadFailed': 'Error al subir archivo.',
      'errorInvalidInput': 'Entrada inválida. Verifica tus datos.',
      // Departments
      'addDepartment': 'Agregar Departamento',
      'editDepartment': 'Editar Departamento',
      'departmentName': 'Nombre del Departamento',
      'departmentNameRequired': 'El nombre del departamento es obligatorio',
      'departmentDescription': 'Descripción',
      'departmentCreated': 'Departamento creado exitosamente',
      'departmentUpdated': 'Departamento actualizado exitosamente',
      'departmentDeleted': 'Departamento eliminado exitosamente',
      'errorCreatingDepartment': 'Error al crear departamento',
      'errorUpdatingDepartment': 'Error al actualizar departamento',
      'errorDeletingDepartment': 'Error al eliminar departamento',
      'errorLoadingDepartments': 'Error al cargar departamentos',
      'noDepartments': 'Aún no hay departamentos',
      'noDepartmentsFound': 'No se encontraron departamentos',
      'searchDepartments': 'Buscar departamentos...',
      'departmentFiles': 'Archivos del Departamento',
      'noFilesUploaded': 'No hay archivos subidos',
      'documents': 'Documentos',
      'documentsOptional': 'Documentos (Opcional)',
      'document': 'Documento',
      'upload': 'Subir',
      'remove': 'Eliminar',
      'view': 'Ver',
      'newFile': 'Nuevo archivo',
      'deleteDepartment': 'Eliminar Departamento',
      'deleteDepartmentConfirm':
          '¿Estás seguro de que deseas eliminar este departamento? Esto lo desactivará.',
      'createDepartment': 'Crear Departamento',
      'updateDepartment': 'Actualizar Departamento',
      // Department Members
      'addMember': 'Agregar Miembro',
      'removeMember': 'Eliminar Miembro',
      'changeRole': 'Cambiar Rol',
      'role': 'Rol',
      'leader': 'Líder',
      'subleader': 'Sub-líder',
      'memberRole': 'Miembro',
      'selectRole': 'Seleccionar Rol',
      'memberAdded': 'Miembro agregado exitosamente',
      'memberRemoved': 'Miembro eliminado exitosamente',
      'roleUpdated': 'Rol actualizado exitosamente',
      'errorAddingMember': 'Error al agregar miembro',
      'errorRemovingMember': 'Error al eliminar miembro',
      'errorUpdatingRole': 'Error al actualizar rol',
      'errorLoadingMembers': 'Error al cargar miembros',
      'noMembersInDepartment': 'No hay miembros en este departamento',
      'allMembersInDepartment':
          'Todos los miembros ya están en este departamento',
      'removeMemberConfirm':
          '¿Estás seguro de que deseas eliminar a {name} de este departamento?',
      'deleteMember': 'Eliminar Miembro',
      'deleteMemberConfirmation':
          '¿Estás seguro de que deseas eliminar a {name}? Esta acción no se puede deshacer.',
      'memberDeletedSuccessfully': 'Miembro eliminado exitosamente',
      // Password Change
      'changePassword': 'Cambiar Contraseña',
      'changePasswordRequired': 'Cambio de Contraseña Requerido',
      'changePasswordMessage':
          'Debes cambiar tu contraseña antes de continuar.',
      'newPassword': 'Nueva Contraseña',
      'confirmPassword': 'Confirmar Nueva Contraseña',
      'newPasswordRequired': 'La nueva contraseña es obligatoria',
      'passwordMinLength': 'La contraseña debe tener al menos 6 caracteres',
      'passwordsDoNotMatch': 'Las contraseñas no coinciden',
      'passwordChanged': 'Contraseña cambiada exitosamente',
      'errorChangingPassword': 'Error al cambiar contraseña',
      // Tasks
      'manageTasks': 'Gestionar Tareas',
      'generateReport': 'Generar Reporte',
      'taskCompletion': 'Completación de Tareas',
      'total': 'Total',
      'completed': 'Completadas',
      'pending': 'Pendientes',
      'inProgress': 'En Progreso',
      'noTasks': 'No hay tareas en este departamento',
      // Reports
      'createReport': 'Crear Reporte',
      'generateSummaryReport': 'Generar Reporte Resumen',
      'noReports': 'Aún no hay reportes',
      'createFirstReport': 'Crea tu primer reporte para comenzar',
      'generatePdf': 'Generar PDF',
      'editReport': 'Editar',
      'deleteReport': 'Eliminar',
      'deleteReportConfirm': '¿Estás seguro de que deseas eliminar "{title}"?',
      'reportDeleted': 'Reporte eliminado exitosamente',
      'errorDeletingReport': 'Error al eliminar reporte',
      'reportGenerated': 'Reporte generado exitosamente',
      'errorGeneratingReport': 'Error al generar reporte',
      'generatingPdf': 'Generando PDF...',
      'generatingReport': 'Generando reporte...',
      'pdfGenerated': 'PDF generado exitosamente',
      // Common
      'refresh': 'Actualizar',
      'active': 'Activo',
      'inactive': 'Inactivo',
      'phone': 'Teléfono',
      'phoneOrEmail': 'Correo o Teléfono',
      'update': 'Actualizar',
      'add': 'Agregar',
      'name': 'Nombre',
      'nameRequired': 'El nombre es obligatorio',
      'successOperation': 'Operación completada exitosamente',
      'warning': 'Advertencia',
      'someDocumentsFailed':
          'Departamento creado, pero algunos documentos fallaron al subir',
      'documentUploadErrors': 'Errores al Subir Documentos',
      'documentsFailedMessage':
          'El departamento fue creado, pero los siguientes documentos fallaron al subir:',
      'canAddDocumentsLater':
          'Puedes agregar estos documentos más tarde editando el departamento.',
      'ok': 'OK',
      'optional': '(Opcional)',
      'enterDepartmentName': 'Ingresa el nombre del departamento',
      'optionalDescription': 'Descripción opcional para el departamento',
      // Teachings
      'teachings': 'Enseñanzas',
      'addTeaching': 'Agregar Enseñanza',
      'editTeaching': 'Editar Enseñanza',
      'teachingDetails': 'Detalles de la Enseñanza',
      'teachingTitle': 'Título',
      'teachingTitleRequired': 'Por favor ingresa un título',
      'teachingDate': 'Fecha de la Enseñanza',
      'teachingDateRequired': 'Por favor selecciona una fecha',
      'speaker': 'Orador',
      'teachingDescription': 'Descripción',
      'updateTeaching': 'Actualizar Enseñanza',
      'teachingAdded': 'Enseñanza agregada exitosamente',
      'teachingUpdated': 'Enseñanza actualizada exitosamente',
      'teachingDeleted': 'Enseñanza eliminada exitosamente',
      'errorLoadingTeaching': 'Error al cargar enseñanza',
      'errorDeletingTeaching': 'Error al eliminar enseñanza',
      'deleteTeachingConfirm':
          '¿Estás seguro de que deseas eliminar "{title}"?',
      'searchTeachings': 'Buscar enseñanzas...',
      'noTeachings': 'Aún no hay enseñanzas',
      'noTeachingsFound':
          'No se encontraron enseñanzas que coincidan con tu búsqueda',
      'listeners': 'Oyentes',
      'syncFromAttendance': 'Sincronizar desde Asistencia de la Iglesia',
      'searchPotentialListeners': 'Buscar oyentes potenciales...',
      'noListeners': 'Aún no hay oyentes',
      'addListener': 'Agregar',
      'addListenerTitle': 'Agregar Oyente',
      'removeListener': 'Eliminar Oyente',
      'removeListenerConfirm': '¿Eliminar "{name}" de los oyentes?',
      'listenerAdded': 'Oyente agregado exitosamente',
      'listenerRemoved': 'Oyente eliminado exitosamente',
      'errorAddingListener': 'Error al agregar oyente',
      'errorRemovingListener': 'Error al eliminar oyente',
      'errorSyncingListeners': 'Error al sincronizar oyentes',
      'listenersSynced':
          'Sincronizados {count} oyente(s) desde la asistencia de la iglesia',
      'allListenersAdded': 'Todos los oyentes potenciales ya están agregados',
      'useSyncOrAdd':
          'Usa "Sincronizar desde Asistencia de la Iglesia" o "Agregar" para agregar oyentes',
      // Visitors
      'visitors': 'Visitantes',
      'addVisitor': 'Agregar Visitante',
      'editVisitor': 'Editar Visitante',
      'updateVisitor': 'Actualizar Visitante',
      'visitorFirstName': 'Nombre',
      'visitorFirstNameRequired': 'El nombre es obligatorio',
      'visitorLastName': 'Apellido',
      'visitorLastNameRequired': 'El apellido es obligatorio',
      'visitDate': 'Fecha de Visita',
      'visitDateRequired': 'La fecha de visita es obligatoria',
      'visitorAdded': 'Visitante agregado exitosamente',
      'visitorUpdated': 'Visitante actualizado exitosamente',
      'visitorDeleted': 'Visitante eliminado exitosamente',
      'errorLoadingVisitor': 'Error al cargar visitante',
      'errorDeletingVisitor': 'Error al eliminar visitante',
      'deleteVisitorConfirm': '¿Estás seguro de que deseas eliminar "{name}"?',
      'searchVisitors': 'Buscar visitantes...',
      'noVisitors': 'Aún no hay visitantes',
      'noVisitorsFound':
          'No se encontraron visitantes que coincidan con tu búsqueda',
      'convertToMember': 'Convertir en miembro',
      'convertVisitorToMember': 'Convertir visitante en miembro',
      'convertVisitorToMemberConfirm':
          'Crear un perfil de miembro para "{name}" con los datos del visitante. El registro del visitante se eliminará.',
      'visitorConvertedToMember':
          'Visitante convertido en miembro exitosamente',
      'errorConvertingVisitor': 'Error al convertir visitante en miembro',
      // Workers & Departments
      'workers': 'Trabajadores',
      'searchWorkers': 'Buscar trabajadores...',
      'noWorkers': 'No se encontraron trabajadores',
      'noWorkersFound':
          'No se encontraron trabajadores que coincidan con tu búsqueda',
      'noDepartmentsAssigned': 'No hay departamentos asignados',
      'setMainDepartment': 'Establecer Departamento Principal',
      'setMainDepartmentFor': 'Establecer Departamento Principal para {name}',
      'workerNoDepartments': 'El trabajador no tiene departamentos asignados',
      'updatingMainDepartment': 'Actualizando departamento principal...',
      'mainDepartmentUpdated':
          'Departamento principal actualizado exitosamente',
      'errorUpdatingMainDepartment':
          'Error al actualizar departamento principal',
      // Leader Access
      'leaderAccessManagement': 'Gestión de Acceso de Líderes',
      'defineFeatureAccess': 'Definir acceso a funciones para cada líder',
      'featureAccessPermissions': 'Permisos de Acceso a Funciones',
      'unsavedChanges': 'Cambios sin guardar',
      'saveAllChanges': 'Guardar Todos los Cambios',
      'allAccessSaved': 'Todos los permisos de acceso guardados exitosamente',
      'errorSavingAccess': 'Error al guardar acceso',
      'errorLoadingLeaders': 'Error al cargar líderes',
      'errorLoadingAccess': 'Error al cargar acceso',
      'canView': 'Ver',
      'canCreate': 'Crear',
      'canEdit': 'Editar',
      'canDelete': 'Eliminar',
      // Settings
      'adminSettings': 'Configuración de Administrador',
      'language': 'Idioma',
      'theme': 'Tema',
      'enableNotifications': 'Habilitar Notificaciones',
      'receivePushNotifications': 'Recibir notificaciones push',
      'exportAllData': 'Exportar Todos los Datos',
      'exportAllDataSubtitle': 'Exportar todos los datos a archivo JSON',
      'importData': 'Importar Datos',
      'importDataSubtitle': 'Importar datos desde archivo JSON',
      'exportMembers': 'Exportar Miembros',
      'exportMembersSubtitle': 'Exportar miembros a CSV',
      'syncUsersMembers': 'Sincronizar Usuarios y Miembros',
      'generateAllUsersReport': 'Generar Reporte de Todos los Usuarios',
      'birthdayNotifications': 'Notificaciones de Cumpleaños',
      'configureBirthdayNotifications':
          'Configurar ajustes de notificaciones de cumpleaños',
      'currentUser': 'Usuario Actual',
      'signOutAccount': 'Cerrar sesión de tu cuenta',
      'appVersion': 'Versión de la App',
      'logoutConfirm': '¿Estás seguro de que deseas cerrar sesión?',
      'languageChanged': 'Idioma cambiado exitosamente',
      'errorChangingLanguage': 'Error al cambiar idioma',
      'themeChanged': 'Tema cambiado exitosamente',
      'errorChangingTheme': 'Error al cambiar tema',
      'errorUpdatingNotifications': 'Error al actualizar notificaciones',
      'notificationsEnabled': 'Notificaciones habilitadas',
      'notificationsDisabled': 'Notificaciones deshabilitadas',
      'exportAllDataConfirm':
          'Esto exportará todos los miembros, departamentos, clases, eventos y tareas a un archivo JSON. Se te pedirá que selecciones una ubicación de guardado. ¿Continuar?',
      'syncUsersMembersConfirm':
          'Esto:\n1. Creará un miembro para cada usuario\n2. Creará un usuario (con contraseña predeterminada "Password123") para cada miembro líder\n\nLos líderes deberán cambiar su contraseña en el primer inicio de sesión.\n\n¿Continuar?',
      'syncCompleted': '¡Sincronización completada!',
      'usersToMembers': 'Usuarios → Miembros',
      'leadersToUsers': 'Líderes → Usuarios',
      'createdLabel': 'creados',
      'skippedLabel': 'omitidos',
      'errorsLabel': 'errores',
      'importDataConfirm':
          'Esto importará datos desde un archivo JSON. Los miembros existentes con el mismo correo electrónico serán omitidos. ¿Continuar?',
      'importCompleted': 'Importación completada',
      'importedLabel': 'Importados',
      'notLoggedIn': 'No has iniciado sesión',
      'logoutFailed': 'Error al cerrar sesión',
      'languageAndRegion': 'Idioma y Región',
      'appearance': 'Apariencia',
      'dataManagement': 'Gestión de Datos',
      'about': 'Acerca de',
      'generateReportComprehensive':
          'Generar reporte completo para todos los usuarios',
      'export': 'Exportar',
      'importing': 'Importando datos...',
      'exporting': 'Exportando datos...',
      'dataExported': 'Datos exportados exitosamente a:\n{path}',
      'exportCancelled': 'Exportación cancelada',
      'exportFailed': 'Error en la exportación',
      'membersExported': 'Miembros exportados exitosamente',
      'sync': 'Sincronizar',
      'syncing': 'Sincronizando usuarios y miembros...',
      'syncFailed': 'Error en la sincronización',
      'reportSaved': 'Reporte guardado exitosamente en:\n{path}',
      'reportGenerationCancelled': 'Generación de reporte cancelada',
      'reportGenerationFailed': 'Error en la generación del reporte',
      'import': 'Importar',
      'importFailed': 'Error en la importación',
      'english': 'Inglés',
      'french': 'Francés',
      'selectTheme': 'Seleccionar Tema',
      'light': 'Claro',
      'dark': 'Oscuro',
      'systemDefault': 'Predeterminado del Sistema',
      'birthdayNotificationsSettings': 'Notificaciones de Cumpleaños',
      'allChurchAppUsers': 'Todos los Usuarios de la App de la Iglesia',
      'defaultAllActiveMembers': 'Predeterminado: Todos los miembros activos',
      'leadersOnly': 'Solo Líderes',
      'onlyDepartmentLeadersAdmins':
          'Solo líderes de departamento y administradores',
      'optOutNoNotifications': 'Optar por No Recibir (Sin Notificaciones)',
      'usersCanOptIn': 'Los usuarios pueden optar individualmente',
      'note': 'Nota',
      'saveSettings': 'Guardar Configuración',
      'settingsSaved': 'Configuración guardada exitosamente',
      'errorSavingConfig': 'Error al guardar configuración',
      'errorLoadingConfig': 'Error al cargar configuración',
      // Events
      'addEvent': 'Agregar Evento',
      'editEvent': 'Editar Evento',
      'deleteEvent': 'Eliminar Evento',
      'eventDeleted': 'Evento eliminado exitosamente',
      'errorDeletingEvent': 'Error al eliminar evento',
      'deleteEventConfirm': '¿Estás seguro de que deseas eliminar "{title}"?',
      'searchEvents': 'Buscar eventos...',
      'noEvents': 'Aún no hay eventos',
      'noEventsFound':
          'No se encontraron eventos que coincidan con tu búsqueda',
      // Church Attendance
      'churchAttendance': 'Asistencia de la Iglesia',
      'sundaySchool': 'Escuela Dominical',
      'churchAttendanceReportPdfTitle': 'Informe de asistencia a la iglesia',
      'churchAttendanceReportPdfIntro':
          'Este informe está organizado por mes natural. Cada mes incluye una tabla de miembros (Presente / Ausente / En línea por culto) y gráficos mensuales de resumen. La última columna queda en blanco para notas.',
      'churchAttendanceReportPdfDiligenceNote':
          'Asistencia constante: ≥{d}% presente = Constante; ≥{m}% = Moderadamente constante; por debajo = No constante. Presente = presencial + en línea, denominador = número de cultos programados en el mes.',
      'attendanceReportFullName': 'Nombre completo',
      'attendanceReportOnsiteTotal': 'Presencial (total)',
      'attendanceReportOnlineTotal': 'En línea (total)',
      'attendanceReportTotalPresent': 'Total presentes',
      'attendanceReportObservation': 'Observación',
      'attendanceReportSpecificObservations': 'Observaciones específicas',
      'attendanceReportPresentAbbr': 'P',
      'attendanceReportAbsentAbbr': 'A',
      'attendanceReportOnlineAbbr': 'O',
      'attendanceReportOnsite': 'Presencial',
      'attendanceReportOnline': 'En línea',
      'attendanceReportAbsent': 'Ausente',
      'attendanceReportVisitor': 'Visitante',
      'attendanceReportVisitorsSection': 'Visitantes',
      'attendanceReportChildTag': 'Niño',
      'attendanceReportNewComerTag': 'Nuevo',
      'attendanceReportMembersSection': 'Miembros',
      'attendanceReportMonthlySummaryTitle':
          'Asistencia mensual (suma de presentes)',
      'attendanceReportPresenceChartsSection': 'Presencia mensual',
      'attendanceReportSundayMonthlyPresenceChart':
          'Domingo — presentes por culto',
      'attendanceReportWednesdayMonthlyPresenceChart':
          'Miércoles — presentes por culto',
      'attendanceReportTotalMonthlyPresenceChart':
          'Presencia total — por fecha de culto (cronológico)',
      'attendanceReportSundayMonthTotal': 'Domingo (mes)',
      'attendanceReportWednesdayMonthTotal': 'Miércoles (mes)',
      'attendanceReportAllServicesMonthTotal': 'Todos los cultos (mes)',
      'attendanceReportChartNoData': 'Sin datos',
      'attendanceReportDiligent': 'Constante',
      'attendanceReportModeratelyDiligent': 'Moderadamente constante',
      'attendanceReportNotDiligent': 'No constante',
      'attendanceReportSundayShort': 'Dom',
      'attendanceReportWednesdayShort': 'Mié',
      'churchAttendanceReportPdfGenerated': 'Generado',
      'churchAttendanceReportPdfPeriod': 'Período',
      'churchAttendanceReportPdfServiceFilter': 'Tipo de culto',
      'churchAttendanceReportPdfSundayService': 'Culto dominical',
      'churchAttendanceReportPdfWednesdayService': 'Culto de miércoles',
      // Reports
      'trainingReport': 'Reporte de Entrenamiento',
      'memberReport': 'Reporte de Miembro',
      'updateReport': 'Actualizar Reporte',
      'createReportTitle': 'Crear Reporte',
      'reportTitle': 'Título',
      'reportTitleRequired': 'El título es obligatorio',
      'monthlyReport': 'Reporte Mensual',
      'yearlyReport': 'Reporte Anual',
      'year': 'Año',
      'month': 'Mes',
      'selectMonth': 'Seleccionar mes',
      'pleaseSelectMonth': 'Por favor selecciona un mes',
      'summaryReportGenerated': 'Reporte resumen generado exitosamente',
      'errorGeneratingSummaryReport': 'Error al generar reporte',
      'reportCreated': 'Reporte creado exitosamente',
      'reportUpdated': 'Reporte actualizado exitosamente',
      'errorCreatingReport': 'Error al crear reporte',
      'errorUpdatingReport': 'Error al actualizar reporte',
      'errorLoadingReport': 'Error al cargar reporte',
      'errorLoadingData': 'Error al cargar datos',
      'failedToGetDepartment': 'Error al obtener departamento',
      'reportGeneratedWithPath': 'Reporte generado exitosamente: {path}',
    
      // Filled missing Spanish keys
      'tasks': 'Tareas',
      'departments': 'Departamentos',
      'notifications': 'Notificaciones',
      'finance': 'Finanzas',
      'reports': 'Informes',
      'chat': 'Chat',
      'birthdays': 'Cumpleaños',
      'classes': 'Formaciones',
      'quickActions': 'Acciones rápidas',
      'account': 'Cuenta',
      'other': 'Otros',
      'member': 'Miembro',
},
    'fr': {
      'appName': 'SysteMIC',
      'welcome': 'Bienvenue',
      'loading': 'Chargement...',
      'error': 'Erreur',
      'success': 'Succès',
      'cancel': 'Annuler',
      'confirm': 'Confirmer',
      'save': 'Enregistrer',
      'delete': 'Supprimer',
      'edit': 'Modifier',
      'search': 'Rechercher',
      'filter': 'Filtrer',
      'close': 'Fermer',
      'login': 'Connexion',
      'logout': 'Déconnexion',
      'email': 'E-mail',
      'password': 'Mot de passe',
      'forgotPassword': 'Mot de passe oublié?',
      'signIn': 'Se connecter',
      'signOut': 'Se déconnecter',
      'emailRequired': 'L\'e-mail est requis',
      'passwordRequired': 'Le mot de passe est requis',
      'invalidEmail': 'Format d\'e-mail invalide',
      'loginError': 'Échec de la connexion. Veuillez réessayer.',
      'dashboard': 'Tableau de bord',
      'home': 'Accueil',
      'overview': 'Aperçu',
      'statistics': 'Statistiques',
      'members': 'Membres',
      'attendance': 'Présence',
      'giving': 'Dons',
      'events': 'Événements',
      'settings': 'Paramètres',
      'notifications': 'Notifications',
      'profile': 'Profil',
      'noData': 'Aucune donnée disponible',
      'networkError': 'Erreur réseau. Veuillez vérifier votre connexion.',
      'genericError': 'Une erreur s\'est produite. Veuillez réessayer.',
      // Finance
      'finance': 'Finance',
      'addGivingRecord': 'Ajouter un enregistrement de don',
      'givingRecord': 'Enregistrement de don',
      'givingRecordDetails': 'Détails de l\'enregistrement de don',
      'transactionType': 'Type de transaction',
      'receiving': 'Réception',
      'expense': 'Dépense',
      'giverType': 'Type de donneur',
      'member': 'Membre',
      'externalPerson': 'Personne externe',
      'giverName': 'Nom du donneur',
      'selectMember': 'Sélectionner un membre',
      'amount': 'Montant',
      'tag': 'Étiquette',
      'notes': 'Notes',
      'description': 'Description',
      'date': 'Date',
      'category': 'Catégorie',
      'created': 'Créé',
      'lastUpdated': 'Dernière mise à jour',
      'recordInformation': 'Informations sur l\'enregistrement',
      'transactionDetails': 'Détails de la transaction',
      'noGivingRecords': 'Aucun enregistrement de don pour le moment',
      'addFirstRecord': 'Ajouter le premier enregistrement',
      'givingRecordCreated': 'Enregistrement de don créé avec succès',
      'givingRecordUpdated': 'Enregistrement de don mis à jour avec succès',
      'givingRecordNotFound': 'Enregistrement de don introuvable',
      'errorLoadingGivingRecord':
          'Erreur lors du chargement de l\'enregistrement de don',
      'giverNameRequired': 'Le nom du donneur est requis',
      'pleaseSelectTag': 'Veuillez sélectionner une étiquette',
      'amountRequired': 'Le montant est requis',
      'validAmountRequired':
          'Veuillez entrer un montant valide supérieur à zéro',
      'createExpense': 'Créer une dépense',
      'createReceivingRecord': 'Créer un enregistrement de réception',
      'saveChanges': 'Enregistrer les modifications',
      'recordCanBeEdited':
          'Cet enregistrement peut être modifié. Les modifications seront enregistrées immédiatement.',
      'recordCannotBeEdited':
          'Cet enregistrement a été créé il y a plus de 2 jours et ne peut pas être modifié.',
      'errorLoadingGivingRecords':
          'Erreur lors du chargement des enregistrements de don',
      // Tag labels
      'construction': 'Construction',
      'specialOperation': 'Opération spéciale',
      'tithe': 'Dîme',
      'offering': 'Offrande',
      'gift': 'Cadeau',
      'other': 'Autre',
      // Dashboard
      'upcomingSessions': 'Sessions à venir',
      'upcomingEvents': 'Événements à venir',
      'tasks': 'Tâches',
      'birthdays': 'Anniversaires',
      'quickActions': 'Actions rapides',
      'departments': 'Départements',
      'classes': 'Trainings',
      'reports': 'Rapports',
      'chat': 'Chat',
      'errorLoadingDashboard': 'Erreur lors du chargement du tableau de bord',
      // Error Messages
      'errorLoginFailed': 'Échec de la connexion. Vérifiez vos identifiants.',
      'errorEmailNotConfirmed':
          'Veuillez confirmer votre e-mail pour continuer.',
      'errorUserNotFound': 'Utilisateur introuvable.',
      'errorAccountCreationFailed': 'Échec de la création du compte.',
      'errorDuplicateEmail': 'L\'e-mail est déjà utilisé.',
      'errorPermissionDenied':
          'Vous n\'avez pas la permission pour cette action.',
      'errorOperationFailed': 'Opération échouée. Veuillez réessayer.',
      'errorInvalidCredentials': 'E-mail ou mot de passe invalide.',
      'errorPasswordResetFailed':
          'Échec de la réinitialisation du mot de passe.',
      'errorMustBeLoggedIn': 'Veuillez vous connecter pour continuer.',
      'errorAdminOrLeaderRequired':
          'Seuls les administrateurs ou les dirigeants peuvent effectuer cette action.',
      'errorMemberNotFound': 'Membre introuvable.',
      'errorEmailOrPhoneRequired': 'E-mail ou téléphone requis.',
      'errorDepartmentNotFound': 'Département introuvable.',
      'errorFailedToLoad': 'Échec du chargement des données.',
      'errorFailedToSave': 'Échec de l\'enregistrement. Veuillez réessayer.',
      'errorFailedToDelete': 'Échec de la suppression.',
      'errorFileUploadFailed': 'Échec du téléchargement du fichier.',
      'errorInvalidInput': 'Entrée invalide. Vérifiez vos données.',
      // Departments
      'addDepartment': 'Ajouter un Département',
      'editDepartment': 'Modifier le Département',
      'departmentName': 'Nom du Département',
      'departmentNameRequired': 'Le nom du département est requis',
      'departmentDescription': 'Description',
      'departmentCreated': 'Département créé avec succès',
      'departmentUpdated': 'Département mis à jour avec succès',
      'departmentDeleted': 'Département supprimé avec succès',
      'errorCreatingDepartment': 'Échec de la création du département',
      'errorUpdatingDepartment': 'Échec de la mise à jour du département',
      'errorDeletingDepartment': 'Échec de la suppression du département',
      'errorLoadingDepartments': 'Échec du chargement des départements',
      'noDepartments': 'Aucun département pour le moment',
      'noDepartmentsFound': 'Aucun département trouvé',
      'searchDepartments': 'Rechercher des départements...',
      'departmentFiles': 'Fichiers du Département',
      'noFilesUploaded': 'Aucun fichier téléchargé',
      'documents': 'Documents',
      'documentsOptional': 'Documents (Optionnel)',
      'document': 'Document',
      'upload': 'Télécharger',
      'remove': 'Supprimer',
      'view': 'Voir',
      'newFile': 'Nouveau fichier',
      'deleteDepartment': 'Supprimer le Département',
      'deleteDepartmentConfirm':
          'Êtes-vous sûr de vouloir supprimer ce département? Cela le désactivera.',
      'createDepartment': 'Créer un Département',
      'updateDepartment': 'Mettre à jour le Département',
      // Department Members
      'addMember': 'Ajouter un Membre',
      'removeMember': 'Retirer un Membre',
      'changeRole': 'Changer le Rôle',
      'role': 'Rôle',
      'leader': 'Dirigeant',
      'subleader': 'Sous-dirigeant',
      'memberRole': 'Membre',
      'selectRole': 'Sélectionner un Rôle',
      'memberAdded': 'Membre ajouté avec succès',
      'memberRemoved': 'Membre retiré avec succès',
      'roleUpdated': 'Rôle mis à jour avec succès',
      'errorAddingMember': 'Échec de l\'ajout du membre',
      'errorRemovingMember': 'Échec du retrait du membre',
      'errorUpdatingRole': 'Échec de la mise à jour du rôle',
      'noMembersInDepartment': 'Aucun membre dans ce département',
      'allMembersInDepartment':
          'Tous les membres sont déjà dans ce département',
      'removeMemberConfirm':
          'Êtes-vous sûr de vouloir retirer {name} de ce département?',
      'deleteMember': 'Supprimer le Membre',
      'deleteMemberConfirmation':
          'Êtes-vous sûr de vouloir supprimer {name}? Cette action ne peut pas être annulée.',
      'memberDeletedSuccessfully': 'Membre supprimé avec succès',
      // Password Change
      'changePassword': 'Changer le Mot de Passe',
      'changePasswordRequired': 'Changement de Mot de Passe Requis',
      'changePasswordMessage':
          'Vous devez changer votre mot de passe avant de continuer.',
      'newPassword': 'Nouveau Mot de Passe',
      'confirmPassword': 'Confirmer le Nouveau Mot de Passe',
      'newPasswordRequired': 'Le nouveau mot de passe est requis',
      'passwordMinLength':
          'Le mot de passe doit contenir au moins 6 caractères',
      'passwordsDoNotMatch': 'Les mots de passe ne correspondent pas',
      'passwordChanged': 'Mot de passe changé avec succès',
      'errorChangingPassword': 'Échec du changement de mot de passe',
      // Tasks
      'manageTasks': 'Gérer les Tâches',
      'generateReport': 'Générer un Rapport',
      'taskCompletion': 'Achèvement des Tâches',
      'total': 'Total',
      'completed': 'Terminées',
      'pending': 'En Attente',
      'inProgress': 'En Cours',
      'noTasks': 'Aucune tâche dans ce département',
      // Reports
      'createReport': 'Créer un Rapport',
      'generateSummaryReport': 'Générer un Rapport Résumé',
      'noReports': 'Aucun rapport pour le moment',
      'createFirstReport': 'Créez votre premier rapport pour commencer',
      'generatePdf': 'Générer un PDF',
      'editReport': 'Modifier',
      'deleteReport': 'Supprimer',
      'deleteReportConfirm': 'Êtes-vous sûr de vouloir supprimer "{title}"?',
      'reportDeleted': 'Rapport supprimé avec succès',
      'errorDeletingReport': 'Échec de la suppression du rapport',
      'reportGenerated': 'Rapport généré avec succès',
      'errorGeneratingReport': 'Échec de la génération du rapport',
      'generatingPdf': 'Génération du PDF...',
      'generatingReport': 'Génération du rapport...',
      'pdfGenerated': 'PDF généré avec succès',
      // Common
      'refresh': 'Actualiser',
      'active': 'Actif',
      'inactive': 'Inactif',
      'phone': 'Téléphone',
      'phoneOrEmail': 'E-mail ou Téléphone',
      'update': 'Mettre à jour',
      'add': 'Ajouter',
      'name': 'Nom',
      'nameRequired': 'Le nom est requis',
      'successOperation': 'Opération terminée avec succès',
      'warning': 'Avertissement',
      'someDocumentsFailed':
          'Département créé, mais certains documents n\'ont pas pu être téléchargés',
      'documentUploadErrors': 'Erreurs de Téléchargement de Documents',
      'documentsFailedMessage':
          'Le département a été créé, mais les documents suivants n\'ont pas pu être téléchargés:',
      'canAddDocumentsLater':
          'Vous pouvez ajouter ces documents plus tard en modifiant le département.',
      'ok': 'OK',
      'optional': '(Optionnel)',
      'enterDepartmentName': 'Entrez le nom du département',
      'optionalDescription': 'Description optionnelle pour le département',
      // Teachings
      'teachings': 'Enseignements',
      'addTeaching': 'Ajouter un Enseignement',
      'editTeaching': 'Modifier l\'Enseignement',
      'teachingDetails': 'Détails de l\'Enseignement',
      'teachingTitle': 'Titre',
      'teachingTitleRequired': 'Veuillez entrer un titre',
      'teachingDate': 'Date de l\'Enseignement',
      'teachingDateRequired': 'Veuillez sélectionner une date',
      'speaker': 'Orateur',
      'teachingDescription': 'Description',
      'updateTeaching': 'Mettre à jour l\'Enseignement',
      'teachingAdded': 'Enseignement ajouté avec succès',
      'teachingUpdated': 'Enseignement mis à jour avec succès',
      'teachingDeleted': 'Enseignement supprimé avec succès',
      'errorLoadingTeaching': 'Erreur lors du chargement de l\'enseignement',
      'errorDeletingTeaching':
          'Erreur lors de la suppression de l\'enseignement',
      'deleteTeachingConfirm': 'Êtes-vous sûr de vouloir supprimer "{title}"?',
      'searchTeachings': 'Rechercher des enseignements...',
      'noTeachings': 'Aucun enseignement pour le moment',
      'noTeachingsFound':
          'Aucun enseignement trouvé correspondant à votre recherche',
      'listeners': 'Auditeurs',
      'syncFromAttendance': 'Synchroniser depuis l\'Assistance de l\'Église',
      'searchPotentialListeners': 'Rechercher des auditeurs potentiels...',
      'noListeners': 'Aucun auditeur pour le moment',
      'addListener': 'Ajouter',
      'addListenerTitle': 'Ajouter un Auditeur',
      'removeListener': 'Retirer un Auditeur',
      'removeListenerConfirm': 'Retirer "{name}" des auditeurs?',
      'listenerAdded': 'Auditeur ajouté avec succès',
      'listenerRemoved': 'Auditeur retiré avec succès',
      'errorAddingListener': 'Erreur lors de l\'ajout de l\'auditeur',
      'errorRemovingListener': 'Erreur lors du retrait de l\'auditeur',
      'errorSyncingListeners':
          'Erreur lors de la synchronisation des auditeurs',
      'listenersSynced':
          'Synchronisés {count} auditeur(s) depuis l\'assistance de l\'église',
      'allListenersAdded': 'Tous les auditeurs potentiels sont déjà ajoutés',
      'useSyncOrAdd':
          'Utilisez "Synchroniser depuis l\'Assistance de l\'Église" ou "Ajouter" pour ajouter des auditeurs',
      // Visitors
      'visitors': 'Visiteurs',
      'addVisitor': 'Ajouter un Visiteur',
      'editVisitor': 'Modifier le Visiteur',
      'updateVisitor': 'Mettre à jour le Visiteur',
      'visitorFirstName': 'Prénom',
      'visitorFirstNameRequired': 'Le prénom est requis',
      'visitorLastName': 'Nom de famille',
      'visitorLastNameRequired': 'Le nom de famille est requis',
      'visitDate': 'Date de Visite',
      'visitDateRequired': 'La date de visite est requise',
      'visitorAdded': 'Visiteur ajouté avec succès',
      'visitorUpdated': 'Visiteur mis à jour avec succès',
      'visitorDeleted': 'Visiteur supprimé avec succès',
      'errorLoadingVisitor': 'Erreur lors du chargement du visiteur',
      'errorDeletingVisitor': 'Erreur lors de la suppression du visiteur',
      'deleteVisitorConfirm': 'Êtes-vous sûr de vouloir supprimer "{name}"?',
      'searchVisitors': 'Rechercher des visiteurs...',
      'noVisitors': 'Aucun visiteur pour le moment',
      'noVisitorsFound':
          'Aucun visiteur trouvé correspondant à votre recherche',
      'convertToMember': 'Convertir en membre',
      'convertVisitorToMember': 'Convertir le visiteur en membre',
      'convertVisitorToMemberConfirm':
          'Créer un profil membre pour "{name}" avec les coordonnées du visiteur. Le dossier visiteur sera supprimé.',
      'visitorConvertedToMember': 'Visiteur converti en membre avec succès',
      'errorConvertingVisitor':
          'Erreur lors de la conversion du visiteur en membre',
      // Workers & Departments
      'workers': 'Travailleurs',
      'searchWorkers': 'Rechercher des travailleurs...',
      'noWorkers': 'Aucun travailleur trouvé',
      'noWorkersFound':
          'Aucun travailleur trouvé correspondant à votre recherche',
      'noDepartmentsAssigned': 'Aucun département assigné',
      'setMainDepartment': 'Définir le Département Principal',
      'setMainDepartmentFor': 'Définir le Département Principal pour {name}',
      'workerNoDepartments': 'Le travailleur n\'a aucun département assigné',
      'updatingMainDepartment': 'Mise à jour du département principal...',
      'mainDepartmentUpdated': 'Département principal mis à jour avec succès',
      'errorUpdatingMainDepartment':
          'Erreur lors de la mise à jour du département principal',
      // Leader Access
      'leaderAccessManagement': 'Gestion de l\'Accès des Dirigeants',
      'defineFeatureAccess':
          'Définir l\'accès aux fonctionnalités pour chaque dirigeant',
      'featureAccessPermissions': 'Permissions d\'Accès aux Fonctionnalités',
      'unsavedChanges': 'Modifications non enregistrées',
      'saveAllChanges': 'Enregistrer Toutes les Modifications',
      'allAccessSaved':
          'Toutes les permissions d\'accès enregistrées avec succès',
      'errorSavingAccess': 'Erreur lors de l\'enregistrement de l\'accès',
      'errorLoadingLeaders': 'Erreur lors du chargement des dirigeants',
      'errorLoadingAccess': 'Erreur lors du chargement de l\'accès',
      'canView': 'Voir',
      'canCreate': 'Créer',
      'canEdit': 'Modifier',
      'canDelete': 'Supprimer',
      // Settings
      'adminSettings': 'Paramètres d\'Administrateur',
      'language': 'Langue',
      'theme': 'Thème',
      'enableNotifications': 'Activer les Notifications',
      'receivePushNotifications': 'Recevoir les notifications push',
      'exportAllData': 'Exporter Toutes les Données',
      'exportAllDataSubtitle':
          'Exporter toutes les données vers un fichier JSON',
      'importData': 'Importer des Données',
      'importDataSubtitle': 'Importer des données depuis un fichier JSON',
      'exportMembers': 'Exporter les Membres',
      'exportMembersSubtitle': 'Exporter les membres vers CSV',
      'syncUsersMembers': 'Synchroniser les Utilisateurs et Membres',
      'generateAllUsersReport': 'Générer un Rapport de Tous les Utilisateurs',
      'birthdayNotifications': 'Notifications d\'Anniversaire',
      'configureBirthdayNotifications':
          'Configurer les paramètres de notifications d\'anniversaire',
      'currentUser': 'Utilisateur Actuel',
      'signOutAccount': 'Se déconnecter de votre compte',
      'appVersion': 'Version de l\'App',
      'logoutConfirm': 'Êtes-vous sûr de vouloir vous déconnecter?',
      'languageChanged': 'Langue changée avec succès',
      'errorChangingLanguage': 'Échec du changement de langue',
      'themeChanged': 'Thème changé avec succès',
      'errorChangingTheme': 'Échec du changement de thème',
      'errorUpdatingNotifications': 'Échec de la mise à jour des notifications',
      'notificationsEnabled': 'Notifications activées',
      'notificationsDisabled': 'Notifications désactivées',
      'exportAllDataConfirm':
          'Cela exportera tous les membres, départements, classes, événements et tâches vers un fichier JSON. Il vous sera demandé de sélectionner un emplacement de sauvegarde. Continuer?',
      'syncUsersMembersConfirm':
          'Cela:\n1. Créera un membre pour chaque utilisateur\n2. Créera un utilisateur (avec mot de passe par défaut "Password123") pour chaque membre dirigeant\n\nLes dirigeants devront changer leur mot de passe lors de la première connexion.\n\nContinuer?',
      'syncCompleted': 'Synchronisation terminée!',
      'usersToMembers': 'Utilisateurs → Membres',
      'leadersToUsers': 'Dirigeants → Utilisateurs',
      'createdLabel': 'créés',
      'skippedLabel': 'ignorés',
      'errorsLabel': 'erreurs',
      'importDataConfirm':
          'Cela importera des données depuis un fichier JSON. Les membres existants avec le même e-mail seront ignorés. Continuer?',
      'importCompleted': 'Importation terminée',
      'importedLabel': 'Importés',
      'notLoggedIn': 'Non connecté',
      'logoutFailed': 'Échec de la déconnexion',
      'languageAndRegion': 'Langue et Région',
      'appearance': 'Apparence',
      'dataManagement': 'Gestion des Données',
      'about': 'À propos',
      'generateReportComprehensive':
          'Générer un rapport complet pour tous les utilisateurs',
      'account': 'Compte',
      'export': 'Exporter',
      'importing': 'Importation des données...',
      'exporting': 'Exportation des données...',
      'dataExported': 'Données exportées avec succès vers:\n{path}',
      'exportCancelled': 'Exportation annulée',
      'exportFailed': 'Échec de l\'exportation',
      'membersExported': 'Membres exportés avec succès',
      'sync': 'Synchroniser',
      'syncing': 'Synchronisation des utilisateurs et membres...',
      'syncFailed': 'Échec de la synchronisation',
      'reportSaved': 'Rapport enregistré avec succès vers:\n{path}',
      'reportGenerationCancelled': 'Génération du rapport annulée',
      'reportGenerationFailed': 'Échec de la génération du rapport',
      'import': 'Importer',
      'importFailed': 'Échec de l\'importation',
      'english': 'Anglais',
      'french': 'Français',
      'selectTheme': 'Sélectionner un Thème',
      'light': 'Clair',
      'dark': 'Sombre',
      'systemDefault': 'Par Défaut du Système',
      'birthdayNotificationsSettings': 'Notifications d\'Anniversaire',
      'allChurchAppUsers': 'Tous les Utilisateurs de l\'App de l\'Église',
      'defaultAllActiveMembers': 'Par défaut: Tous les membres actifs',
      'leadersOnly': 'Dirigeants Uniquement',
      'onlyDepartmentLeadersAdmins':
          'Seulement les dirigeants de département et administrateurs',
      'optOutNoNotifications': 'Désactivation (Aucune Notification)',
      'usersCanOptIn': 'Les utilisateurs peuvent s\'inscrire individuellement',
      'note': 'Note',
      'saveSettings': 'Enregistrer les Paramètres',
      'settingsSaved': 'Paramètres enregistrés avec succès',
      'errorSavingConfig':
          'Erreur lors de l\'enregistrement de la configuration',
      'errorLoadingConfig': 'Erreur lors du chargement de la configuration',
      // Events
      'addEvent': 'Ajouter un Événement',
      'editEvent': 'Modifier l\'Événement',
      'deleteEvent': 'Supprimer l\'Événement',
      'eventDeleted': 'Événement supprimé avec succès',
      'errorDeletingEvent': 'Erreur lors de la suppression de l\'événement',
      'deleteEventConfirm': 'Êtes-vous sûr de vouloir supprimer "{title}"?',
      'searchEvents': 'Rechercher des événements...',
      'noEvents': 'Aucun événement pour le moment',
      'noEventsFound': 'Aucun événement trouvé correspondant à votre recherche',
      // Church Attendance
      'churchAttendance': 'Assistance de l\'Église',
      'sundaySchool': 'École du Dimanche',
      'churchAttendanceReportPdfTitle': 'Rapport de présence au culte',
      'churchAttendanceReportPdfIntro':
          'Ce rapport est organisé par mois civil. Chaque mois comprend un tableau des membres (Présent / Absent / En ligne par culte) et des graphiques de synthèse mensuels. La dernière colonne est laissée vide pour les notes.',
      'churchAttendanceReportPdfDiligenceNote':
          'Assiduité : ≥{d}% de présences = Assidu ; ≥{m}% = Modérément assidu ; en dessous = Peu assidu. Présent = sur place + en ligne, dénominateur = nombre de cultes prévus dans le mois.',
      'attendanceReportFullName': 'Nom complet',
      'attendanceReportOnsiteTotal': 'Sur place (total)',
      'attendanceReportOnlineTotal': 'En ligne (total)',
      'attendanceReportTotalPresent': 'Total présences',
      'attendanceReportObservation': 'Observation',
      'attendanceReportSpecificObservations': 'Observations spécifiques',
      'attendanceReportPresentAbbr': 'P',
      'attendanceReportAbsentAbbr': 'A',
      'attendanceReportOnlineAbbr': 'O',
      'attendanceReportOnsite': 'Sur place',
      'attendanceReportOnline': 'En ligne',
      'attendanceReportAbsent': 'Absent',
      'attendanceReportVisitor': 'Visiteur',
      'attendanceReportVisitorsSection': 'Visiteurs',
      'attendanceReportChildTag': 'Enfant',
      'attendanceReportNewComerTag': 'Nouveau',
      'attendanceReportMembersSection': 'Membres',
      'attendanceReportMonthlySummaryTitle':
          'Présence mensuelle (somme des présences)',
      'attendanceReportPresenceChartsSection': 'Présence mensuelle',
      'attendanceReportSundayMonthlyPresenceChart':
          'Dimanche — présents par culte',
      'attendanceReportWednesdayMonthlyPresenceChart':
          'Mercredi — présents par culte',
      'attendanceReportTotalMonthlyPresenceChart':
          'Présence totale — par date de culte (chronologique)',
      'attendanceReportSundayMonthTotal': 'Dimanche (mois)',
      'attendanceReportWednesdayMonthTotal': 'Mercredi (mois)',
      'attendanceReportAllServicesMonthTotal': 'Tous les cultes (mois)',
      'attendanceReportChartNoData': 'Aucune donnée',
      'attendanceReportDiligent': 'Assidu',
      'attendanceReportModeratelyDiligent': 'Modérément assidu',
      'attendanceReportNotDiligent': 'Peu assidu',
      'attendanceReportSundayShort': 'Dim',
      'attendanceReportWednesdayShort': 'Mer',
      'churchAttendanceReportPdfGenerated': 'Généré',
      'churchAttendanceReportPdfPeriod': 'Période',
      'churchAttendanceReportPdfServiceFilter': 'Type de culte',
      'churchAttendanceReportPdfSundayService': 'Culte du dimanche',
      'churchAttendanceReportPdfWednesdayService': 'Culte du mercredi',
      // Reports
      'trainingReport': 'Rapport de Formation',
      'memberReport': 'Rapport de Membre',
      'updateReport': 'Mettre à jour le Rapport',
      'createReportTitle': 'Créer un Rapport',
      'reportTitle': 'Titre',
      'reportTitleRequired': 'Le titre est requis',
      'monthlyReport': 'Rapport Mensuel',
      'yearlyReport': 'Rapport Annuel',
      'year': 'Année',
      'month': 'Mois',
      'selectMonth': 'Sélectionner un mois',
      'pleaseSelectMonth': 'Veuillez sélectionner un mois',
      'summaryReportGenerated': 'Rapport résumé généré avec succès',
      'errorGeneratingSummaryReport': 'Erreur lors de la génération du rapport',
      'reportCreated': 'Rapport créé avec succès',
      'reportUpdated': 'Rapport mis à jour avec succès',
      'errorCreatingReport': 'Erreur lors de la création du rapport',
      'errorUpdatingReport': 'Erreur lors de la mise à jour du rapport',
      'errorLoadingReport': 'Erreur lors du chargement du rapport',
      'errorLoadingData': 'Erreur lors du chargement des données',
      'failedToGetDepartment': 'Échec de l\'obtention du département',
      'reportGeneratedWithPath': 'Rapport généré avec succès: {path}',
    },
  };
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return AppLocalizations.supportedLocales
        .any((supported) => supported.languageCode == locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.resolvedOf(this);

  Locale get appLocale => l10n.locale;

  String tr(String fallback, [Map<String, Object?> params = const {}]) {
    return l10n.translate(fallback, params);
  }
}
