import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../config/app_theme.dart';
import '../localization/localization_extensions.dart';
import '../widgets/custom_button.dart';
import '../widgets/language_selector.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/window_title_bar.dart';

class GovernmentLoginIntroScreen extends StatelessWidget {
  const GovernmentLoginIntroScreen({super.key});

  void _openLogin(BuildContext context) {
    Navigator.pushReplacementNamed(
      context,
      '/gov-account-gateway',
      arguments: const {'mode': 'login'},
    );
  }

  void _openStudentFaceScan(BuildContext context) {
    Navigator.pushReplacementNamed(context, '/student-face-scan');
  }

  void _openRegister(BuildContext context) {
    Navigator.pushReplacementNamed(
      context,
      '/gov-account-gateway',
      arguments: const {'mode': 'create'},
    );
  }

  @override
  Widget build(BuildContext context) {
    final useDesktopLayout = ResponsiveLayout.isDesktop(context);

    return Scaffold(
      body: Column(
        children: [
          if (ResponsiveLayout.isNativeDesktop()) const WindowTitleBar(),
          Expanded(
            child: useDesktopLayout
                ? _buildDesktopLayout(context)
                : _buildMobileLayout(context),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Row(
      children: [
        Expanded(flex: 4, child: const _GovernmentBrandingPanel()),
        Expanded(
          flex: 6,
          child: Container(
            color: AppTheme.bgBase,
            child: Center(
              child: SingleChildScrollView(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 460),
                  padding: const EdgeInsets.all(40),
                  child: _GovernmentIntroCard(
                    onContinue: () => _openLogin(context),
                    onCreateAccount: () => _openRegister(context),
                    onStudentFaceScan: () => _openStudentFaceScan(context),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Container(
      color: AppTheme.bgBase,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: ResponsiveLayout.pagePadding(
            context,
            compact: 16,
            mobile: 24,
            tablet: 24,
            desktop: 24,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: _GovernmentIntroCard(
                onContinue: () => _openLogin(context),
                onCreateAccount: () => _openRegister(context),
                onStudentFaceScan: () => _openStudentFaceScan(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GovernmentIntroCard extends StatelessWidget {
  final VoidCallback onContinue;
  final VoidCallback onCreateAccount;
  final VoidCallback onStudentFaceScan;

  const _GovernmentIntroCard({
    required this.onContinue,
    required this.onCreateAccount,
    required this.onStudentFaceScan,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final isDesktop = ResponsiveLayout.isDesktop(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: const LanguageSelector(compact: true),
        ),
        if (!isDesktop) ...[
          const SizedBox(height: 24),
          Center(
            child: Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryGlow,
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.account_balance_rounded,
                size: 38,
                color: Colors.white,
              ),
            ),
          ),
        ],
        SizedBox(height: isDesktop ? 12 : 24),
        Text(
          t('Create or sign in to your government account'),
          style: TextStyle(
            fontSize: isDesktop ? 32 : 28,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
            letterSpacing: -0.5,
          ),
        ).animate().fadeIn(delay: 120.ms).slideY(begin: 0.08, end: 0),
        const SizedBox(height: 10),
        Text(
          t(
            'If this is your first time, create your government account. Otherwise, sign in with your government email and password.',
          ),
          style: const TextStyle(
            fontSize: 15,
            color: AppTheme.textSecondary,
            height: 1.5,
          ),
        ).animate().fadeIn(delay: 220.ms),
        const SizedBox(height: 24),
        _GovernmentAccessNotice()
            .animate()
            .fadeIn(delay: 280.ms)
            .slideY(begin: 0.05, end: 0),
        const SizedBox(height: 24),
        _GovernmentRequirementsCard()
            .animate()
            .fadeIn(delay: 340.ms)
            .slideY(begin: 0.05, end: 0),
        const SizedBox(height: 32),
        CustomButton(
          text: t('Create Government Account'),
          onPressed: onCreateAccount,
          icon: Icons.person_add_alt_1_rounded,
          useGradient: true,
        ).animate().fadeIn(delay: 420.ms).slideY(begin: 0.05, end: 0),
        const SizedBox(height: 12),
        CustomButton(
          text: t('Student Face Scan'),
          onPressed: onStudentFaceScan,
          icon: Icons.face_retouching_natural,
          backgroundColor: AppTheme.secondaryColor,
        ).animate().fadeIn(delay: 470.ms).slideY(begin: 0.05, end: 0),
        const SizedBox(height: 12),
        CustomButton(
          text: t('Login with Government Email'),
          onPressed: onContinue,
          icon: Icons.arrow_forward_rounded,
          isOutlined: true,
        ).animate().fadeIn(delay: 520.ms).slideY(begin: 0.05, end: 0),
      ],
    );
  }
}

class _GovernmentAccessNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.t;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              color: AppTheme.primaryLight,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('Government account access'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  t(
                    'Use your official government email to create an account the first time, or sign in if you already have one.',
                  ),
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GovernmentRequirementsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.t;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppTheme.surfaceGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('Before you continue'),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          _RequirementRow(
            icon: Icons.email_outlined,
            label: t('Have your government email ready'),
          ),
          const SizedBox(height: 12),
          _RequirementRow(
            icon: Icons.person_add_alt_1_outlined,
            label: t('Create your account first if you are new'),
          ),
          const SizedBox(height: 12),
          _RequirementRow(
            icon: Icons.login_rounded,
            label: t('Login if you already have a government account'),
          ),
        ],
      ),
    );
  }
}

class _RequirementRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _RequirementRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppTheme.primaryLight),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              height: 1.35,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _GovernmentBrandingPanel extends StatelessWidget {
  const _GovernmentBrandingPanel();

  @override
  Widget build(BuildContext context) {
    final t = context.t;

    return LayoutBuilder(
      builder: (context, constraints) {
        final orbLarge = (constraints.maxWidth * 0.38)
            .clamp(160, 220)
            .toDouble();
        final orbSmall = (constraints.maxWidth * 0.3)
            .clamp(130, 170)
            .toDouble();
        final sidePadding = constraints.maxWidth < 420 ? 24.0 : 48.0;

        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF132238), Color(0xFF0A0E1A), Color(0xFF102B3F)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -60,
                right: -30,
                child: Container(
                  width: orbLarge,
                  height: orbLarge,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppTheme.primaryColor.withValues(alpha: 0.14),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -30,
                left: -40,
                child: Container(
                  width: orbSmall,
                  height: orbSmall,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppTheme.secondaryColor.withValues(alpha: 0.12),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(sidePadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                          width: 62,
                          height: 62,
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryGlow,
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.account_balance_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                        )
                        .animate()
                        .fadeIn(delay: 180.ms)
                        .scale(begin: const Offset(0.8, 0.8)),
                    const SizedBox(height: 28),
                    const Text(
                      'FaceAttend',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ).animate().fadeIn(delay: 320.ms).slideX(begin: -0.05),
                    const SizedBox(height: 10),
                    Text(
                      t('Government Attendance Access'),
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withValues(alpha: 0.62),
                      ),
                    ).animate().fadeIn(delay: 420.ms),
                    const SizedBox(height: 40),
                    _BrandingFeature(
                      icon: Icons.shield_outlined,
                      title: t('Protected sign-in experience'),
                      subtitle: t(
                        'Review the access requirements before opening the sign-in form',
                      ),
                      delay: 520,
                    ),
                    const SizedBox(height: 20),
                    _BrandingFeature(
                      icon: Icons.badge_outlined,
                      title: t('Government account access'),
                      subtitle: t(
                        'Use the official credentials assigned to your organization',
                      ),
                      delay: 620,
                    ),
                    const SizedBox(height: 20),
                    _BrandingFeature(
                      icon: Icons.arrow_forward_rounded,
                      title: t('Continue securely'),
                      subtitle: t(
                        'Move to the existing login page when you are ready to sign in',
                      ),
                      delay: 720,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BrandingFeature extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final int delay;

  const _BrandingFeature({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Icon(icon, color: AppTheme.primaryLight, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: Colors.white.withValues(alpha: 0.48),
                    ),
                  ),
                ],
              ),
            ),
          ],
        )
        .animate()
        .fadeIn(delay: Duration(milliseconds: delay))
        .slideX(begin: -0.05);
  }
}
