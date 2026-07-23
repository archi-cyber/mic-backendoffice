import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/mic_theme.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/routes/route_names.dart';
import '../../../services/auth_service.dart';

/// Desktop/Web reset password. Same behaviour as [ResetPasswordPage].
class DesktopResetPasswordPage extends StatefulWidget {
  final String? email;

  DesktopResetPasswordPage({super.key, this.email});

  @override
  State<DesktopResetPasswordPage> createState() =>
      _DesktopResetPasswordPageState();
}

class _DesktopResetPasswordPageState extends State<DesktopResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _tokenController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _passwordReset = false;

  @override
  void initState() {
    super.initState();
    if (widget.email != null) _emailController.text = widget.email!;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _tokenController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleResetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await AuthService.resetPassword(
        token: _tokenController.text.trim(),
        email: _emailController.text.trim(),
        newPassword: _passwordController.text.trim(),
      );
      if (mounted) {
        setState(() {
          _isLoading = false;
          _passwordReset = true;
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

    if (_passwordReset) {
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
                    Icons.check_circle_outline,
                    size: 80,
                    color: AppColors.success,
                  ),
                  SizedBox(height: AppDimensions.spacingXL),
                  Text(
                    context.tr('Password Reset Successful!'),
                    style: theme.textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: AppDimensions.spacingMD),
                  Text(
                    context.tr(
                      'You can now sign in with your new password.',
                    ),
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: AppDimensions.spacingXXL),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        RouteNames.desktopLogin,
                        (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(
                        double.infinity,
                        AppDimensions.buttonHeightLG,
                      ),
                    ),
                    child: Text(context.tr('Go to Login')),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(AppDimensions.paddingLG),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.lock_reset_outlined,
                    size: 80,
                    color: AppColors.primary,
                  ),
                  SizedBox(height: AppDimensions.spacingXL),
                  Text(
                    context.tr('Set New Password'),
                    style: theme.textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: AppDimensions.spacingSM),
                  Text(
                    context.tr(
                      'Enter the token from your email and your new password.',
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
                      border: OutlineInputBorder(),
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
                  SizedBox(height: AppDimensions.spacingMD),
                  TextFormField(
                    controller: _tokenController,
                    decoration: InputDecoration(
                      labelText: context.tr('Reset Token'),
                      prefixIcon: Icon(Icons.vpn_key_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return context.tr('Token is required');
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: AppDimensions.spacingMD),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: context.tr('New Password'),
                      prefixIcon: Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return context.tr('Password is required');
                      }
                      if (value.length < 6) {
                        return context.tr(
                          'Password must be at least 6 characters',
                        );
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: AppDimensions.spacingMD),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    decoration: InputDecoration(
                      labelText: context.tr('Confirm Password'),
                      prefixIcon: Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => setState(
                          () => _obscureConfirmPassword =
                              !_obscureConfirmPassword,
                        ),
                      ),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return context.tr('Please confirm your password');
                      }
                      if (value != _passwordController.text) {
                        return context.tr('Passwords do not match');
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: AppDimensions.spacingXL),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleResetPassword,
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
                        : Text(context.tr('Reset Password')),
                  ),
                  SizedBox(height: AppDimensions.spacingMD),
                  TextButton(
                    onPressed: () => Navigator.of(
                      context,
                    ).pushReplacementNamed(RouteNames.desktopLogin),
                    child: Text(context.tr('Back to Login')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
