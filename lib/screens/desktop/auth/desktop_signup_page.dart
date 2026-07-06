import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/mic_theme.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/routes/route_names.dart';
import '../../../core/localization/app_localizations.dart';

/// Desktop/Web signup. This app uses admin-created accounts; signup is informational.
class DesktopSignupPage extends StatelessWidget {
  DesktopSignupPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(AppDimensions.paddingLG),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.person_add_outlined,
                  size: 64,
                  color: AppColors.primary,
                ),
                SizedBox(height: AppDimensions.spacingXL),
                Text(
                  'Create an account',
                  style: theme.textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: AppDimensions.spacingMD),
                Text(
                  'Accounts are created by your administrator. '
                  'If you need access, please contact your church admin to get a login.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: context.mic.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: AppDimensions.spacingXXL),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(
                      context,
                    ).pushReplacementNamed(RouteNames.desktopLogin);
                  },
                  icon: Icon(Icons.arrow_back),
                  label: Text(context.tr('Back to Login')),
                  style: OutlinedButton.styleFrom(
                    minimumSize: Size(
                      double.infinity,
                      AppDimensions.buttonHeightLG,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
