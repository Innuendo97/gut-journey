import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gut_journey/app/branding/brand_mark.dart';
import 'package:gut_journey/app/router.dart';
import 'package:gut_journey/features/onboarding/data/onboarding_state.dart';
import 'package:gut_journey/l10n/generated/app_localizations.dart';

/// Two steps: the value proposition, then the medical disclaimer that must
/// be explicitly accepted before the diary opens.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    await ref.read(onboardingAcceptedProvider.notifier).accept();
    if (mounted) context.go(AppRoutes.today);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: PageView(
          controller: _controller,
          children: [
            _OnboardingPage(
              hero: const BrandMark(size: 96),
              title: l10n.onboardingTitle,
              body: l10n.onboardingPitch,
              action: FilledButton(
                onPressed: () => _controller.nextPage(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                ),
                child: Text(l10n.onboardingContinue),
              ),
            ),
            _OnboardingPage(
              hero: Icon(
                Icons.medical_information_outlined,
                size: 72,
                color: theme.colorScheme.primary,
              ),
              title: l10n.disclaimerTitle,
              body: l10n.disclaimerBody,
              bodyStyle: theme.textTheme.bodyMedium,
              action: FilledButton(
                onPressed: _accept,
                child: Text(l10n.disclaimerAccept),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.hero,
    required this.title,
    required this.body,
    required this.action,
    this.bodyStyle,
  });

  final Widget hero;
  final String title;
  final String body;
  final Widget action;
  final TextStyle? bodyStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: hero),
          const SizedBox(height: 24),
          Text(
            title,
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            body,
            style:
                bodyStyle ??
                theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          action,
        ],
      ),
    );
  }
}
