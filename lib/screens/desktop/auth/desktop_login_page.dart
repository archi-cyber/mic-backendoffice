import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/mic_theme.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/error_message_helper.dart';
import '../../../core/routes/route_names.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/app_logo.dart';

/// Desktop/Web login (width >= 500px). Same behaviour as [LoginPage], desktop layout.
class DesktopLoginPage extends StatefulWidget {
  DesktopLoginPage({super.key});

  @override
  State<DesktopLoginPage> createState() => _DesktopLoginPageState();
}

class _DesktopLoginPageState extends State<DesktopLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (success) {
      if (authProvider.mustChangePassword) {
        Navigator.of(context).pushReplacementNamed(RouteNames.changePassword);
      } else {
        Navigator.of(context).pushReplacementNamed(RouteNames.desktopMain);
      }
    } else {
      final errorMessage = ErrorMessageHelper.getErrorMessage(
        context,
        authProvider.errorMessage,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: context.mic.background,
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
                  const AppLogo(size: 64),
                  SizedBox(height: AppDimensions.spacingXL),
                  Text(
                    localizations?.welcome ?? 'Welcome',
                    style: theme.textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: AppDimensions.spacingSM),
                  Text(
                    localizations?.signIn ?? 'Sign In',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: context.mic.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: AppDimensions.spacingXL),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: localizations?.email ?? 'Email or Phone',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return localizations?.emailRequired ??
                            'Email is required';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: AppDimensions.spacingMD),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: localizations?.password ?? 'Password',
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
                        return localizations?.passwordRequired ??
                            'Password is required';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: AppDimensions.spacingSM),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(
                          context,
                        ).pushNamed(RouteNames.desktopForgotPassword);
                      },
                      child: Text(
                        localizations?.forgotPassword ?? 'Forgot Password?',
                      ),
                    ),
                  ),
                  SizedBox(height: AppDimensions.spacingLG),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
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
                        : Text(localizations?.signIn ?? 'Sign In'),
                  ),
                  SizedBox(height: AppDimensions.spacingMD),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pushNamed(RouteNames.desktopSignup);
                    },
                    child: Text(context.tr('Create an account')),
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
