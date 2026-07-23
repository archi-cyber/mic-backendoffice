import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/mic_theme.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/routes/route_names.dart';
import '../../services/auth_service.dart';

/// Forgot password screen
class ForgotPasswordPage extends StatefulWidget {
  ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Forgot Password')),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(AppDimensions.paddingLG),
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
                    SizedBox(height: AppDimensions.spacingXL),
                    Text(
                      context.tr('Email Sent!'),
                      style: theme.textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: AppDimensions.spacingMD),
                    Text(
                      context.tr(
                        'Please check your email for the password reset token. You\'ll need to enter it on the next screen.',
                      ),
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: AppDimensions.spacingXXL),
                    ElevatedButton(
                      onPressed: () {
                        // Navigate to reset password page with the email
                        Navigator.of(context).pushReplacementNamed(
                          RouteNames.resetPassword,
                          arguments: {'email': _emailController.text.trim()},
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(
                          double.infinity,
                          AppDimensions.buttonHeightLG,
                        ),
                      ),
                      child: Text(context.tr('Enter Reset Token')),
                    ),
                    SizedBox(height: AppDimensions.spacingMD),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(context.tr('Back to Login')),
                    ),
                  ] else ...[
                    Icon(
                      Icons.lock_reset_outlined,
                      size: 80,
                      color: AppColors.primary,
                    ),
                    SizedBox(height: AppDimensions.spacingXL),
                    Text(
                      context.tr('Reset Password'),
                      style: theme.textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: AppDimensions.spacingSM),
                    Text(
                      context.tr(
                        'Enter your email address and we\'ll send you a token to reset your password.',
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: context.mic.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: AppDimensions.spacingXXL),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: context.tr('Email'),
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return context.tr('Email is required');
                        }
                        if (!value.contains('@')) {
                          return context.tr('Invalid email format');
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: AppDimensions.spacingXL),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleForgotPassword,
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(
                          double.infinity,
                          AppDimensions.buttonHeightLG,
                        ),
                      ),
                      child: _isLoading
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(context.tr('Send Reset Link')),
                    ),
                    SizedBox(height: AppDimensions.spacingMD),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(context.tr('Back to Login')),
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
