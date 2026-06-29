import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../shared/providers/service_providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _controller.forward();
    _bootstrap();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final stopwatch = Stopwatch()..start();

    try {
      // 1. Initialize DB
      await ref.read(isarServiceProvider).init();

      // 2. Initialize Notifications
      await ref.read(notificationServiceProvider).init();

      // 3. Re-scan for missed doses offline
      await ref.read(medicineSchedulerServiceProvider).checkAndMarkMissedDoses();
      
      // 4. Update the schedule queue for the next 7 days
      await ref.read(medicineSchedulerServiceProvider).rescheduleAllActiveMedicines();
    } catch (e) {
      print("Bootstrap error: $e");
    }

    // 5. Check onboarding state
    final isOnboardingDone = await _isOnboardingCompleted();

    // Ensure splash displays for at least 2 seconds
    final elapsed = stopwatch.elapsedMilliseconds;
    if (elapsed < 2000) {
      await Future.delayed(Duration(milliseconds: 2000 - elapsed));
    }

    if (mounted) {
      if (isOnboardingDone) {
        context.go('/home');
      } else {
        context.go('/onboarding');
      }
    }
  }

  Future<bool> _isOnboardingCompleted() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/theme_settings.json');
      if (!await file.exists()) return false;
      final contents = await file.readAsString();
      final data = jsonDecode(contents) as Map<String, dynamic>;
      return data['isOnboardingCompleted'] as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // Elegant minimalist background
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? [AppColors.backgroundDark, const Color(0xFF0A0F1D)]
                      : [const Color(0xFFF8FAFC), const Color(0xFFEFF6FF)],
                ),
              ),
            ),
          ),
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Minimalist health care symbol
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF141B2D) : Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: isDark ? null : [
                          const BoxShadow(
                            color: Color(0x030284C7),
                            blurRadius: 40,
                            spreadRadius: 10,
                          )
                        ],
                      ),
                      child: Icon(
                        Icons.healing_rounded,
                        size: 64,
                        color: isDark ? AppColors.primaryBlueDark : AppColors.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      AppStrings.appName,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                        color: isDark ? Colors.white : AppColors.onBackgroundLight,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppStrings.splashTagline,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isDark ? AppColors.primaryBlueDark : AppColors.primaryBlue,
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
