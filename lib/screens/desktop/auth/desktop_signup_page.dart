import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/routes/route_names.dart';

/// Desktop/Web signup. This app uses admin-created accounts; signup is informational.
class DesktopSignupPage extends StatelessWidget {
  const DesktopSignupPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.paddingLG),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.person_add_outlined,
                  size: 64,
                  color: AppColors.primary,
                ),
                const SizedBox(height: AppDimensions.spacingXL),
                Text(
                  'Create an account',
                  style: theme.textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.spacingMD),
                Text(
                  'Accounts are created by your administrator. '
                  'If you need access, please contact your church admin to get a login.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.spacingXXL),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(
                      context,
                    ).pushReplacementNamed(RouteNames.desktopLogin);
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back to Login'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(
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
