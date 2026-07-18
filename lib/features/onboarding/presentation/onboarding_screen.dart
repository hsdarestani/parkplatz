import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../config/brand_config.dart';
import '../../../config/design_tokens.dart';

const onboardingCompletedKey = 'freiraum_onboarding_completed';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final controller = PageController();
  int page = 0;
  bool busy = false;

  static const slides = [
    _OnboardingSlide(
      icon: Icons.search_rounded,
      title: 'Parken ohne Umwege',
      text:
          'Finde freie private Stellplätze in deiner Nähe und prüfe Preis, Maße und Verfügbarkeit vor der Buchung.',
    ),
    _OnboardingSlide(
      icon: Icons.swap_horiz_rounded,
      title: 'Direkt und transparent zahlen',
      text:
          'Du zahlst direkt an den Anbieter per PayPal, Revolut oder SEPA. FREIRAUM verwahrt kein Kundengeld.',
    ),
    _OnboardingSlide(
      icon: Icons.qr_code_2_rounded,
      title: 'Sicher ankommen',
      text:
          'Nach der Zahlungsbestätigung erhältst du die genaue Zufahrt, Zugangshinweise und deinen Parking Pass.',
    ),
  ];

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> finish() async {
    if (busy) return;
    setState(() => busy = true);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(onboardingCompletedKey, true);
    if (mounted) context.go('/discover');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: T.porcelain,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 16, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        BrandConfig.name,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.4,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: finish,
                      child: const Text('Überspringen'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: controller,
                  itemCount: slides.length,
                  onPageChanged: (value) => setState(() => page = value),
                  itemBuilder: (context, index) => _SlideView(slide: slides[index]),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        slides.length,
                        (index) => AnimatedContainer(
                          duration: T.normal,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: page == index ? 30 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: page == index ? T.mint : T.lineStrong,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: busy
                            ? null
                            : page == slides.length - 1
                                ? finish
                                : () => controller.nextPage(
                                      duration: T.normal,
                                      curve: T.emphasized,
                                    ),
                        icon: busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(
                                page == slides.length - 1
                                    ? Icons.check_rounded
                                    : Icons.arrow_forward_rounded,
                              ),
                        label: Text(
                          page == slides.length - 1
                              ? 'FREIRAUM entdecken'
                              : 'Weiter',
                        ),
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

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});

  final _OnboardingSlide slide;

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 190,
                  height: 190,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [T.ink, T.inkSoft],
                    ),
                    borderRadius: BorderRadius.circular(54),
                    boxShadow: T.shadowLarge,
                  ),
                  child: Icon(slide.icon, size: 88, color: T.mint),
                ),
                const SizedBox(height: 34),
                Text(
                  slide.title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontSize: 38,
                      ),
                ),
                const SizedBox(height: 14),
                Text(
                  slide.text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: T.muted,
                    fontSize: 17,
                    height: 1.55,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _OnboardingSlide {
  const _OnboardingSlide({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;
}
