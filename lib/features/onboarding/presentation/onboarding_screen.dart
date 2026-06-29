import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../shared/providers/service_providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardData> _pages = [
    OnboardData(
      icon: Icons.notifications_active_rounded,
      title: AppStrings.obTitle1,
      desc: AppStrings.obDesc1,
    ),
    OnboardData(
      icon: Icons.analytics_rounded,
      title: AppStrings.obTitle2,
      desc: AppStrings.obDesc2,
    ),
    OnboardData(
      icon: Icons.description_rounded,
      title: AppStrings.obTitle3,
      desc: AppStrings.obDesc3,
    ),
  ];

  Future<void> _completeOnboarding() async {
    // Request notification permissions
    final permissionService = ref.read(permissionServiceProvider);
    await permissionService.requestNotificationPermission();
    await permissionService.requestCameraPermission();

    // Write completion to settings JSON
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/theme_settings.json');
      Map<String, dynamic> data = {};
      if (await file.exists()) {
        final contents = await file.readAsString();
        data = Map<String, dynamic>.from(jsonDecode(contents));
      }
      data['isOnboardingCompleted'] = true;
      await file.writeAsString(jsonEncode(data));
    } catch (_) {}

    if (mounted) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (_currentPage < _pages.length - 1)
            TextButton(
              onPressed: _completeOnboarding,
              child: const Text(
                AppStrings.skip,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  final data = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF141B2D) : const Color(0xFFEFF6FF),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            data.icon,
                            size: 64,
                            color: isDark ? AppColors.primaryBlueDark : AppColors.primaryBlue,
                          ),
                        ),
                        const SizedBox(height: 48),
                        Text(
                          data.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          data.desc,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(40.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 8),
                        height: 8,
                        width: _currentPage == index ? 24 : 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? (isDark ? AppColors.primaryBlueDark : AppColors.primaryBlue)
                              : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: () {
                      if (_currentPage < _pages.length - 1) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeIn,
                        );
                      } else {
                        _completeOnboarding();
                      }
                    },
                    child: Text(
                      _currentPage == _pages.length - 1 ? AppStrings.getStarted : AppStrings.next,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardData {
  final IconData icon;
  final String title;
  final String desc;

  OnboardData({required this.icon, required this.title, required this.desc});
}
