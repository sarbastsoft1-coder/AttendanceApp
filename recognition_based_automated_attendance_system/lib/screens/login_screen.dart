import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../localization/localization_extensions.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_textfield.dart';
import '../widgets/language_selector.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/window_title_bar.dart';

/// Premium Split-Panel Login Screen for Windows Desktop
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _loadSavedEmail();
  }

  void _loadSavedEmail() {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.isRememberMeEnabled()) {
      final email = authProvider.getLastEmail();
      if (email != null) {
        _emailController.text = email;
        _rememberMe = true;
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final language = context.read<LanguageProvider>();
    final success = await authProvider.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      rememberMe: _rememberMe,
    );

    if (!mounted) return;

    if (success) {
      if (authProvider.hasRegisteredFace) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        Navigator.pushReplacementNamed(context, '/face-capture');
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.error ?? language.tr('loginFailed')),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  void _showForgotPasswordDialog() {
    final forgotEmailController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final language = context.read<LanguageProvider>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(language.tr('forgotPasswordTitle')),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                language.tr('forgotPasswordHelp'),
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              CustomTextField(
                label: language.tr('email'),
                hint: language.tr('enterEmail'),
                controller: forgotEmailController,
                keyboardType: TextInputType.emailAddress,
                prefixIcon: Icons.email_outlined,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return language.tr('pleaseEnterEmail');
                  }
                  if (!value.contains('@')) {
                    return language.tr('pleaseEnterValidEmail');
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(language.tr('cancel')),
          ),
          Consumer<AuthProvider>(
            builder: (context, auth, child) {
              return ElevatedButton(
                onPressed: auth.isLoading
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;

                        final token = await auth.forgotPassword(
                          forgotEmailController.text.trim(),
                        );
                        final success = token != null;

                        if (!context.mounted) return;
                        Navigator.pop(context);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              success
                                  ? language.tr('passwordResetSent')
                                  : auth.error ??
                                        language.tr('failedToSendResetLink'),
                            ),
                            backgroundColor: success
                                ? AppTheme.successColor
                                : AppTheme.errorColor,
                          ),
                        );
                      },
                child: auth.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Text(language.tr('sendResetLink')),
              );
            },
          ),
        ],
      ),
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
                ? _buildDesktopLayout()
                : _buildMobileLayout(),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        Expanded(flex: 4, child: _BrandingPanel()),
        Expanded(
          flex: 6,
          child: Container(
            color: AppTheme.bgBase,
            child: Center(
              child: SingleChildScrollView(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 440),
                  padding: const EdgeInsets.all(40),
                  child: _buildForm(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Container(
      color: AppTheme.bgBase,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: _buildForm(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    final language = context.language;
    final useDesktopLayout = ResponsiveLayout.isDesktop(context);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: const LanguageSelector(compact: true),
          ),
          if (!useDesktopLayout) ...[
            const SizedBox(height: 24),
            Center(
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryGlow,
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.face_retouching_natural,
                  size: 40,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ] else
            const SizedBox(height: 12),
          Text(
            language.tr('welcomeBack'),
            style: TextStyle(
              fontSize: useDesktopLayout ? 32 : 28,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
              letterSpacing: -0.5,
            ),
          ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0),
          const SizedBox(height: 8),
          Text(
            language.tr('signInTeacherDashboard'),
            style: const TextStyle(fontSize: 15, color: AppTheme.textSecondary),
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 36),
          CustomTextField(
            label: language.tr('email'),
            hint: language.tr('enterEmail'),
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icons.email_outlined,
            textInputAction: TextInputAction.next,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return language.tr('emailRequired');
              }
              if (!RegExp(
                r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
              ).hasMatch(value)) {
                return language.tr('enterValidEmail');
              }
              return null;
            },
          ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.05, end: 0),
          const SizedBox(height: 16),
          CustomTextField(
            label: language.tr('password'),
            hint: language.tr('enterPassword'),
            controller: _passwordController,
            obscureText: true,
            prefixIcon: Icons.lock_outline,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _login(),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return language.tr('passwordRequired');
              }
              if (value.length < 6) {
                return language.tr('passwordMinLength');
              }
              return null;
            },
          ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.05, end: 0),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: _rememberMe,
                    onChanged: (value) {
                      setState(() => _rememberMe = value ?? false);
                    },
                  ),
                  Text(
                    language.tr('rememberMe'),
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: _showForgotPasswordDialog,
                child: Text(
                  language.tr('forgotPassword'),
                  style: TextStyle(color: AppTheme.primaryLight, fontSize: 13),
                ),
              ),
            ],
          ).animate().fadeIn(delay: 500.ms),
          const SizedBox(height: 28),
          Consumer<AuthProvider>(
            builder: (context, auth, child) {
              return CustomButton(
                text: language.tr('signIn'),
                isLoading: auth.isLoading,
                onPressed: _login,
                icon: Icons.login_rounded,
                useGradient: true,
              );
            },
          ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.05, end: 0),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${language.tr('dontHaveAccount')} ',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/register'),
                  child: Text(
                    language.tr('signUp'),
                    style: const TextStyle(
                      color: AppTheme.primaryLight,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ).animate().fadeIn(delay: 700.ms),
        ],
      ),
    );
  }
}

class _BrandingPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final language = context.language;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1033), Color(0xFF0F0A1A), Color(0xFF0A0E1A)],
        ),
      ),
      child: Stack(
        children: [
          CustomPaint(size: Size.infinite, painter: _BrandingDotPainter()),
          Positioned(
            top: -60,
            right: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.primaryColor.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -30,
            left: -50,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.secondaryColor.withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                      width: 60,
                      height: 60,
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
                        Icons.face_retouching_natural,
                        color: Colors.white,
                        size: 32,
                      ),
                    )
                    .animate()
                    .fadeIn(delay: 200.ms)
                    .scale(begin: const Offset(0.8, 0.8)),
                const SizedBox(height: 32),
                const Text(
                  'FaceAttend',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ).animate().fadeIn(delay: 400.ms).slideX(begin: -0.05),
                const SizedBox(height: 8),
                Text(
                  language.tr('teacherAttendanceSystem'),
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w300,
                  ),
                ).animate().fadeIn(delay: 500.ms),
                const SizedBox(height: 48),
                _FeatureItem(
                  icon: Icons.qr_code_scanner_rounded,
                  title: language.tr('smartRoomScanning'),
                  subtitle: language.tr('processEntireHallsSeconds'),
                  delay: 600,
                ),
                const SizedBox(height: 20),
                _FeatureItem(
                  icon: Icons.face_retouching_natural,
                  title: language.tr('faceRecognition'),
                  subtitle: language.tr('automatedStudentIdentification'),
                  delay: 700,
                ),
                const SizedBox(height: 20),
                _FeatureItem(
                  icon: Icons.analytics_rounded,
                  title: language.tr('analyticsDashboard'),
                  subtitle: language.tr('trackAttendanceTrends'),
                  delay: 800,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final int delay;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
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
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.4),
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

class _BrandingDotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.02)
      ..style = PaintingStyle.fill;

    const spacing = 30.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 0.8, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
