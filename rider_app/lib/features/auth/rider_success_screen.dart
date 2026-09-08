import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';
import 'package:shared_widgets/widgets/custom_button.dart';

import '../../providers/session_provider.dart';

/// Post-registration success banner step before entering the shell.
class RiderSuccessScreen extends ConsumerWidget {
  /// Creates the success screen.
  const RiderSuccessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Responsive.maxContainer(
        context: context,
        maxWidth: 450,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.verified_outlined,
                  size: 88, color: AppTheme.primaryColor),
              const SizedBox(height: 20),
              Text(
                'You’re all set',
                textAlign: TextAlign.center,
                style: AppTextStyles.headlineSmall.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your rider profile is ready. You can complete identity verification anytime from Account.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 28),
              CustomButton(
                text: 'Go to home',
                onPressed: () {
                  ref.read(sessionProvider.notifier).signIn();
                  context.go('/home');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
