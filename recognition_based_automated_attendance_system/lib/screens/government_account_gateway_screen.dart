import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../config/app_theme.dart';
import '../localization/localization_extensions.dart';
import '../widgets/custom_button.dart';
import '../widgets/language_selector.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/window_title_bar.dart';

enum _GovernmentAuthMode { login, create }

class GovernmentAccountGatewayScreen extends StatefulWidget {
  final String? initialMode;

  const GovernmentAccountGatewayScreen({super.key, this.initialMode});

  @override
  State<GovernmentAccountGatewayScreen> createState() =>
      _GovernmentAccountGatewayScreenState();
}

class _GovernmentAccountGatewayScreenState
    extends State<GovernmentAccountGatewayScreen> {
  late _GovernmentAuthMode _selectedMode;

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.initialMode == 'create'
        ? _GovernmentAuthMode.create
        : _GovernmentAuthMode.login;
  }

  void _openGovernmentIntro() {
    Navigator.pushReplacementNamed(context, '/gov-login-intro');
  }

  void _continue() {
    if (_selectedMode == _GovernmentAuthMode.create) {
      Navigator.pushReplacementNamed(context, '/gov-register');
      return;
    }

    Navigator.pushReplacementNamed(context, '/gov-login');
  }

  @override
  Widget build(BuildContext context) {
    final useDesktopLayout = ResponsiveLayout.isDesktop(context);

    return Scaffold(
      body: Column(
        children: [
          if (ResponsiveLayout.isNativeDesktop()) const WindowTitleBar(),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0C1420),
                    Color(0xFF101D2D),
                    Color(0xFF0E1826),
                  ],
                ),
              ),
              child: Center(
                child: SingleChildScrollView(
                  padding: ResponsiveLayout.pagePadding(
                    context,
                    compact: 16,
                    mobile: 24,
                    tablet: 28,
                    desktop: 40,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: useDesktopLayout ? 720 : 520,
                    ),
                    child: Container(
                      padding: EdgeInsets.all(useDesktopLayout ? 32 : 24),
                      decoration: BoxDecoration(
                        color: AppTheme.bgBase.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: AppTheme.glassBorder),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.26),
                            blurRadius: 30,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                onPressed: _openGovernmentIntro,
                                icon: const Icon(Icons.arrow_back_rounded),
                                color: AppTheme.textSecondary,
                                tooltip: context.t('Back'),
                              ),
                              const Spacer(),
                              const LanguageSelector(compact: true),
                            ],
                          ).animate().fadeIn(delay: 80.ms),
                          const SizedBox(height: 12),
                          Container(
                            width: 74,
                            height: 74,
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryGlow,
                                  blurRadius: 24,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.account_balance_rounded,
                              size: 36,
                              color: Colors.white,
                            ),
                          ).animate().fadeIn(delay: 140.ms).scale(),
                          const SizedBox(height: 24),
                          Text(
                            context.t('Government account access'),
                            style: TextStyle(
                              fontSize: useDesktopLayout ? 34 : 28,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ).animate().fadeIn(delay: 180.ms).slideY(
                            begin: 0.06,
                            end: 0,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            context.t(
                              'Choose whether you want to sign in with your government account or create a new government account first.',
                            ),
                            style: const TextStyle(
                              fontSize: 15,
                              color: AppTheme.textSecondary,
                              height: 1.5,
                            ),
                          ).animate().fadeIn(delay: 240.ms),
                          const SizedBox(height: 28),
                          _GovernmentModeCard(
                            title: context.t('Login with Government Email'),
                            subtitle: context.t(
                              'Open the government sign-in page if you already have an account.',
                            ),
                            icon: Icons.login_rounded,
                            selected: _selectedMode == _GovernmentAuthMode.login,
                            onTap: () {
                              setState(() {
                                _selectedMode = _GovernmentAuthMode.login;
                              });
                            },
                          ).animate().fadeIn(delay: 300.ms).slideY(
                            begin: 0.04,
                            end: 0,
                          ),
                          const SizedBox(height: 14),
                          _GovernmentModeCard(
                            title: context.t('Create Government Account'),
                            subtitle: context.t(
                              'Open the registration page to create your government account.',
                            ),
                            icon: Icons.person_add_alt_1_rounded,
                            selected:
                                _selectedMode == _GovernmentAuthMode.create,
                            onTap: () {
                              setState(() {
                                _selectedMode = _GovernmentAuthMode.create;
                              });
                            },
                          ).animate().fadeIn(delay: 360.ms).slideY(
                            begin: 0.04,
                            end: 0,
                          ),
                          const SizedBox(height: 28),
                          CustomButton(
                            text: _selectedMode == _GovernmentAuthMode.create
                                ? context.t('Create Government Account')
                                : context.t('Login with Government Email'),
                            onPressed: _continue,
                            icon: _selectedMode == _GovernmentAuthMode.create
                                ? Icons.person_add_alt_1_rounded
                                : Icons.arrow_forward_rounded,
                            useGradient: true,
                          ).animate().fadeIn(delay: 420.ms).slideY(
                            begin: 0.04,
                            end: 0,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GovernmentModeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _GovernmentModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: AppTheme.animFast,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: selected ? AppTheme.bgCard : AppTheme.bgElevated,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected ? AppTheme.primaryColor : AppTheme.glassBorder,
              width: selected ? 1.4 : 0.9,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.14),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: AppTheme.animFast,
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: selected
                      ? AppTheme.primaryGradient
                      : AppTheme.surfaceGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: selected ? Colors.white : AppTheme.primaryLight,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? AppTheme.primaryLight : AppTheme.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
