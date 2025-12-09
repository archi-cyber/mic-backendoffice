import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/routes/route_names.dart';
import '../../config/app_config.dart';
import '../../providers/auth_provider.dart';

/// Splash screen shown when the app first launches
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

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
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
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
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    // Navigate based on auth status
    if (authProvider.isAuthenticated && authProvider.currentUser != null) {
      // Check if password change is required
      if (authProvider.mustChangePassword) {
        Navigator.of(context).pushReplacementNamed(RouteNames.changePassword);
      } else {
        Navigator.of(context).pushReplacementNamed(RouteNames.dashboard);
      }
    } else {
      Navigator.of(context).pushReplacementNamed(RouteNames.login);
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
      backgroundColor: AppColors.primary,
      body: Center(
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
                        color: AppColors.surface,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.shadow,
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.church,
                        size: AppDimensions.splashLogoSize * 0.6,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingXL),
                    // App Name
                    Text(
                      AppConfig.appName,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: AppColors.textLight,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingSM),
                    // App Tagline (optional)
                    Text(
                      'Church Administration',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textLight.withOpacity(0.9),
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingXXL),
                    // Loading Indicator
                    const SizedBox(
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
    );
  }
}
