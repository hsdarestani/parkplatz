import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/brand_config.dart';
import '../../config/design_tokens.dart';
import '../onboarding/presentation/onboarding_screen.dart';

class LaunchScreen extends StatefulWidget {
  const LaunchScreen({super.key});

  @override
  State<LaunchScreen> createState() => _LaunchScreenState();
}

class _LaunchScreenState extends State<LaunchScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController animation;

  @override
  void initState() {
    super.initState();
    animation = AnimationController(vsync: this, duration: T.slow)
      ..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _continue());
  }

  Future<void> _continue() async {
    final disabled = MediaQuery.disableAnimationsOf(context);
    if (!disabled) {
      await Future<void>.delayed(const Duration(milliseconds: 850));
    }
    final preferences = await SharedPreferences.getInstance();
    final completed = preferences.getBool(onboardingCompletedKey) == true;
    if (mounted) context.go(completed ? '/discover' : '/onboarding');
  }

  @override
  void dispose() {
    animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: animation,
                builder: (_, __) => Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: T.mint.withValues(
                        alpha: .4 + animation.value * .4,
                      ),
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: T.mint.withValues(alpha: .2),
                        blurRadius: 24 + animation.value * 20,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.route, color: T.ink, size: 38),
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                BrandConfig.name,
                style: TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                ),
              ),
              const Text(
                BrandConfig.tagline,
                style: TextStyle(fontSize: 16, color: T.muted),
              ),
            ],
          ),
        ),
      );
}
