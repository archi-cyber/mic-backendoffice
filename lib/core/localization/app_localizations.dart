import 'package:flutter/material.dart';

/// App localization delegate
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
    final value =
        _localizedValues[locale.languageCode]?[key] ??
        _localizedValues['en']?[key] ??
        fallback;
    return _interpolate(value, params);
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
        return _localizedValues[locale.languageCode]?[entry.key] ?? fallback;
      }
    }
    return null;
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
      _localizedValues[locale.languageCode]?['appName'] ?? 'SysteMIC';
  String get welcome =>
      _localizedValues[locale.languageCode]?['welcome'] ?? 'Welcome';
  String get loading =>
      _localizedValues[locale.languageCode]?['loading'] ?? 'Loading...';
  String get error =>
      _localizedValues[locale.languageCode]?['error'] ?? 'Error';
  String get success =>
      _localizedValues[locale.languageCode]?['success'] ?? 'Success';
  String get cancel =>
      _localizedValues[locale.languageCode]?['cancel'] ?? 'Cancel';
  String get confirm =>
      _localizedValues[locale.languageCode]?['confirm'] ?? 'Confirm';
  String get save => _localizedValues[locale.languageCode]?['save'] ?? 'Save';
  String get delete =>
      _localizedValues[locale.languageCode]?['delete'] ?? 'Delete';
  String get edit => _localizedValues[locale.languageCode]?['edit'] ?? 'Edit';
  String get search =>
      _localizedValues[locale.languageCode]?['search'] ?? 'Search';
  String get filter =>
      _localizedValues[locale.languageCode]?['filter'] ?? 'Filter';
  String get close =>
      _localizedValues[locale.languageCode]?['close'] ?? 'Close';

  // Authentication
  String get login =>
      _localizedValues[locale.languageCode]?['login'] ?? 'Login';
  String get logout =>
      _localizedValues[locale.languageCode]?['logout'] ?? 'Logout';
  String get email =>
      _localizedValues[locale.languageCode]?['email'] ?? 'Email';
  String get password =>
      _localizedValues[locale.languageCode]?['password'] ?? 'Password';
  String get forgotPassword =>
      _localizedValues[locale.languageCode]?['forgotPassword'] ??
      'Forgot Password?';
  String get signIn =>
      _localizedValues[locale.languageCode]?['signIn'] ?? 'Sign In';
  String get signOut =>
      _localizedValues[locale.languageCode]?['signOut'] ?? 'Sign Out';
  String get emailRequired =>
      _localizedValues[locale.languageCode]?['emailRequired'] ??
      'Email is required';
  String get passwordRequired =>
      _localizedValues[locale.languageCode]?['passwordRequired'] ??
      'Password is required';
  String get invalidEmail =>
      _localizedValues[locale.languageCode]?['invalidEmail'] ??
      'Invalid email format';
  String get loginError =>
      _localizedValues[locale.languageCode]?['loginError'] ??
      'Login failed. Please try again.';

  // Dashboard
  String get dashboard =>
      _localizedValues[locale.languageCode]?['dashboard'] ?? 'Dashboard';
  String get home => _localizedValues[locale.languageCode]?['home'] ?? 'Home';
  String get overview =>
      _localizedValues[locale.languageCode]?['overview'] ?? 'Overview';
  String get statistics =>
      _localizedValues[locale.languageCode]?['statistics'] ?? 'Statistics';

  // Navigation
  String get members =>
      _localizedValues[locale.languageCode]?['members'] ?? 'Members';
  String get attendance =>
      _localizedValues[locale.languageCode]?['attendance'] ?? 'Attendance';
  String get giving =>
      _localizedValues[locale.languageCode]?['giving'] ?? 'Giving';
  String get events =>
      _localizedValues[locale.languageCode]?['events'] ?? 'Events';
  String get settings =>
      _localizedValues[locale.languageCode]?['settings'] ?? 'Settings';
  String get notifications =>
      _localizedValues[locale.languageCode]?['notifications'] ??
      'Notifications';
  String get profile =>
      _localizedValues[locale.languageCode]?['profile'] ?? 'Profile';

  // Messages
  String get noData =>
      _localizedValues[locale.languageCode]?['noData'] ?? 'No data available';
  String get networkError =>
      _localizedValues[locale.languageCode]?['networkError'] ??
      'Network error. Please check your connection.';
  String get genericError =>
      _localizedValues[locale.languageCode]?['genericError'] ??
      'An error occurred. Please try again.';

  // Finance
  String get finance =>
      _localizedValues[locale.languageCode]?['finance'] ?? 'Finance';
  String get addGivingRecord =>
      _localizedValues[locale.languageCode]?['addGivingRecord'] ??
      'Add Giving Record';
  String get givingRecord =>
      _localizedValues[locale.languageCode]?['givingRecord'] ?? 'Giving Record';
  String get givingRecordDetails =>
      _localizedValues[locale.languageCode]?['givingRecordDetails'] ??
      'Giving Record Details';
  String get transactionType =>
      _localizedValues[locale.languageCode]?['transactionType'] ??
      'Transaction Type';
  String get receiving =>
      _localizedValues[locale.languageCode]?['receiving'] ?? 'Receiving';
  String get expense =>
      _localizedValues[locale.languageCode]?['expense'] ?? 'Expense';
  String get giverType =>
      _localizedValues[locale.languageCode]?['giverType'] ?? 'Giver Type';
  String get member =>
      _localizedValues[locale.languageCode]?['member'] ?? 'Member';
  String get externalPerson =>
      _localizedValues[locale.languageCode]?['externalPerson'] ??
      'External Person';
  String get giverName =>
      _localizedValues[locale.languageCode]?['giverName'] ?? 'Giver Name';
  String get selectMember =>
      _localizedValues[locale.languageCode]?['selectMember'] ?? 'Select Member';
  String get amount =>
      _localizedValues[locale.languageCode]?['amount'] ?? 'Amount';
  String get tag => _localizedValues[locale.languageCode]?['tag'] ?? 'Tag';
  String get notes =>
      _localizedValues[locale.languageCode]?['notes'] ?? 'Notes';
  String get description =>
      _localizedValues[locale.languageCode]?['description'] ?? 'Description';
  String get date => _localizedValues[locale.languageCode]?['date'] ?? 'Date';
  String get category =>
      _localizedValues[locale.languageCode]?['category'] ?? 'Category';
  String get created =>
      _localizedValues[locale.languageCode]?['created'] ?? 'Created';
  String get lastUpdated =>
      _localizedValues[locale.languageCode]?['lastUpdated'] ?? 'Last Updated';
  String get recordInformation =>
      _localizedValues[locale.languageCode]?['recordInformation'] ??
      'Record Information';
  String get transactionDetails =>
      _localizedValues[locale.languageCode]?['transactionDetails'] ??
      'Transaction Details';
  String get noGivingRecords =>
      _localizedValues[locale.languageCode]?['noGivingRecords'] ??
      'No giving records yet';
  String get addFirstRecord =>
      _localizedValues[locale.languageCode]?['addFirstRecord'] ??
      'Add First Record';
  String get givingRecordCreated =>
      _localizedValues[locale.languageCode]?['givingRecordCreated'] ??
      'Giving record created successfully';
  String get givingRecordUpdated =>
      _localizedValues[locale.languageCode]?['givingRecordUpdated'] ??
      'Giving record updated successfully';
  String get givingRecordNotFound =>
      _localizedValues[locale.languageCode]?['givingRecordNotFound'] ??
      'Giving record not found';
  String get errorLoadingGivingRecord =>
      _localizedValues[locale.languageCode]?['errorLoadingGivingRecord'] ??
      'Error loading giving record';
  String get giverNameRequired =>
      _localizedValues[locale.languageCode]?['giverNameRequired'] ??
      'Giver name is required';
  String get pleaseSelectTag =>
      _localizedValues[locale.languageCode]?['pleaseSelectTag'] ??
      'Please select a tag';
  String get amountRequired =>
      _localizedValues[locale.languageCode]?['amountRequired'] ??
      'Amount is required';
  String get validAmountRequired =>
      _localizedValues[locale.languageCode]?['validAmountRequired'] ??
      'Please enter a valid amount greater than zero';
  String get createExpense =>
      _localizedValues[locale.languageCode]?['createExpense'] ??
      'Create Expense';
  String get createReceivingRecord =>
      _localizedValues[locale.languageCode]?['createReceivingRecord'] ??
      'Create Receiving Record';
  String get saveChanges =>
      _localizedValues[locale.languageCode]?['saveChanges'] ?? 'Save Changes';
  String get recordCanBeEdited =>
      _localizedValues[locale.languageCode]?['recordCanBeEdited'] ??
      'This record can be edited. Changes will be saved immediately.';
  String get recordCannotBeEdited =>
      _localizedValues[locale.languageCode]?['recordCannotBeEdited'] ??
      'This record was created more than 2 days ago and cannot be edited.';
  String get errorLoadingMembers =>
      _localizedValues[locale.languageCode]?['errorLoadingMembers'] ??
      'Error loading members';
  String get errorLoadingGivingRecords =>
      _localizedValues[locale.languageCode]?['errorLoadingGivingRecords'] ??
      'Error loading giving records';

  // Tag labels
  String get construction =>
      _localizedValues[locale.languageCode]?['construction'] ?? 'Construction';
  String get specialOperation =>
      _localizedValues[locale.languageCode]?['specialOperation'] ??
      'Special Operation';
  String get tithe =>
      _localizedValues[locale.languageCode]?['tithe'] ?? 'Tithe';
  String get offering =>
      _localizedValues[locale.languageCode]?['offering'] ?? 'Offering';
  String get gift => _localizedValues[locale.languageCode]?['gift'] ?? 'Gift';
  String get other =>
      _localizedValues[locale.languageCode]?['other'] ?? 'Other';

  // Dashboard
  String get upcomingSessions =>
      _localizedValues[locale.languageCode]?['upcomingSessions'] ??
      'Upcoming Sessions';
  String get upcomingEvents =>
      _localizedValues[locale.languageCode]?['upcomingEvents'] ??
      'Upcoming Events';
  String get tasks =>
      _localizedValues[locale.languageCode]?['tasks'] ?? 'Tasks';
  String get birthdays =>
      _localizedValues[locale.languageCode]?['birthdays'] ?? 'Birthdays';
  String get quickActions =>
      _localizedValues[locale.languageCode]?['quickActions'] ?? 'Quick Actions';
  String get departments =>
      _localizedValues[locale.languageCode]?['departments'] ?? 'Departments';
  String get classes =>
      _localizedValues[locale.languageCode]?['classes'] ?? 'Trainings';
  String get reports =>
      _localizedValues[locale.languageCode]?['reports'] ?? 'Reports';
  String get chat => _localizedValues[locale.languageCode]?['chat'] ?? 'Chat';
  String get errorLoadingDashboard =>
      _localizedValues[locale.languageCode]?['errorLoadingDashboard'] ??
      'Error loading dashboard';

  // Error Messages - Short and descriptive
  String get errorLoginFailed =>
      _localizedValues[locale.languageCode]?['errorLoginFailed'] ??
      'Login failed. Check your credentials.';
  String get errorEmailNotConfirmed =>
      _localizedValues[locale.languageCode]?['errorEmailNotConfirmed'] ??
      'Please confirm your email to continue.';
  String get errorUserNotFound =>
      _localizedValues[locale.languageCode]?['errorUserNotFound'] ??
      'User not found.';
  String get errorAccountCreationFailed =>
      _localizedValues[locale.languageCode]?['errorAccountCreationFailed'] ??
      'Failed to create account.';
  String get errorDuplicateEmail =>
      _localizedValues[locale.languageCode]?['errorDuplicateEmail'] ??
      'Email already in use.';
  String get errorPermissionDenied =>
      _localizedValues[locale.languageCode]?['errorPermissionDenied'] ??
      'You don\'t have permission for this action.';
  String get errorOperationFailed =>
      _localizedValues[locale.languageCode]?['errorOperationFailed'] ??
      'Operation failed. Please try again.';
  String get errorInvalidCredentials =>
      _localizedValues[locale.languageCode]?['errorInvalidCredentials'] ??
      'Invalid email or password.';
  String get errorPasswordResetFailed =>
      _localizedValues[locale.languageCode]?['errorPasswordResetFailed'] ??
      'Password reset failed.';
  String get errorMustBeLoggedIn =>
      _localizedValues[locale.languageCode]?['errorMustBeLoggedIn'] ??
      'Please log in to continue.';
  String get errorAdminOrLeaderRequired =>
      _localizedValues[locale.languageCode]?['errorAdminOrLeaderRequired'] ??
      'Only admins or leaders can perform this action.';
  String get errorMemberNotFound =>
      _localizedValues[locale.languageCode]?['errorMemberNotFound'] ??
      'Member not found.';
  String get errorEmailOrPhoneRequired =>
      _localizedValues[locale.languageCode]?['errorEmailOrPhoneRequired'] ??
      'Email or phone is required.';
  String get errorDepartmentNotFound =>
      _localizedValues[locale.languageCode]?['errorDepartmentNotFound'] ??
      'Department not found.';
  String get errorFailedToLoad =>
      _localizedValues[locale.languageCode]?['errorFailedToLoad'] ??
      'Failed to load data.';
  String get errorFailedToSave =>
      _localizedValues[locale.languageCode]?['errorFailedToSave'] ??
      'Failed to save. Please try again.';
  String get errorFailedToDelete =>
      _localizedValues[locale.languageCode]?['errorFailedToDelete'] ??
      'Failed to delete.';
  String get errorFileUploadFailed =>
      _localizedValues[locale.languageCode]?['errorFileUploadFailed'] ??
      'File upload failed.';
  String get errorInvalidInput =>
      _localizedValues[locale.languageCode]?['errorInvalidInput'] ??
      'Invalid input. Please check your data.';

  // Departments
  String get addDepartment =>
      _localizedValues[locale.languageCode]?['addDepartment'] ??
      'Add Department';
  String get editDepartment =>
      _localizedValues[locale.languageCode]?['editDepartment'] ??
      'Edit Department';
  String get departmentName =>
      _localizedValues[locale.languageCode]?['departmentName'] ??
      'Department Name';
  String get departmentNameRequired =>
      _localizedValues[locale.languageCode]?['departmentNameRequired'] ??
      'Department name is required';
  String get departmentDescription =>
      _localizedValues[locale.languageCode]?['departmentDescription'] ??
      'Description';
  String get departmentCreated =>
      _localizedValues[locale.languageCode]?['departmentCreated'] ??
      'Department created successfully';
  String get departmentUpdated =>
      _localizedValues[locale.languageCode]?['departmentUpdated'] ??
      'Department updated successfully';
  String get departmentDeleted =>
      _localizedValues[locale.languageCode]?['departmentDeleted'] ??
      'Department deleted successfully';
  String get errorCreatingDepartment =>
      _localizedValues[locale.languageCode]?['errorCreatingDepartment'] ??
      'Failed to create department';
  String get errorUpdatingDepartment =>
      _localizedValues[locale.languageCode]?['errorUpdatingDepartment'] ??
      'Failed to update department';
  String get errorDeletingDepartment =>
      _localizedValues[locale.languageCode]?['errorDeletingDepartment'] ??
      'Failed to delete department';
  String get errorLoadingDepartments =>
      _localizedValues[locale.languageCode]?['errorLoadingDepartments'] ??
      'Failed to load departments';
  String get noDepartments =>
      _localizedValues[locale.languageCode]?['noDepartments'] ??
      'No departments yet';
  String get noDepartmentsFound =>
      _localizedValues[locale.languageCode]?['noDepartmentsFound'] ??
      'No departments found';
  String get searchDepartments =>
      _localizedValues[locale.languageCode]?['searchDepartments'] ??
      'Search departments...';
  String get departmentFiles =>
      _localizedValues[locale.languageCode]?['departmentFiles'] ??
      'Department Files';
  String get noFilesUploaded =>
      _localizedValues[locale.languageCode]?['noFilesUploaded'] ??
      'No files uploaded';
  String get documents =>
      _localizedValues[locale.languageCode]?['documents'] ?? 'Documents';
  String get documentsOptional =>
      _localizedValues[locale.languageCode]?['documentsOptional'] ??
      'Documents (Optional)';
  String get document =>
      _localizedValues[locale.languageCode]?['document'] ?? 'Document';
  String get upload =>
      _localizedValues[locale.languageCode]?['upload'] ?? 'Upload';
  String get remove =>
      _localizedValues[locale.languageCode]?['remove'] ?? 'Remove';
  String get view => _localizedValues[locale.languageCode]?['view'] ?? 'View';
  String get newFile =>
      _localizedValues[locale.languageCode]?['newFile'] ?? 'New file';
  String get deleteDepartment =>
      _localizedValues[locale.languageCode]?['deleteDepartment'] ??
      'Delete Department';
  String get deleteDepartmentConfirm =>
      _localizedValues[locale.languageCode]?['deleteDepartmentConfirm'] ??
      'Are you sure you want to delete this department? This will deactivate it.';
  String get createDepartment =>
      _localizedValues[locale.languageCode]?['createDepartment'] ??
      'Create Department';
  String get updateDepartment =>
      _localizedValues[locale.languageCode]?['updateDepartment'] ??
      'Update Department';

  // Department Members
  String get addMember =>
      _localizedValues[locale.languageCode]?['addMember'] ?? 'Add Member';
  String get removeMember =>
      _localizedValues[locale.languageCode]?['removeMember'] ?? 'Remove Member';
  String get changeRole =>
      _localizedValues[locale.languageCode]?['changeRole'] ?? 'Change Role';
  String get role => _localizedValues[locale.languageCode]?['role'] ?? 'Role';
  String get leader =>
      _localizedValues[locale.languageCode]?['leader'] ?? 'Leader';
  String get subleader =>
      _localizedValues[locale.languageCode]?['subleader'] ?? 'Subleader';
  String get memberRole =>
      _localizedValues[locale.languageCode]?['memberRole'] ?? 'Member';
  String get selectRole =>
      _localizedValues[locale.languageCode]?['selectRole'] ?? 'Select Role';
  String get memberAdded =>
      _localizedValues[locale.languageCode]?['memberAdded'] ??
      'Member added successfully';
  String get memberRemoved =>
      _localizedValues[locale.languageCode]?['memberRemoved'] ??
      'Member removed successfully';
  String get deleteMember =>
      _localizedValues[locale.languageCode]?['deleteMember'] ?? 'Delete Member';
  String get deleteMemberConfirmation =>
      _localizedValues[locale.languageCode]?['deleteMemberConfirmation'] ??
      'Are you sure you want to delete {name}? This action cannot be undone.';
  String get memberDeletedSuccessfully =>
      _localizedValues[locale.languageCode]?['memberDeletedSuccessfully'] ??
      'Member deleted successfully';
  String get roleUpdated =>
      _localizedValues[locale.languageCode]?['roleUpdated'] ??
      'Role updated successfully';
  String get errorAddingMember =>
      _localizedValues[locale.languageCode]?['errorAddingMember'] ??
      'Failed to add member';
  String get errorRemovingMember =>
      _localizedValues[locale.languageCode]?['errorRemovingMember'] ??
      'Failed to remove member';
  String get errorUpdatingRole =>
      _localizedValues[locale.languageCode]?['errorUpdatingRole'] ??
      'Failed to update role';
  String get noMembersInDepartment =>
      _localizedValues[locale.languageCode]?['noMembersInDepartment'] ??
      'No members in this department';
  String get allMembersInDepartment =>
      _localizedValues[locale.languageCode]?['allMembersInDepartment'] ??
      'All members are already in this department';
  String get removeMemberConfirm =>
      _localizedValues[locale.languageCode]?['removeMemberConfirm'] ??
      'Are you sure you want to remove {name} from this department?';
  String removeMemberConfirmWithName(String name) =>
      removeMemberConfirm.replaceAll('{name}', name);

  // Password Change
  String get changePassword =>
      _localizedValues[locale.languageCode]?['changePassword'] ??
      'Change Password';
  String get changePasswordRequired =>
      _localizedValues[locale.languageCode]?['changePasswordRequired'] ??
      'Change Password Required';
  String get changePasswordMessage =>
      _localizedValues[locale.languageCode]?['changePasswordMessage'] ??
      'You must change your password before continuing.';
  String get newPassword =>
      _localizedValues[locale.languageCode]?['newPassword'] ?? 'New Password';
  String get confirmPassword =>
      _localizedValues[locale.languageCode]?['confirmPassword'] ??
      'Confirm New Password';
  String get newPasswordRequired =>
      _localizedValues[locale.languageCode]?['newPasswordRequired'] ??
      'New password is required';
  String get passwordMinLength =>
      _localizedValues[locale.languageCode]?['passwordMinLength'] ??
      'Password must be at least 6 characters';
  String get passwordsDoNotMatch =>
      _localizedValues[locale.languageCode]?['passwordsDoNotMatch'] ??
      'Passwords do not match';
  String get passwordChanged =>
      _localizedValues[locale.languageCode]?['passwordChanged'] ??
      'Password changed successfully';
  String get errorChangingPassword =>
      _localizedValues[locale.languageCode]?['errorChangingPassword'] ??
      'Failed to change password';

  // Tasks
  String get manageTasks =>
      _localizedValues[locale.languageCode]?['manageTasks'] ?? 'Manage Tasks';
  String get generateReport =>
      _localizedValues[locale.languageCode]?['generateReport'] ??
      'Generate Report';
  String get taskCompletion =>
      _localizedValues[locale.languageCode]?['taskCompletion'] ??
      'Task Completion';
  String get total =>
      _localizedValues[locale.languageCode]?['total'] ?? 'Total';
  String get completed =>
      _localizedValues[locale.languageCode]?['completed'] ?? 'Completed';
  String get pending =>
      _localizedValues[locale.languageCode]?['pending'] ?? 'Pending';
  String get inProgress =>
      _localizedValues[locale.languageCode]?['inProgress'] ?? 'In Progress';
  String get noTasks =>
      _localizedValues[locale.languageCode]?['noTasks'] ??
      'No tasks in this department';

  // Reports
  String get createReport =>
      _localizedValues[locale.languageCode]?['createReport'] ?? 'Create Report';
  String get generateSummaryReport =>
      _localizedValues[locale.languageCode]?['generateSummaryReport'] ??
      'Generate Summary Report';
  String get noReports =>
      _localizedValues[locale.languageCode]?['noReports'] ?? 'No reports yet';
  String get createFirstReport =>
      _localizedValues[locale.languageCode]?['createFirstReport'] ??
      'Create your first report to get started';
  String get generatePdf =>
      _localizedValues[locale.languageCode]?['generatePdf'] ?? 'Generate PDF';
  String get editReport =>
      _localizedValues[locale.languageCode]?['editReport'] ?? 'Edit';
  String get deleteReport =>
      _localizedValues[locale.languageCode]?['deleteReport'] ?? 'Delete';
  String get deleteReportConfirm =>
      _localizedValues[locale.languageCode]?['deleteReportConfirm'] ??
      'Are you sure you want to delete "{title}"?';
  String deleteReportConfirmWithTitle(String title) =>
      deleteReportConfirm.replaceAll('{title}', title);
  String get reportDeleted =>
      _localizedValues[locale.languageCode]?['reportDeleted'] ??
      'Report deleted successfully';
  String get errorDeletingReport =>
      _localizedValues[locale.languageCode]?['errorDeletingReport'] ??
      'Failed to delete report';
  String get reportGenerated =>
      _localizedValues[locale.languageCode]?['reportGenerated'] ??
      'Report generated successfully';
  String get errorGeneratingReport =>
      _localizedValues[locale.languageCode]?['errorGeneratingReport'] ??
      'Failed to generate report';
  String get generatingPdf =>
      _localizedValues[locale.languageCode]?['generatingPdf'] ??
      'Generating PDF...';
  String get generatingReport =>
      _localizedValues[locale.languageCode]?['generatingReport'] ??
      'Generating report...';
  String get pdfGenerated =>
      _localizedValues[locale.languageCode]?['pdfGenerated'] ??
      'PDF generated successfully';

  // Refresh
  String get refresh =>
      _localizedValues[locale.languageCode]?['refresh'] ?? 'Refresh';

  // Active/Inactive
  String get active =>
      _localizedValues[locale.languageCode]?['active'] ?? 'Active';
  String get inactive =>
      _localizedValues[locale.languageCode]?['inactive'] ?? 'Inactive';

  // Phone
  String get phone =>
      _localizedValues[locale.languageCode]?['phone'] ?? 'Phone';
  String get phoneOrEmail =>
      _localizedValues[locale.languageCode]?['phoneOrEmail'] ??
      'Email or Phone';

  // Update
  String get update =>
      _localizedValues[locale.languageCode]?['update'] ?? 'Update';
  String get add => _localizedValues[locale.languageCode]?['add'] ?? 'Add';
  String get name => _localizedValues[locale.languageCode]?['name'] ?? 'Name';
  String get nameRequired =>
      _localizedValues[locale.languageCode]?['nameRequired'] ??
      'Name is required';

  // Success messages
  String get successOperation =>
      _localizedValues[locale.languageCode]?['successOperation'] ??
      'Operation completed successfully';

  // Warning messages
  String get warning =>
      _localizedValues[locale.languageCode]?['warning'] ?? 'Warning';
  String get someDocumentsFailed =>
      _localizedValues[locale.languageCode]?['someDocumentsFailed'] ??
      'Department created, but some documents failed to upload';
  String get documentUploadErrors =>
      _localizedValues[locale.languageCode]?['documentUploadErrors'] ??
      'Document Upload Errors';
  String get documentsFailedMessage =>
      _localizedValues[locale.languageCode]?['documentsFailedMessage'] ??
      'The department was created, but the following documents failed to upload:';
  String get canAddDocumentsLater =>
      _localizedValues[locale.languageCode]?['canAddDocumentsLater'] ??
      'You can add these documents later by editing the department.';

  // OK button
  String get ok => _localizedValues[locale.languageCode]?['ok'] ?? 'OK';

  // Optional
  String get optional =>
      _localizedValues[locale.languageCode]?['optional'] ?? '(Optional)';

  // Enter text helpers
  String get enterDepartmentName =>
      _localizedValues[locale.languageCode]?['enterDepartmentName'] ??
      'Enter the name of the department';
  String get optionalDescription =>
      _localizedValues[locale.languageCode]?['optionalDescription'] ??
      'Optional description for the department';

  // Teachings
  String get teachings =>
      _localizedValues[locale.languageCode]?['teachings'] ?? 'Teachings';
  String get addTeaching =>
      _localizedValues[locale.languageCode]?['addTeaching'] ?? 'Add Teaching';
  String get editTeaching =>
      _localizedValues[locale.languageCode]?['editTeaching'] ?? 'Edit Teaching';
  String get teachingDetails =>
      _localizedValues[locale.languageCode]?['teachingDetails'] ??
      'Teaching Details';
  String get teachingTitle =>
      _localizedValues[locale.languageCode]?['teachingTitle'] ?? 'Title';
  String get teachingTitleRequired =>
      _localizedValues[locale.languageCode]?['teachingTitleRequired'] ??
      'Please enter a title';
  String get teachingDate =>
      _localizedValues[locale.languageCode]?['teachingDate'] ?? 'Teaching Date';
  String get teachingDateRequired =>
      _localizedValues[locale.languageCode]?['teachingDateRequired'] ??
      'Please select a date';
  String get speaker =>
      _localizedValues[locale.languageCode]?['speaker'] ?? 'Speaker';
  String get teachingDescription =>
      _localizedValues[locale.languageCode]?['teachingDescription'] ??
      'Description';
  String get updateTeaching =>
      _localizedValues[locale.languageCode]?['updateTeaching'] ??
      'Update Teaching';
  String get teachingAdded =>
      _localizedValues[locale.languageCode]?['teachingAdded'] ??
      'Teaching added successfully';
  String get teachingUpdated =>
      _localizedValues[locale.languageCode]?['teachingUpdated'] ??
      'Teaching updated successfully';
  String get teachingDeleted =>
      _localizedValues[locale.languageCode]?['teachingDeleted'] ??
      'Teaching deleted successfully';
  String get errorLoadingTeaching =>
      _localizedValues[locale.languageCode]?['errorLoadingTeaching'] ??
      'Error loading teaching';
  String get errorDeletingTeaching =>
      _localizedValues[locale.languageCode]?['errorDeletingTeaching'] ??
      'Error deleting teaching';
  String get deleteTeachingConfirm =>
      _localizedValues[locale.languageCode]?['deleteTeachingConfirm'] ??
      'Are you sure you want to delete "{title}"?';
  String deleteTeachingConfirmWithTitle(String title) =>
      deleteTeachingConfirm.replaceAll('{title}', title);
  String get searchTeachings =>
      _localizedValues[locale.languageCode]?['searchTeachings'] ??
      'Search teachings...';
  String get noTeachings =>
      _localizedValues[locale.languageCode]?['noTeachings'] ??
      'No teachings yet';
  String get noTeachingsFound =>
      _localizedValues[locale.languageCode]?['noTeachingsFound'] ??
      'No teachings found matching your search';
  String get listeners =>
      _localizedValues[locale.languageCode]?['listeners'] ?? 'Listeners';
  String get syncFromAttendance =>
      _localizedValues[locale.languageCode]?['syncFromAttendance'] ??
      'Sync from Church Attendance';
  String get searchPotentialListeners =>
      _localizedValues[locale.languageCode]?['searchPotentialListeners'] ??
      'Search potential listeners...';
  String get noListeners =>
      _localizedValues[locale.languageCode]?['noListeners'] ??
      'No listeners yet';
  String get addListener =>
      _localizedValues[locale.languageCode]?['addListener'] ?? 'Add';
  String get addListenerTitle =>
      _localizedValues[locale.languageCode]?['addListenerTitle'] ??
      'Add Listener';
  String get removeListener =>
      _localizedValues[locale.languageCode]?['removeListener'] ??
      'Remove Listener';
  String get removeListenerConfirm =>
      _localizedValues[locale.languageCode]?['removeListenerConfirm'] ??
      'Remove "{name}" from listeners?';
  String removeListenerConfirmWithName(String name) =>
      removeListenerConfirm.replaceAll('{name}', name);
  String get listenerAdded =>
      _localizedValues[locale.languageCode]?['listenerAdded'] ??
      'Listener added successfully';
  String get listenerRemoved =>
      _localizedValues[locale.languageCode]?['listenerRemoved'] ??
      'Listener removed successfully';
  String get errorAddingListener =>
      _localizedValues[locale.languageCode]?['errorAddingListener'] ??
      'Error adding listener';
  String get errorRemovingListener =>
      _localizedValues[locale.languageCode]?['errorRemovingListener'] ??
      'Error removing listener';
  String get errorSyncingListeners =>
      _localizedValues[locale.languageCode]?['errorSyncingListeners'] ??
      'Error syncing listeners';
  String get listenersSynced =>
      _localizedValues[locale.languageCode]?['listenersSynced'] ??
      'Synced {count} listener(s) from church attendance';
  String listenersSyncedWithCount(int count) =>
      listenersSynced.replaceAll('{count}', count.toString());
  String get allListenersAdded =>
      _localizedValues[locale.languageCode]?['allListenersAdded'] ??
      'All potential listeners are already added';
  String get useSyncOrAdd =>
      _localizedValues[locale.languageCode]?['useSyncOrAdd'] ??
      'Use "Sync from Church Attendance" or "Add" to add listeners';

  // Visitors
  String get visitors =>
      _localizedValues[locale.languageCode]?['visitors'] ?? 'Visitors';
  String get addVisitor =>
      _localizedValues[locale.languageCode]?['addVisitor'] ?? 'Add Visitor';
  String get editVisitor =>
      _localizedValues[locale.languageCode]?['editVisitor'] ?? 'Edit Visitor';
  String get updateVisitor =>
      _localizedValues[locale.languageCode]?['updateVisitor'] ??
      'Update Visitor';
  String get visitorFirstName =>
      _localizedValues[locale.languageCode]?['visitorFirstName'] ??
      'First Name';
  String get visitorFirstNameRequired =>
      _localizedValues[locale.languageCode]?['visitorFirstNameRequired'] ??
      'First name is required';
  String get visitorLastName =>
      _localizedValues[locale.languageCode]?['visitorLastName'] ?? 'Last Name';
  String get visitorLastNameRequired =>
      _localizedValues[locale.languageCode]?['visitorLastNameRequired'] ??
      'Last name is required';
  String get visitDate =>
      _localizedValues[locale.languageCode]?['visitDate'] ?? 'Visit Date';
  String get visitDateRequired =>
      _localizedValues[locale.languageCode]?['visitDateRequired'] ??
      'Visit date is required';
  String get visitorAdded =>
      _localizedValues[locale.languageCode]?['visitorAdded'] ??
      'Visitor added successfully';
  String get visitorUpdated =>
      _localizedValues[locale.languageCode]?['visitorUpdated'] ??
      'Visitor updated successfully';
  String get visitorDeleted =>
      _localizedValues[locale.languageCode]?['visitorDeleted'] ??
      'Visitor deleted successfully';
  String get errorLoadingVisitor =>
      _localizedValues[locale.languageCode]?['errorLoadingVisitor'] ??
      'Error loading visitor';
  String get errorDeletingVisitor =>
      _localizedValues[locale.languageCode]?['errorDeletingVisitor'] ??
      'Error deleting visitor';
  String get deleteVisitorConfirm =>
      _localizedValues[locale.languageCode]?['deleteVisitorConfirm'] ??
      'Are you sure you want to delete "{name}"?';
  String deleteVisitorConfirmWithName(String name) =>
      deleteVisitorConfirm.replaceAll('{name}', name);
  String get searchVisitors =>
      _localizedValues[locale.languageCode]?['searchVisitors'] ??
      'Search visitors...';
  String get noVisitors =>
      _localizedValues[locale.languageCode]?['noVisitors'] ?? 'No visitors yet';
  String get noVisitorsFound =>
      _localizedValues[locale.languageCode]?['noVisitorsFound'] ??
      'No visitors found matching your search';
  String get convertToMember =>
      _localizedValues[locale.languageCode]?['convertToMember'] ??
      'Convert to Member';
  String get convertVisitorToMember =>
      _localizedValues[locale.languageCode]?['convertVisitorToMember'] ??
      'Convert visitor to member';
  String convertVisitorToMemberConfirm(String name) =>
      (_localizedValues[locale
                  .languageCode]?['convertVisitorToMemberConfirm'] ??
              'Create a member profile for "{name}" using the visitor\'s contact details. The visitor record will be removed.')
          .replaceAll('{name}', name);
  String get visitorConvertedToMember =>
      _localizedValues[locale.languageCode]?['visitorConvertedToMember'] ??
      'Visitor converted to member successfully';
  String get errorConvertingVisitor =>
      _localizedValues[locale.languageCode]?['errorConvertingVisitor'] ??
      'Error converting visitor to member';

  // Workers & Departments
  String get workers =>
      _localizedValues[locale.languageCode]?['workers'] ?? 'Workers';
  String get searchWorkers =>
      _localizedValues[locale.languageCode]?['searchWorkers'] ??
      'Search workers...';
  String get noWorkers =>
      _localizedValues[locale.languageCode]?['noWorkers'] ?? 'No workers found';
  String get noWorkersFound =>
      _localizedValues[locale.languageCode]?['noWorkersFound'] ??
      'No workers found matching your search';
  String get noDepartmentsAssigned =>
      _localizedValues[locale.languageCode]?['noDepartmentsAssigned'] ??
      'No departments assigned';
  String get setMainDepartment =>
      _localizedValues[locale.languageCode]?['setMainDepartment'] ??
      'Set Main Department';
  String get setMainDepartmentFor =>
      _localizedValues[locale.languageCode]?['setMainDepartmentFor'] ??
      'Set Main Department for {name}';
  String setMainDepartmentForWithName(String name) =>
      setMainDepartmentFor.replaceAll('{name}', name);
  String get workerNoDepartments =>
      _localizedValues[locale.languageCode]?['workerNoDepartments'] ??
      'Worker has no departments assigned';
  String get updatingMainDepartment =>
      _localizedValues[locale.languageCode]?['updatingMainDepartment'] ??
      'Updating main department...';
  String get mainDepartmentUpdated =>
      _localizedValues[locale.languageCode]?['mainDepartmentUpdated'] ??
      'Main department updated successfully';
  String get errorUpdatingMainDepartment =>
      _localizedValues[locale.languageCode]?['errorUpdatingMainDepartment'] ??
      'Error updating main department';

  // Leader Access
  String get leaderAccessManagement =>
      _localizedValues[locale.languageCode]?['leaderAccessManagement'] ??
      'Leader Access Management';
  String get defineFeatureAccess =>
      _localizedValues[locale.languageCode]?['defineFeatureAccess'] ??
      'Define feature access for each leader';
  String get featureAccessPermissions =>
      _localizedValues[locale.languageCode]?['featureAccessPermissions'] ??
      'Feature Access Permissions';
  String get unsavedChanges =>
      _localizedValues[locale.languageCode]?['unsavedChanges'] ??
      'Unsaved changes';
  String get saveAllChanges =>
      _localizedValues[locale.languageCode]?['saveAllChanges'] ??
      'Save All Changes';
  String get allAccessSaved =>
      _localizedValues[locale.languageCode]?['allAccessSaved'] ??
      'All access permissions saved successfully';
  String get errorSavingAccess =>
      _localizedValues[locale.languageCode]?['errorSavingAccess'] ??
      'Error saving access';
  String get errorLoadingLeaders =>
      _localizedValues[locale.languageCode]?['errorLoadingLeaders'] ??
      'Error loading leaders';
  String get errorLoadingAccess =>
      _localizedValues[locale.languageCode]?['errorLoadingAccess'] ??
      'Error loading access';
  String get canView =>
      _localizedValues[locale.languageCode]?['canView'] ?? 'View';
  String get canCreate =>
      _localizedValues[locale.languageCode]?['canCreate'] ?? 'Create';
  String get canEdit =>
      _localizedValues[locale.languageCode]?['canEdit'] ?? 'Edit';
  String get canDelete =>
      _localizedValues[locale.languageCode]?['canDelete'] ?? 'Delete';

  // Settings
  String get adminSettings =>
      _localizedValues[locale.languageCode]?['adminSettings'] ??
      'Admin Settings';
  String get language =>
      _localizedValues[locale.languageCode]?['language'] ?? 'Language';
  String get theme =>
      _localizedValues[locale.languageCode]?['theme'] ?? 'Theme';
  String get enableNotifications =>
      _localizedValues[locale.languageCode]?['enableNotifications'] ??
      'Enable Notifications';
  String get receivePushNotifications =>
      _localizedValues[locale.languageCode]?['receivePushNotifications'] ??
      'Receive push notifications';
  String get exportAllData =>
      _localizedValues[locale.languageCode]?['exportAllData'] ??
      'Export All Data';
  String get exportAllDataSubtitle =>
      _localizedValues[locale.languageCode]?['exportAllDataSubtitle'] ??
      'Export all data to JSON file';
  String get importData =>
      _localizedValues[locale.languageCode]?['importData'] ?? 'Import Data';
  String get importDataSubtitle =>
      _localizedValues[locale.languageCode]?['importDataSubtitle'] ??
      'Import data from JSON file';
  String get exportMembers =>
      _localizedValues[locale.languageCode]?['exportMembers'] ??
      'Export Members';
  String get exportMembersSubtitle =>
      _localizedValues[locale.languageCode]?['exportMembersSubtitle'] ??
      'Export members to CSV';
  String get syncUsersMembers =>
      _localizedValues[locale.languageCode]?['syncUsersMembers'] ??
      'Sync Users & Members';
  String get generateAllUsersReport =>
      _localizedValues[locale.languageCode]?['generateAllUsersReport'] ??
      'Generate All Users Report';
  String get birthdayNotifications =>
      _localizedValues[locale.languageCode]?['birthdayNotifications'] ??
      'Birthday Notifications';
  String get configureBirthdayNotifications =>
      _localizedValues[locale
          .languageCode]?['configureBirthdayNotifications'] ??
      'Configure birthday notification settings';
  String get currentUser =>
      _localizedValues[locale.languageCode]?['currentUser'] ?? 'Current User';
  String get signOutAccount =>
      _localizedValues[locale.languageCode]?['signOutAccount'] ??
      'Sign out of your account';
  String get appVersion =>
      _localizedValues[locale.languageCode]?['appVersion'] ?? 'App Version';
  String get logoutConfirm =>
      _localizedValues[locale.languageCode]?['logoutConfirm'] ??
      'Are you sure you want to logout?';
  String get languageChanged =>
      _localizedValues[locale.languageCode]?['languageChanged'] ??
      'Language changed successfully';
  String get errorChangingLanguage =>
      _localizedValues[locale.languageCode]?['errorChangingLanguage'] ??
      'Failed to change language';
  String get themeChanged =>
      _localizedValues[locale.languageCode]?['themeChanged'] ??
      'Theme changed successfully';
  String get errorChangingTheme =>
      _localizedValues[locale.languageCode]?['errorChangingTheme'] ??
      'Failed to change theme';
  String get errorUpdatingNotifications =>
      _localizedValues[locale.languageCode]?['errorUpdatingNotifications'] ??
      'Failed to update notifications';
  String get export =>
      _localizedValues[locale.languageCode]?['export'] ?? 'Export';
  String get importing =>
      _localizedValues[locale.languageCode]?['importing'] ??
      'Importing data...';
  String get exporting =>
      _localizedValues[locale.languageCode]?['exporting'] ??
      'Exporting data...';
  String get dataExported =>
      _localizedValues[locale.languageCode]?['dataExported'] ??
      'Data exported successfully to:\n{path}';
  String dataExportedWithPath(String path) =>
      dataExported.replaceAll('{path}', path);
  String get exportCancelled =>
      _localizedValues[locale.languageCode]?['exportCancelled'] ??
      'Export cancelled';
  String get exportFailed =>
      _localizedValues[locale.languageCode]?['exportFailed'] ?? 'Export failed';
  String get membersExported =>
      _localizedValues[locale.languageCode]?['membersExported'] ??
      'Members exported successfully';
  String get sync => _localizedValues[locale.languageCode]?['sync'] ?? 'Sync';
  String get syncing =>
      _localizedValues[locale.languageCode]?['syncing'] ??
      'Syncing users and members...';
  String get syncFailed =>
      _localizedValues[locale.languageCode]?['syncFailed'] ?? 'Sync failed';
  String get reportSaved =>
      _localizedValues[locale.languageCode]?['reportSaved'] ??
      'Report saved successfully to:\n{path}';
  String reportSavedWithPath(String path) =>
      reportSaved.replaceAll('{path}', path);
  String get reportGenerationCancelled =>
      _localizedValues[locale.languageCode]?['reportGenerationCancelled'] ??
      'Report generation cancelled';
  String get reportGenerationFailed =>
      _localizedValues[locale.languageCode]?['reportGenerationFailed'] ??
      'Report generation failed';
  String get import =>
      _localizedValues[locale.languageCode]?['import'] ?? 'Import';
  String get importFailed =>
      _localizedValues[locale.languageCode]?['importFailed'] ?? 'Import failed';
  String get english =>
      _localizedValues[locale.languageCode]?['english'] ?? 'English';
  String get french =>
      _localizedValues[locale.languageCode]?['french'] ?? 'Français';
  String get selectTheme =>
      _localizedValues[locale.languageCode]?['selectTheme'] ?? 'Select Theme';
  String get light =>
      _localizedValues[locale.languageCode]?['light'] ?? 'Light';
  String get dark => _localizedValues[locale.languageCode]?['dark'] ?? 'Dark';
  String get systemDefault =>
      _localizedValues[locale.languageCode]?['systemDefault'] ??
      'System Default';
  String get birthdayNotificationsSettings =>
      _localizedValues[locale.languageCode]?['birthdayNotificationsSettings'] ??
      'Birthday Notifications';
  String get allChurchAppUsers =>
      _localizedValues[locale.languageCode]?['allChurchAppUsers'] ??
      'All Church App Users';
  String get defaultAllActiveMembers =>
      _localizedValues[locale.languageCode]?['defaultAllActiveMembers'] ??
      'Default: All active members';
  String get leadersOnly =>
      _localizedValues[locale.languageCode]?['leadersOnly'] ?? 'Leaders Only';
  String get onlyDepartmentLeadersAdmins =>
      _localizedValues[locale.languageCode]?['onlyDepartmentLeadersAdmins'] ??
      'Only department leaders and admins';
  String get optOutNoNotifications =>
      _localizedValues[locale.languageCode]?['optOutNoNotifications'] ??
      'Opt-Out (No Notifications)';
  String get usersCanOptIn =>
      _localizedValues[locale.languageCode]?['usersCanOptIn'] ??
      'Users can opt-in individually';
  String get note => _localizedValues[locale.languageCode]?['note'] ?? 'Note';
  String get saveSettings =>
      _localizedValues[locale.languageCode]?['saveSettings'] ?? 'Save Settings';
  String get settingsSaved =>
      _localizedValues[locale.languageCode]?['settingsSaved'] ??
      'Settings saved successfully';
  String get errorSavingConfig =>
      _localizedValues[locale.languageCode]?['errorSavingConfig'] ??
      'Error saving config';
  String get errorLoadingConfig =>
      _localizedValues[locale.languageCode]?['errorLoadingConfig'] ??
      'Error loading config';
  String get notificationsEnabled =>
      _localizedValues[locale.languageCode]?['notificationsEnabled'] ??
      'Notifications enabled';
  String get notificationsDisabled =>
      _localizedValues[locale.languageCode]?['notificationsDisabled'] ??
      'Notifications disabled';
  String get exportAllDataConfirm =>
      _localizedValues[locale.languageCode]?['exportAllDataConfirm'] ??
      'This will export all members, departments, classes, events, and tasks to a JSON file. You will be asked to select a save location. Continue?';
  String get syncUsersMembersConfirm =>
      _localizedValues[locale.languageCode]?['syncUsersMembersConfirm'] ??
      'This will:\n1. Create a member for every user\n2. Create a user (with default password "Password123") for every leader member\n\nLeaders will be required to change their password on first login.\n\nContinue?';
  String get syncCompleted =>
      _localizedValues[locale.languageCode]?['syncCompleted'] ??
      'Sync completed!';
  String get usersToMembers =>
      _localizedValues[locale.languageCode]?['usersToMembers'] ??
      'Users → Members';
  String get leadersToUsers =>
      _localizedValues[locale.languageCode]?['leadersToUsers'] ??
      'Leaders → Users';
  String get createdLabel =>
      _localizedValues[locale.languageCode]?['createdLabel'] ?? 'created';
  String get skippedLabel =>
      _localizedValues[locale.languageCode]?['skippedLabel'] ?? 'skipped';
  String get errorsLabel =>
      _localizedValues[locale.languageCode]?['errorsLabel'] ?? 'errors';
  String get importDataConfirm =>
      _localizedValues[locale.languageCode]?['importDataConfirm'] ??
      'This will import data from a JSON file. Existing members with the same email will be skipped. Continue?';
  String get importCompleted =>
      _localizedValues[locale.languageCode]?['importCompleted'] ??
      'Import completed';
  String get importedLabel =>
      _localizedValues[locale.languageCode]?['importedLabel'] ?? 'Imported';
  String get notLoggedIn =>
      _localizedValues[locale.languageCode]?['notLoggedIn'] ?? 'Not logged in';
  String get logoutFailed =>
      _localizedValues[locale.languageCode]?['logoutFailed'] ?? 'Logout failed';
  String get languageAndRegion =>
      _localizedValues[locale.languageCode]?['languageAndRegion'] ??
      'Language & Region';
  String get appearance =>
      _localizedValues[locale.languageCode]?['appearance'] ?? 'Appearance';
  String get dataManagement =>
      _localizedValues[locale.languageCode]?['dataManagement'] ??
      'Data Management';
  String get about =>
      _localizedValues[locale.languageCode]?['about'] ?? 'About';
  String get generateReportComprehensive =>
      _localizedValues[locale.languageCode]?['generateReportComprehensive'] ??
      'Generate comprehensive report for all users';
  String get account =>
      _localizedValues[locale.languageCode]?['account'] ?? 'Account';

  // Events
  String get addEvent =>
      _localizedValues[locale.languageCode]?['addEvent'] ?? 'Add Event';
  String get editEvent =>
      _localizedValues[locale.languageCode]?['editEvent'] ?? 'Edit Event';
  String get deleteEvent =>
      _localizedValues[locale.languageCode]?['deleteEvent'] ?? 'Delete Event';
  String get eventDeleted =>
      _localizedValues[locale.languageCode]?['eventDeleted'] ??
      'Event deleted successfully';
  String get errorDeletingEvent =>
      _localizedValues[locale.languageCode]?['errorDeletingEvent'] ??
      'Error deleting event';
  String get deleteEventConfirm =>
      _localizedValues[locale.languageCode]?['deleteEventConfirm'] ??
      'Are you sure you want to delete "{title}"?';
  String deleteEventConfirmWithTitle(String title) =>
      deleteEventConfirm.replaceAll('{title}', title);
  String get searchEvents =>
      _localizedValues[locale.languageCode]?['searchEvents'] ??
      'Search events...';
  String get noEvents =>
      _localizedValues[locale.languageCode]?['noEvents'] ?? 'No events yet';
  String get noEventsFound =>
      _localizedValues[locale.languageCode]?['noEventsFound'] ??
      'No events found matching your search';

  // Church Attendance
  String get churchAttendance =>
      _localizedValues[locale.languageCode]?['churchAttendance'] ??
      'Church Attendance';
  String get sundaySchool =>
      _localizedValues[locale.languageCode]?['sundaySchool'] ?? 'Sunday School';

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
      _localizedValues[locale.languageCode]?['attendanceReportFullName'] ??
      'Full name';
  String get attendanceReportOnsiteTotal =>
      _localizedValues[locale.languageCode]?['attendanceReportOnsiteTotal'] ??
      'Onsite (total)';
  String get attendanceReportOnlineTotal =>
      _localizedValues[locale.languageCode]?['attendanceReportOnlineTotal'] ??
      'Online (total)';
  String get attendanceReportTotalPresent =>
      _localizedValues[locale.languageCode]?['attendanceReportTotalPresent'] ??
      'Total present';
  String get attendanceReportObservation =>
      _localizedValues[locale.languageCode]?['attendanceReportObservation'] ??
      'Observation';
  String get attendanceReportSpecificObservations =>
      _localizedValues[locale
          .languageCode]?['attendanceReportSpecificObservations'] ??
      'Specific observations';
  String get attendanceReportPresentAbbr =>
      _localizedValues[locale.languageCode]?['attendanceReportPresentAbbr'] ??
      'P';
  String get attendanceReportAbsentAbbr =>
      _localizedValues[locale.languageCode]?['attendanceReportAbsentAbbr'] ??
      'A';
  String get attendanceReportOnlineAbbr =>
      _localizedValues[locale.languageCode]?['attendanceReportOnlineAbbr'] ??
      'O';
  String get attendanceReportOnsite =>
      _localizedValues[locale.languageCode]?['attendanceReportOnsite'] ??
      'Onsite';
  String get attendanceReportOnline =>
      _localizedValues[locale.languageCode]?['attendanceReportOnline'] ??
      'Online';
  String get attendanceReportAbsent =>
      _localizedValues[locale.languageCode]?['attendanceReportAbsent'] ??
      'Absent';
  String get attendanceReportVisitor =>
      _localizedValues[locale.languageCode]?['attendanceReportVisitor'] ??
      'Visitor';
  String get attendanceReportVisitorsSection =>
      _localizedValues[locale
          .languageCode]?['attendanceReportVisitorsSection'] ??
      'Visitors';
  String get attendanceReportChildTag =>
      _localizedValues[locale.languageCode]?['attendanceReportChildTag'] ??
      'Child';
  String get attendanceReportNewComerTag =>
      _localizedValues[locale.languageCode]?['attendanceReportNewComerTag'] ??
      'New comer';
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
      _localizedValues[locale.languageCode]?['attendanceReportChartNoData'] ??
      'No data';
  String get attendanceReportDiligent =>
      _localizedValues[locale.languageCode]?['attendanceReportDiligent'] ??
      'Diligent';
  String get attendanceReportModeratelyDiligent =>
      _localizedValues[locale
          .languageCode]?['attendanceReportModeratelyDiligent'] ??
      'Moderately diligent';
  String get attendanceReportNotDiligent =>
      _localizedValues[locale.languageCode]?['attendanceReportNotDiligent'] ??
      'Not diligent';
  String get attendanceReportSundayShort =>
      _localizedValues[locale.languageCode]?['attendanceReportSundayShort'] ??
      'Sun';
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
      _localizedValues[locale.languageCode]?['trainingReport'] ??
      'Training Report';
  String get memberReport =>
      _localizedValues[locale.languageCode]?['memberReport'] ?? 'Member Report';
  String get updateReport =>
      _localizedValues[locale.languageCode]?['updateReport'] ?? 'Update Report';
  String get createReportTitle =>
      _localizedValues[locale.languageCode]?['createReportTitle'] ??
      'Create Report';
  String get reportTitle =>
      _localizedValues[locale.languageCode]?['reportTitle'] ?? 'Title';
  String get reportTitleRequired =>
      _localizedValues[locale.languageCode]?['reportTitleRequired'] ??
      'Title is required';
  String get monthlyReport =>
      _localizedValues[locale.languageCode]?['monthlyReport'] ??
      'Monthly Report';
  String get yearlyReport =>
      _localizedValues[locale.languageCode]?['yearlyReport'] ?? 'Yearly Report';
  String get year => _localizedValues[locale.languageCode]?['year'] ?? 'Year';
  String get month =>
      _localizedValues[locale.languageCode]?['month'] ?? 'Month';
  String get selectMonth =>
      _localizedValues[locale.languageCode]?['selectMonth'] ?? 'Select month';
  String get pleaseSelectMonth =>
      _localizedValues[locale.languageCode]?['pleaseSelectMonth'] ??
      'Please select a month';
  String get summaryReportGenerated =>
      _localizedValues[locale.languageCode]?['summaryReportGenerated'] ??
      'Summary report generated successfully';
  String get errorGeneratingSummaryReport =>
      _localizedValues[locale.languageCode]?['errorGeneratingSummaryReport'] ??
      'Error generating report';
  String get reportCreated =>
      _localizedValues[locale.languageCode]?['reportCreated'] ??
      'Report created successfully';
  String get reportUpdated =>
      _localizedValues[locale.languageCode]?['reportUpdated'] ??
      'Report updated successfully';
  String get errorCreatingReport =>
      _localizedValues[locale.languageCode]?['errorCreatingReport'] ??
      'Error creating report';
  String get errorUpdatingReport =>
      _localizedValues[locale.languageCode]?['errorUpdatingReport'] ??
      'Error updating report';
  String get errorLoadingReport =>
      _localizedValues[locale.languageCode]?['errorLoadingReport'] ??
      'Error loading report';
  String get errorLoadingData =>
      _localizedValues[locale.languageCode]?['errorLoadingData'] ??
      'Error loading data';
  String get failedToGetDepartment =>
      _localizedValues[locale.languageCode]?['failedToGetDepartment'] ??
      'Failed to get department';
  String get reportGeneratedWithPath =>
      _localizedValues[locale.languageCode]?['reportGeneratedWithPath'] ??
      'Report generated successfully: {path}';
  String reportGeneratedWithPathString(String path) =>
      reportGeneratedWithPath.replaceAll('{path}', path);

  static const Map<String, Map<String, String>> _literalValues = {
    'fr': {
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
    },
    'es': {
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
    return AppLocalizations.supportedLocales.contains(locale);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;

  String tr(String fallback, [Map<String, Object?> params = const {}]) {
    return l10n.translate(fallback, params);
  }
}
