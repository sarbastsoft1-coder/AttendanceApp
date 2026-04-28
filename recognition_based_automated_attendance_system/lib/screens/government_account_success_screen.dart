import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../config/app_theme.dart';
import '../localization/localization_extensions.dart';
import '../widgets/custom_button.dart';
import '../widgets/language_selector.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/window_title_bar.dart';

class GovernmentAccountSuccessScreen extends StatelessWidget {
  final String? accountName;
  final String? email;
  final String? password;
  final String? adminAccessKey;

  const GovernmentAccountSuccessScreen({
    super.key,
    this.accountName,
    this.email,
    this.password,
    this.adminAccessKey,
  });

  void _openLogin(BuildContext context) {
    Navigator.pushReplacementNamed(
      context,
      '/login',
      arguments: {
        'destination': 'admin',
        if ((email ?? '').trim().isNotEmpty) 'email': email!.trim(),
        if ((password ?? '').isNotEmpty) 'password': password,
        if ((adminAccessKey ?? '').trim().isNotEmpty)
          'adminAccessKey': adminAccessKey!.trim(),
        'message':
            'Government admin account created successfully. Continue with the main login page.',
      },
    );
  }

  void _openGovernmentEntry(BuildContext context) {
    Navigator.pushReplacementNamed(context, '/gov-login-intro');
  }

  @override
  Widget build(BuildContext context) {
    final useDesktopLayout = ResponsiveLayout.isDesktop(context);
    final displayName = (accountName ?? '').trim();
    final displayEmail = (email ?? '').trim();
    final displayPassword = password ?? '';
    final displayAdminAccessKey = (adminAccessKey ?? '').trim();

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
                    Color(0xFF0D1724),
                    Color(0xFF0F1C2B),
                    Color(0xFF11283A),
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
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Container(
                      padding: EdgeInsets.all(useDesktopLayout ? 34 : 24),
                      decoration: BoxDecoration(
                        color: AppTheme.bgBase.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: AppTheme.glassBorder),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.22),
                            blurRadius: 36,
                            offset: const Offset(0, 18),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                onPressed: () => _openGovernmentEntry(context),
                                icon: const Icon(Icons.arrow_back_rounded),
                                color: AppTheme.textSecondary,
                                tooltip: context.t('Back'),
                              ),
                              const Spacer(),
                              const LanguageSelector(compact: true),
                            ],
                          ).animate().fadeIn(delay: 80.ms),
                          const SizedBox(height: 16),
                          Center(
                            child: Container(
                              width: 86,
                              height: 86,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF1EC7A6),
                                    Color(0xFF2F88FF),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(26),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF1EC7A6,
                                    ).withValues(alpha: 0.25),
                                    blurRadius: 26,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.verified_rounded,
                                size: 42,
                                color: Colors.white,
                              ),
                            ),
                          ).animate().fadeIn(delay: 140.ms).scale(),
                          const SizedBox(height: 24),
                          Text(
                                context.t(
                                  'Government account created successfully',
                                ),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: useDesktopLayout ? 34 : 28,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                  letterSpacing: -0.5,
                                ),
                              )
                              .animate()
                              .fadeIn(delay: 180.ms)
                              .slideY(begin: 0.05, end: 0),
                          const SizedBox(height: 10),
                          Text(
                            context.t(
                              'Your government admin account is ready. This page shows the email, password, and generated admin access key you need for the first sign-in.',
                            ),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 15,
                              color: AppTheme.textSecondary,
                              height: 1.55,
                            ),
                          ).animate().fadeIn(delay: 240.ms),
                          const SizedBox(height: 28),
                          Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  gradient: AppTheme.surfaceGradient,
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                    color: AppTheme.glassBorder,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      context.t('Account Summary'),
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    if (displayName.isNotEmpty)
                                      _SummaryRow(
                                        icon: Icons.account_balance_rounded,
                                        label: context.t('Organization'),
                                        value: displayName,
                                      ),
                                    if (displayName.isNotEmpty &&
                                        displayEmail.isNotEmpty)
                                      const SizedBox(height: 12),
                                    if (displayEmail.isNotEmpty)
                                      _SummaryRow(
                                        icon: Icons.email_outlined,
                                        label: context.t('Government Email'),
                                        value: displayEmail,
                                      ),
                                    if (displayEmail.isNotEmpty &&
                                        displayPassword.isNotEmpty)
                                      const SizedBox(height: 12),
                                    if (displayPassword.isNotEmpty)
                                      _SummaryRow(
                                        icon: Icons.lock_outline,
                                        label: context.t('Password'),
                                        value: displayPassword,
                                        canCopy: true,
                                      ),
                                    if ((displayEmail.isNotEmpty ||
                                            displayPassword.isNotEmpty) &&
                                        displayAdminAccessKey.isNotEmpty)
                                      const SizedBox(height: 12),
                                    if (displayAdminAccessKey.isNotEmpty)
                                      _SummaryRow(
                                        icon: Icons.key_outlined,
                                        label: context.t('Admin Access Key'),
                                        value: displayAdminAccessKey,
                                        canCopy: true,
                                      ),
                                  ],
                                ),
                              )
                              .animate()
                              .fadeIn(delay: 300.ms)
                              .slideY(begin: 0.04, end: 0),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppTheme.bgCard,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: AppTheme.glassBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.t('What you can do next'),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                _NextStepRow(
                                  icon: Icons.groups_2_rounded,
                                  text: context.t(
                                    'Use this account as the main admin access for your organization.',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _NextStepRow(
                                  icon: Icons.share_rounded,
                                  text: context.t(
                                    'You can now share access with students, teachers, and admins in your organization.',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _NextStepRow(
                                  icon: Icons.login_rounded,
                                  text: context.t(
                                    'Open the main login page where the admin role, email, password, and generated key are ready to use.',
                                  ),
                                ),
                              ],
                            ),
                          ).animate().fadeIn(delay: 360.ms).slideY(begin: 0.04, end: 0),
                          const SizedBox(height: 28),
                          CustomButton(
                                text: context.t('Open Main Login Page'),
                                onPressed: () => _openLogin(context),
                                icon: Icons.arrow_forward_rounded,
                                useGradient: true,
                              )
                              .animate()
                              .fadeIn(delay: 420.ms)
                              .slideY(begin: 0.04, end: 0),
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

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool canCopy;

  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
    this.canCopy = false,
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
            color: AppTheme.primaryColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: AppTheme.primaryLight, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
        if (canCopy)
          IconButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: value));
              if (!context.mounted) {
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$label copied'),
                  backgroundColor: AppTheme.successColor,
                ),
              );
            },
            icon: const Icon(Icons.copy_rounded),
            color: AppTheme.textSecondary,
            tooltip: context.t('Copy'),
          ),
      ],
    );
  }
}

class _NextStepRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _NextStepRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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
            text,
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
