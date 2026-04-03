import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../localization/localization_extensions.dart';
import '../providers/auth_provider.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_textfield.dart';
import '../widgets/language_selector.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/window_title_bar.dart';

/// Premium Split-Panel Registration Screen
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _departmentController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _departmentController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.register(
      email: _emailController.text.trim(),
      fullName: _nameController.text.trim(),
      password: _passwordController.text,
      phone: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      department: _departmentController.text.trim().isEmpty
          ? null
          : _departmentController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      Navigator.pushReplacementNamed(context, '/face-capture');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.error ?? context.t('Registration failed')),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
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
        // Left — Branding
        Expanded(flex: 4, child: _RegisterBrandingPanel()),
        // Right — Form
        Expanded(
          flex: 6,
          child: Container(
            color: AppTheme.bgBase,
            child: Center(
              child: SingleChildScrollView(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 520),
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
    final t = context.t;

    return Container(
      color: AppTheme.bgBase,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  AppBar(
                    title: Text(t('Create Account')),
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                  ),
                  _buildForm(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    final t = context.t;
    final language = context.language;
    final fullNameLabel = t('Full Name');
    final fullNameHint = t('Enter your full name');
    final phoneOptionalLabel = '${t('Phone Number')} (${t('Optional')})';
    final phoneHint = t('Enter your phone number');
    final departmentOptionalLabel = '${t('Department')} (${t('Optional')})';
    final departmentHint = t('Enter your department');
    final createPasswordHint = t('Create a password');
    final confirmPasswordLabel = t('Confirm Password');
    final confirmPasswordHint = t('Confirm your password');
    final createAccountLabel = t('Create Account');
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
          const SizedBox(height: 16),
          // Header
          Row(
            children: [
              if (useDesktopLayout)
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: AppTheme.textSecondary,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('Create Account'),
                      style: TextStyle(
                        fontSize: useDesktopLayout ? 30 : 26,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t('Set up your account'),
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ).animate().fadeIn(delay: 100.ms),
          const SizedBox(height: 32),

          // Name + Email row (desktop) or stacked (mobile)
          if (useDesktopLayout) ...[
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    label: fullNameLabel,
                    hint: fullNameHint,
                    controller: _nameController,
                    prefixIcon: Icons.person_outline,
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return t('Name is required');
                      }
                      if (value.length < 2) {
                        return t('Name must be at least 2 characters');
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: CustomTextField(
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
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.05, end: 0),
            const SizedBox(height: 16),
            // Phone + Department row
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    label: phoneOptionalLabel,
                    hint: phoneHint,
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    prefixIcon: Icons.phone_outlined,
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: CustomTextField(
                    label: departmentOptionalLabel,
                    hint: departmentHint,
                    controller: _departmentController,
                    prefixIcon: Icons.business_outlined,
                    textInputAction: TextInputAction.next,
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.05, end: 0),
            const SizedBox(height: 16),
            // Password row
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    label: language.tr('password'),
                    hint: createPasswordHint,
                    controller: _passwordController,
                    obscureText: true,
                    prefixIcon: Icons.lock_outline,
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return language.tr('passwordRequired');
                      }
                      if (value.length < 6) {
                        return language.tr('passwordMinLength');
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: CustomTextField(
                    label: confirmPasswordLabel,
                    hint: confirmPasswordHint,
                    controller: _confirmPasswordController,
                    obscureText: true,
                    prefixIcon: Icons.lock_outline,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _register(),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return t('Please confirm');
                      }
                      if (value != _passwordController.text) {
                        return t('Passwords don\'t match');
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.05, end: 0),
          ] else ...[
            // Mobile stacked layout
            CustomTextField(
              label: fullNameLabel,
              hint: fullNameHint,
              controller: _nameController,
              prefixIcon: Icons.person_outline,
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return t('Name is required');
                }
                if (value.length < 2) {
                  return t('Name must be at least 2 characters');
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
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
            ),
            const SizedBox(height: 16),
            CustomTextField(
              label: phoneOptionalLabel,
              hint: phoneHint,
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              prefixIcon: Icons.phone_outlined,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              label: departmentOptionalLabel,
              hint: departmentHint,
              controller: _departmentController,
              prefixIcon: Icons.business_outlined,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              label: language.tr('password'),
              hint: createPasswordHint,
              controller: _passwordController,
              obscureText: true,
              prefixIcon: Icons.lock_outline,
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return language.tr('passwordRequired');
                }
                if (value.length < 6) {
                  return language.tr('passwordMinLength');
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            CustomTextField(
              label: confirmPasswordLabel,
              hint: confirmPasswordHint,
              controller: _confirmPasswordController,
              obscureText: true,
              prefixIcon: Icons.lock_outline,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _register(),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return t('Please confirm your password');
                }
                if (value != _passwordController.text) {
                  return t('Passwords do not match');
                }
                return null;
              },
            ),
          ],
          const SizedBox(height: 28),

          // Register Button
          Consumer<AuthProvider>(
            builder: (context, auth, child) {
              return CustomButton(
                text: createAccountLabel,
                isLoading: auth.isLoading,
                onPressed: _register,
                icon: Icons.person_add_rounded,
                useGradient: true,
              );
            },
          ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.05, end: 0),
          const SizedBox(height: 24),

          // Login Link
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${t('Already have an account?')} ',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Text(
                    language.tr('signIn'),
                    style: TextStyle(
                      color: AppTheme.primaryLight,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ).animate().fadeIn(delay: 600.ms),
        ],
      ),
    );
  }
}

// ─── Registration Branding Panel ────────────────────────────
class _RegisterBrandingPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.t;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F1A2E), Color(0xFF0A0E1A), Color(0xFF1A0F2E)],
        ),
      ),
      child: Stack(
        children: [
          // Glow orb
          Positioned(
            top: -50,
            left: -40,
            child: Container(
              width: 200,
              height: 200,
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
          Positioned(
            bottom: -40,
            right: -30,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.primaryColor.withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: AppTheme.accentGradient,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.secondaryColor.withValues(
                              alpha: 0.3,
                            ),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.person_add_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    )
                    .animate()
                    .fadeIn(delay: 200.ms)
                    .scale(begin: const Offset(0.8, 0.8)),
                const SizedBox(height: 28),
                const Text(
                  'FaceAttend',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.2,
                    letterSpacing: -0.5,
                  ),
                ).animate().fadeIn(delay: 400.ms).slideX(begin: -0.05),
                const SizedBox(height: 12),
                Text(
                  t(
                    'Create your account and start managing attendance effortlessly.',
                  ),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.45),
                    height: 1.5,
                  ),
                ).animate().fadeIn(delay: 500.ms),
                const SizedBox(height: 40),
                // Steps
                _SetupStep(
                  number: '1',
                  title: t('Create your account'),
                  isActive: true,
                  delay: 600,
                ),
                const SizedBox(height: 16),
                _SetupStep(
                  number: '2',
                  title: t('Register your face'),
                  isActive: false,
                  delay: 700,
                ),
                const SizedBox(height: 16),
                _SetupStep(
                  number: '3',
                  title: t('Start taking attendance'),
                  isActive: false,
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

class _SetupStep extends StatelessWidget {
  final String number;
  final String title;
  final bool isActive;
  final int delay;

  const _SetupStep({
    required this.number,
    required this.title,
    required this.isActive,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isActive
                ? AppTheme.primaryColor
                : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: isActive
                ? null
                : Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isActive
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.4),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            color: isActive
                ? Colors.white
                : Colors.white.withValues(alpha: 0.4),
          ),
        ),
      ],
    ).animate().fadeIn(delay: Duration(milliseconds: delay));
  }
}
