import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/routes/route_names.dart';
import '../../../services/auth_service.dart';

/// Desktop/Web forgot password. Same behaviour as [ForgotPasswordPage].
class DesktopForgotPasswordPage extends StatefulWidget {
  const DesktopForgotPasswordPage({super.key});

  @override
  State<DesktopForgotPasswordPage> createState() =>
      _DesktopForgotPasswordPageState();
}

class _DesktopForgotPasswordPageState extends State<DesktopForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleForgotPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _emailSent = false;
    });

    try {
      await AuthService.forgotPassword(email: _emailController.text.trim());
      if (mounted) {
        setState(() {
          _isLoading = false;
          _emailSent = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.paddingLG),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_emailSent) ...[
                    Icon(
                      Icons.check_circle_outline,
                      size: 80,
                      color: AppColors.success,
                    ),
                    const SizedBox(height: AppDimensions.spacingXL),
                    Text(
                      'Email Sent!',
                      style: theme.textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppDimensions.spacingMD),
                    Text(
                      'Please check your email for the password reset token. You\'ll need to enter it on the next screen.',
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppDimensions.spacingXXL),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pushReplacementNamed(
                          RouteNames.desktopResetPassword,
                          arguments: {'email': _emailController.text.trim()},
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(
                          double.infinity,
                          AppDimensions.buttonHeightLG,
                        ),
                      ),
                      child: const Text('Enter Reset Token'),
                    ),
                    const SizedBox(height: AppDimensions.spacingMD),
                    TextButton(
                      onPressed: () => Navigator.of(
                        context,
                      ).pushReplacementNamed(RouteNames.desktopLogin),
                      child: const Text('Back to Login'),
                    ),
                  ] else ...[
                    Icon(
                      Icons.lock_reset_outlined,
                      size: 80,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: AppDimensions.spacingXL),
                    Text(
                      localizations?.forgotPassword ?? 'Forgot Password',
                      style: theme.textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppDimensions.spacingSM),
                    Text(
                      'Enter your email and we\'ll send you a token to reset your password.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppDimensions.spacingXXL),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return localizations?.emailRequired ??
                              'Email is required';
                        }
                        if (!value.contains('@')) {
                          return localizations?.invalidEmail ?? 'Invalid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppDimensions.spacingXL),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleForgotPassword,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(
                          double.infinity,
                          AppDimensions.buttonHeightLG,
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Send Reset Link'),
                    ),
                    const SizedBox(height: AppDimensions.spacingMD),
                    TextButton(
                      onPressed: () => Navigator.of(
                        context,
                      ).pushReplacementNamed(RouteNames.desktopLogin),
                      child: const Text('Back to Login'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
