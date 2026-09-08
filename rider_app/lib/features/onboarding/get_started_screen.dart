import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';

/// Rider onboarding screen matching the brand design.
class GetStartedScreen extends StatelessWidget {
  /// Creates the get started screen.
  const GetStartedScreen({super.key});

  static const String _bgAssetPath = 'lib/assets/onboarding/Onboarding-1.png';
  static const String _logoAssetPath = 'lib/assets/martfood_logo_dark.png';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? AppTheme.darkSurface : AppTheme.onboardingBackground;
    final titleColor = isDark ? Colors.black : Colors.black87;
    final subtitleColor = isDark ? Colors.black : Colors.black.withValues(alpha: 0.7);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: bgColor,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: bgColor,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Screen background covers full screen edge-to-edge
            Positioned.fill(
              child: Image.asset(
                _bgAssetPath,
                alignment: Alignment.topCenter,
                fit: BoxFit.cover,
              ),
            ),
            // Content overlay
            SafeArea(
              child: Responsive.maxContainer(
                context: context,
                maxWidth: 640,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isTab = Responsive.isTablet(context);
                    return SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: IntrinsicHeight(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: isTab ? 36.0 : 24.0,
                              vertical: isTab ? 28.0 : 20.0,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Spacer for the top illustration area
                                Spacer(flex: isTab ? 9 : 11),
                                // Logo
                                Image.asset(
                                  _logoAssetPath,
                                  height: isTab ? 46 : 38,
                                  fit: BoxFit.contain,
                                  alignment: Alignment.centerLeft,
                                ),
                                const SizedBox(height: 20),
                                // Heading
                                Text(
                                  'Deliver Happiness,\nEarn More',
                                  style: TextStyle(
                                    fontSize: AppTypography.font(32),
                                    fontWeight: FontWeight.w800,
                                    color: titleColor,
                                    height: 1.18,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                // Subline
                                Text(
                                  'Join thousands of riders delivering food and everyday essentials across your city. Choose when you work, earn on every delivery, and get paid with ease.',
                                  style: TextStyle(
                                    fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                                    fontWeight: FontWeight.w500,
                                    color: subtitleColor,
                                    height: 1.45,
                                  ),
                                ),
                                const Spacer(flex: 1),
                                const SizedBox(height: 24),
                                // Get Started button
                                SizedBox(
                                  width: double.infinity,
                                  height: isTab ? 60 : 56,
                                  child: ElevatedButton(
                                    onPressed: () => context.push('/auth/login'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryPurpleFor(isDark),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                    ),
                                    child: Text(
                                      'Get Started',
                                      style: TextStyle(
                                        fontSize: AppTypography.font(16),
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

