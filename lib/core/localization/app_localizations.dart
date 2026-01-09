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
    Locale('en', ''), // English
    Locale('fr', ''), // French
    Locale('es', ''), // Spanish
  ];

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
      _localizedValues[locale.languageCode]?['addDepartment'] ?? 'Add Department';
  String get editDepartment =>
      _localizedValues[locale.languageCode]?['editDepartment'] ?? 'Edit Department';
  String get departmentName =>
      _localizedValues[locale.languageCode]?['departmentName'] ?? 'Department Name';
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
      _localizedValues[locale.languageCode]?['departmentFiles'] ?? 'Department Files';
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
  String get view =>
      _localizedValues[locale.languageCode]?['view'] ?? 'View';
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
  String get role =>
      _localizedValues[locale.languageCode]?['role'] ?? 'Role';
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
      _localizedValues[locale.languageCode]?['changePassword'] ?? 'Change Password';
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
      _localizedValues[locale.languageCode]?['generateReport'] ?? 'Generate Report';
  String get taskCompletion =>
      _localizedValues[locale.languageCode]?['taskCompletion'] ?? 'Task Completion';
  String get total =>
      _localizedValues[locale.languageCode]?['total'] ?? 'Total';
  String get completed =>
      _localizedValues[locale.languageCode]?['completed'] ?? 'Completed';
  String get pending =>
      _localizedValues[locale.languageCode]?['pending'] ?? 'Pending';
  String get inProgress =>
      _localizedValues[locale.languageCode]?['inProgress'] ?? 'In Progress';
  String get noTasks =>
      _localizedValues[locale.languageCode]?['noTasks'] ?? 'No tasks in this department';

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
      _localizedValues[locale.languageCode]?['generatingPdf'] ?? 'Generating PDF...';
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
      _localizedValues[locale.languageCode]?['phoneOrEmail'] ?? 'Email or Phone';

  // Update
  String get update =>
      _localizedValues[locale.languageCode]?['update'] ?? 'Update';
  String get add =>
      _localizedValues[locale.languageCode]?['add'] ?? 'Add';
  String get name =>
      _localizedValues[locale.languageCode]?['name'] ?? 'Name';
  String get nameRequired =>
      _localizedValues[locale.languageCode]?['nameRequired'] ?? 'Name is required';

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
  String get ok =>
      _localizedValues[locale.languageCode]?['ok'] ?? 'OK';

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
      'errorAdminOrLeaderRequired': 'Only admins or leaders can perform this action.',
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
      'deleteDepartmentConfirm': 'Are you sure you want to delete this department? This will deactivate it.',
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
      'removeMemberConfirm': 'Are you sure you want to remove {name} from this department?',
      'deleteMember': 'Delete Member',
      'deleteMemberConfirmation': 'Are you sure you want to delete {name}? This action cannot be undone.',
      'memberDeletedSuccessfully': 'Member deleted successfully',
      // Password Change
      'changePassword': 'Change Password',
      'changePasswordRequired': 'Change Password Required',
      'changePasswordMessage': 'You must change your password before continuing.',
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
      'someDocumentsFailed': 'Department created, but some documents failed to upload',
      'documentUploadErrors': 'Document Upload Errors',
      'documentsFailedMessage': 'The department was created, but the following documents failed to upload:',
      'canAddDocumentsLater': 'You can add these documents later by editing the department.',
      'ok': 'OK',
      'optional': '(Optional)',
      'enterDepartmentName': 'Enter the name of the department',
      'optionalDescription': 'Optional description for the department',
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
      'errorAdminOrLeaderRequired': 'Solo administradores o líderes pueden realizar esta acción.',
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
      'deleteDepartmentConfirm': '¿Estás seguro de que deseas eliminar este departamento? Esto lo desactivará.',
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
      'allMembersInDepartment': 'Todos los miembros ya están en este departamento',
      'removeMemberConfirm': '¿Estás seguro de que deseas eliminar a {name} de este departamento?',
      'deleteMember': 'Eliminar Miembro',
      'deleteMemberConfirmation': '¿Estás seguro de que deseas eliminar a {name}? Esta acción no se puede deshacer.',
      'memberDeletedSuccessfully': 'Miembro eliminado exitosamente',
      // Password Change
      'changePassword': 'Cambiar Contraseña',
      'changePasswordRequired': 'Cambio de Contraseña Requerido',
      'changePasswordMessage': 'Debes cambiar tu contraseña antes de continuar.',
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
      'someDocumentsFailed': 'Departamento creado, pero algunos documentos fallaron al subir',
      'documentUploadErrors': 'Errores al Subir Documentos',
      'documentsFailedMessage': 'El departamento fue creado, pero los siguientes documentos fallaron al subir:',
      'canAddDocumentsLater': 'Puedes agregar estos documentos más tarde editando el departamento.',
      'ok': 'OK',
      'optional': '(Opcional)',
      'enterDepartmentName': 'Ingresa el nombre del departamento',
      'optionalDescription': 'Descripción opcional para el departamento',
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
      'errorEmailNotConfirmed': 'Veuillez confirmer votre e-mail pour continuer.',
      'errorUserNotFound': 'Utilisateur introuvable.',
      'errorAccountCreationFailed': 'Échec de la création du compte.',
      'errorDuplicateEmail': 'L\'e-mail est déjà utilisé.',
      'errorPermissionDenied': 'Vous n\'avez pas la permission pour cette action.',
      'errorOperationFailed': 'Opération échouée. Veuillez réessayer.',
      'errorInvalidCredentials': 'E-mail ou mot de passe invalide.',
      'errorPasswordResetFailed': 'Échec de la réinitialisation du mot de passe.',
      'errorMustBeLoggedIn': 'Veuillez vous connecter pour continuer.',
      'errorAdminOrLeaderRequired': 'Seuls les administrateurs ou les dirigeants peuvent effectuer cette action.',
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
      'deleteDepartmentConfirm': 'Êtes-vous sûr de vouloir supprimer ce département? Cela le désactivera.',
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
      'allMembersInDepartment': 'Tous les membres sont déjà dans ce département',
      'removeMemberConfirm': 'Êtes-vous sûr de vouloir retirer {name} de ce département?',
      'deleteMember': 'Supprimer le Membre',
      'deleteMemberConfirmation': 'Êtes-vous sûr de vouloir supprimer {name}? Cette action ne peut pas être annulée.',
      'memberDeletedSuccessfully': 'Membre supprimé avec succès',
      // Password Change
      'changePassword': 'Changer le Mot de Passe',
      'changePasswordRequired': 'Changement de Mot de Passe Requis',
      'changePasswordMessage': 'Vous devez changer votre mot de passe avant de continuer.',
      'newPassword': 'Nouveau Mot de Passe',
      'confirmPassword': 'Confirmer le Nouveau Mot de Passe',
      'newPasswordRequired': 'Le nouveau mot de passe est requis',
      'passwordMinLength': 'Le mot de passe doit contenir au moins 6 caractères',
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
      'someDocumentsFailed': 'Département créé, mais certains documents n\'ont pas pu être téléchargés',
      'documentUploadErrors': 'Erreurs de Téléchargement de Documents',
      'documentsFailedMessage': 'Le département a été créé, mais les documents suivants n\'ont pas pu être téléchargés:',
      'canAddDocumentsLater': 'Vous pouvez ajouter ces documents plus tard en modifiant le département.',
      'ok': 'OK',
      'optional': '(Optionnel)',
      'enterDepartmentName': 'Entrez le nom du département',
      'optionalDescription': 'Description optionnelle pour le département',
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
