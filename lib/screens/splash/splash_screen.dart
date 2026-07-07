import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/mic_theme.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/navigation/app_navigator.dart';
import '../../core/routes/route_names.dart';
import '../../config/app_config.dart';
import '../../core/platform/platform_capabilities.dart';
import '../../providers/auth_provider.dart';
import '../../services/task_penalty_service.dart';
import '../../services/push_notification_handler.dart';
import '../../widgets/app_logo.dart';
import '../desktop/desktop_shell.dart';

/// Splash screen shown when the app first launches
class SplashScreen extends StatefulWidget {
  SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _navigateToNextScreen();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: AppDimensions.splashAnimationDuration.toInt(),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _animationController.forward();
  }

  Future<void> _navigateToNextScreen() async {
    // Wait for animation to complete
    await Future.delayed(
      Duration(milliseconds: AppDimensions.splashAnimationDuration.toInt()),
    );

    if (!mounted) return;

    // Check authentication status and navigate accordingly
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Wait a bit for auth provider to initialize
    await Future.delayed(Duration(milliseconds: 500));

    if (!mounted) return;

    final width = MediaQuery.of(context).size.width;
    final useDesktop = width >= kDesktopBreakpoint;

    // Navigate based on auth status and screen size (desktop when width >= 500px)
    if (authProvider.isAuthenticated && authProvider.currentUser != null) {
      await TaskPenaltyService.calculatePenaltiesOnStartup();
      if (!mounted) return;

      if (authProvider.mustChangePassword) {
        Navigator.of(context).pushReplacementNamed(RouteNames.changePassword);
      } else {
        final launchMessage = PlatformCapabilities.supportsPushNotifications
            ? await PushNotificationHandler.getInitialMessage()
            : null;
        if (!mounted) return;

        final openNotifications = launchMessage != null;

        if (useDesktop) {
          Navigator.of(context).pushReplacementNamed(
            RouteNames.desktopMain,
            arguments: openNotifications
                ? RouteNames.desktopNotifications
                : null,
          );
        } else {
          Navigator.of(context).pushReplacementNamed(RouteNames.dashboard);
          if (openNotifications) {
            AppNavigator.markPendingNotificationsNavigation();
          }
        }
      }
    } else {
      if (useDesktop) {
        Navigator.of(context).pushReplacementNamed(RouteNames.desktopLogin);
      } else {
        Navigator.of(context).pushReplacementNamed(RouteNames.login);
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: context.mic.brandGradient),
        child: Center(
          child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // App Logo/Icon
                    Container(
                      width: AppDimensions.splashLogoSize,
                      height: AppDimensions.splashLogoSize,
                      decoration: BoxDecoration(
                        color: context.mic.surface,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.shadow,
                            blurRadius: 20,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      padding: EdgeInsets.all(AppDimensions.paddingSM),
                      child: AppLogo(
                        size: AppDimensions.splashLogoSize -
                            (AppDimensions.paddingSM * 2),
                      ),
                    ),
                    SizedBox(height: AppDimensions.spacingXL),
                    // App Name
                    Text(
                      AppConfig.appName,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: AppColors.textLight,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    SizedBox(height: AppDimensions.spacingSM),
                    // App Tagline (optional)
                    Text(
                      'Church Administration',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textLight.withValues(alpha: 0.9),
                        letterSpacing: 1,
                      ),
                    ),
                    SizedBox(height: AppDimensions.spacingXXL),
                    // Loading Indicator
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.textLight,
                        ),
                        strokeWidth: 2,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          ),
        ),
      ),
    );
  }
}
