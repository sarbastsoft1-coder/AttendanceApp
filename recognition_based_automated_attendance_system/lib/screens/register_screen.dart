import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../localization/localization_extensions.dart';
import '../providers/auth_provider.dart';
import 'government_account_success_screen.dart';
import '../utils/input_validators.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_textfield.dart';
import '../widgets/language_selector.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/window_title_bar.dart';

enum _RegisterAccountType { teacher, student, admin }

/// Premium Split-Panel Registration Screen
class RegisterScreen extends StatefulWidget {
  final bool governmentOnly;

  const RegisterScreen({super.key, this.governmentOnly = false});

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
  _RegisterAccountType _selectedAccountType = _RegisterAccountType.teacher;
  bool _didLoadRouteArguments = false;
  bool _governmentOnly = false;

  void _openGovernmentEntry() {
    Navigator.pushReplacementNamed(
      context,
      _governmentOnly ? '/gov-account-gateway' : '/gov-login-intro',
      arguments: _governmentOnly ? const {'mode': 'create'} : null,
    );
  }

  void _openLogin() {
    final destination = _governmentOnly
        ? 'admin'
        : switch (_selectedAccountType) {
            _RegisterAccountType.admin => 'admin',
            _RegisterAccountType.student => 'student',
            _RegisterAccountType.teacher => 'teacher',
          };

    Navigator.pushReplacementNamed(
      context,
      '/login',
      arguments: {'destination': destination},
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoadRouteArguments) {
      return;
    }

    final args = ModalRoute.of(context)?.settings.arguments;
    _governmentOnly = widget.governmentOnly;
    if (args is Map) {
      final governmentOnly = args['governmentOnly'];
      if (governmentOnly is bool) {
        _governmentOnly = widget.governmentOnly || governmentOnly;
      }

      if (_governmentOnly) {
        _selectedAccountType = _RegisterAccountType.admin;
      } else if (args['accountType'] == 'admin') {
        _selectedAccountType = _RegisterAccountType.admin;
      } else if (args['accountType'] == 'student') {
        _selectedAccountType = _RegisterAccountType.student;
      }
    }

    _didLoadRouteArguments = true;
  }

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

  String _generateAdminAccessKey() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();

    String segment(int length) => List.generate(
      length,
      (_) => chars[random.nextInt(chars.length)],
    ).join();

    return 'ADM-${segment(4)}-${segment(4)}-${segment(4)}-${segment(4)}';
  }

  Widget _buildAdminAccessNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.admin_panel_settings_outlined,
              color: AppTheme.primaryLight,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t('Admin accounts are created by admins'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.t(
                    'Public registration creates user accounts only. Admins should use Manage Users to create admin or user accounts, then sign in with the admin access key.',
                  ),
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
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

  Widget _buildStudentAccessNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.school_outlined,
              color: AppTheme.primaryLight,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t('Student accounts see student attendance only'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.t(
                    'Student users can review absent classes and student attendance records after signing in.',
                  ),
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
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

  Widget _buildSelectedAccountNotice() {
    if (_governmentOnly) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.glassBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.account_balance_rounded,
                color: AppTheme.primaryLight,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t('Government account access'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.t(
                      'Use your government email and password to create the first admin account. The admin access key will be generated automatically and shown on the next page.',
                    ),
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
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

    switch (_selectedAccountType) {
      case _RegisterAccountType.student:
        return _buildStudentAccessNotice();
      case _RegisterAccountType.admin:
        return _buildAdminAccessNotice();
      case _RegisterAccountType.teacher:
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.glassBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.badge_outlined,
                  color: AppTheme.primaryLight,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t('Teacher accounts manage attendance'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.t(
                        'Teacher users can sign in, register faces, and manage attendance features.',
                      ),
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.4,
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

  Widget _buildAccountTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.t('Account Type'),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          context.t(
            'Choose whether you are registering as a teacher or student',
          ),
          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 720;
            final cardWidth = isWide
                ? (constraints.maxWidth - 24) / 3
                : (constraints.maxWidth - 12) / 2;

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: cardWidth,
                  child: _RegisterAccountTypeCard(
                    title: context.t('Teacher Account'),
                    subtitle: context.t(
                      'Create a teacher account with full attendance access',
                    ),
                    icon: Icons.badge_outlined,
                    selected:
                        _selectedAccountType == _RegisterAccountType.teacher,
                    onTap: () {
                      setState(
                        () =>
                            _selectedAccountType = _RegisterAccountType.teacher,
                      );
                    },
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _RegisterAccountTypeCard(
                    title: context.t('Student Account'),
                    subtitle: context.t(
                      'Create a student account with absent classes only',
                    ),
                    icon: Icons.school_outlined,
                    selected:
                        _selectedAccountType == _RegisterAccountType.student,
                    onTap: () {
                      setState(
                        () =>
                            _selectedAccountType = _RegisterAccountType.student,
                      );
                    },
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _RegisterAccountTypeCard(
                    title: context.t('Admin Account'),
                    subtitle: context.t(
                      'Admins sign in with admin access and are not created publicly',
                    ),
                    icon: Icons.admin_panel_settings_outlined,
                    selected:
                        _selectedAccountType == _RegisterAccountType.admin,
                    onTap: () {
                      setState(
                        () => _selectedAccountType = _RegisterAccountType.admin,
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _register() async {
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).clearSnackBars();
    if (_selectedAccountType == _RegisterAccountType.admin &&
        !_governmentOnly) {
      Navigator.pushReplacementNamed(
        context,
        '/login',
        arguments: const {'destination': 'admin'},
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    TextInput.finishAutofillContext();

    final authProvider = context.read<AuthProvider>();
    final generatedAdminAccessKey = _governmentOnly
        ? _generateAdminAccessKey()
        : null;
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
      role: _governmentOnly
          ? 'admin'
          : _selectedAccountType == _RegisterAccountType.student
          ? 'student'
          : 'teacher',
      adminAccessKey: generatedAdminAccessKey,
      persistSession: false,
    );

    if (!mounted) return;

    if (success) {
      final destination = switch (_selectedAccountType) {
        _RegisterAccountType.admin => 'admin',
        _RegisterAccountType.student => 'student',
        _RegisterAccountType.teacher => 'teacher',
      };
      final loginEmail = _emailController.text.trim();
      final loginPassword = _passwordController.text;

      if (_governmentOnly) {
        final accountName = _nameController.text.trim().isNotEmpty
            ? _nameController.text.trim()
            : loginEmail.split('@').first;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => GovernmentAccountSuccessScreen(
              accountName: accountName,
              email: loginEmail,
              password: loginPassword,
              adminAccessKey: generatedAdminAccessKey,
            ),
          ),
        );
        return;
      }

      Navigator.pushReplacementNamed(
        context,
        '/login',
        arguments: {
          'destination': destination,
          'email': loginEmail,
          'password': loginPassword,
          'message':
              'Account created. Sign in with the same email and password.',
        },
      );
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
          padding: ResponsiveLayout.pagePadding(
            context,
            compact: 16,
            mobile: 24,
            tablet: 24,
            desktop: 24,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  AppBar(
                    title: Text(
                      _governmentOnly
                          ? t('Create Government Account')
                          : t('Create Account'),
                    ),
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: _openGovernmentEntry,
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
    final showRegistrationFields =
        _governmentOnly || _selectedAccountType != _RegisterAccountType.admin;
    final createAccountLabel = _governmentOnly
        ? t('Create Government Account')
        : _selectedAccountType == _RegisterAccountType.admin
        ? t('Go to Admin Sign In')
        : t('Create Account');
    final headerTitle = _governmentOnly
        ? t('Create Government Account')
        : t('Create Account');
    final headerSubtitle = _governmentOnly
        ? t('Set up your government account')
        : t('Set up your account');
    final useDesktopLayout = ResponsiveLayout.isDesktop(context);

    return AutofillGroup(
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
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
                    onPressed: _openGovernmentEntry,
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        headerTitle,
                        style: TextStyle(
                          fontSize: useDesktopLayout ? 30 : 26,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        headerSubtitle,
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
            const SizedBox(height: 20),
            _buildSelectedAccountNotice()
                .animate()
                .fadeIn(delay: 150.ms)
                .slideY(begin: 0.04, end: 0),
            if (!_governmentOnly) ...[
              const SizedBox(height: 20),
              _buildAccountTypeSelector()
                  .animate()
                  .fadeIn(delay: 180.ms)
                  .slideY(begin: 0.04, end: 0),
            ],
            const SizedBox(height: 32),

            // Name + Email row (desktop) or stacked (mobile)
            if (showRegistrationFields && useDesktopLayout) ...[
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      label: fullNameLabel,
                      hint: fullNameHint,
                      controller: _nameController,
                      prefixIcon: Icons.person_outline,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.name],
                      textCapitalization: TextCapitalization.words,
                      validator: (value) {
                        final name = value?.trim() ?? '';
                        if (name.isEmpty) {
                          return t('Name is required');
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
                      autofillHints: const [
                        AutofillHints.username,
                        AutofillHints.email,
                      ],
                      autocorrect: false,
                      enableSuggestions: false,
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        if (email.isEmpty) {
                          return language.tr('emailRequired');
                        }
                        if (!isValidEmailAddress(email)) {
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
                      autofillHints: const [AutofillHints.telephoneNumber],
                      autocorrect: false,
                      enableSuggestions: false,
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
                      textCapitalization: TextCapitalization.words,
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
                      autofillHints: const [AutofillHints.newPassword],
                      autocorrect: false,
                      enableSuggestions: false,
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
                      autofillHints: const [AutofillHints.newPassword],
                      autocorrect: false,
                      enableSuggestions: false,
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
            ] else if (showRegistrationFields) ...[
              // Mobile stacked layout
              CustomTextField(
                label: fullNameLabel,
                hint: fullNameHint,
                controller: _nameController,
                prefixIcon: Icons.person_outline,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  final name = value?.trim() ?? '';
                  if (name.isEmpty) {
                    return t('Name is required');
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
                autofillHints: const [
                  AutofillHints.username,
                  AutofillHints.email,
                ],
                autocorrect: false,
                enableSuggestions: false,
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (email.isEmpty) {
                    return language.tr('emailRequired');
                  }
                  if (!isValidEmailAddress(email)) {
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
                autofillHints: const [AutofillHints.telephoneNumber],
                autocorrect: false,
                enableSuggestions: false,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                label: departmentOptionalLabel,
                hint: departmentHint,
                controller: _departmentController,
                prefixIcon: Icons.business_outlined,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                label: language.tr('password'),
                hint: createPasswordHint,
                controller: _passwordController,
                obscureText: true,
                prefixIcon: Icons.lock_outline,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                autocorrect: false,
                enableSuggestions: false,
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
                autofillHints: const [AutofillHints.newPassword],
                autocorrect: false,
                enableSuggestions: false,
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
            if (showRegistrationFields)
              const SizedBox(height: 28)
            else
              const SizedBox(height: 12),

            // Register Button
            Consumer<AuthProvider>(
              builder: (context, auth, child) {
                return CustomButton(
                  text: createAccountLabel,
                  isLoading: !showRegistrationFields ? false : auth.isLoading,
                  onPressed: _register,
                  icon: !showRegistrationFields
                      ? Icons.admin_panel_settings_outlined
                      : Icons.person_add_rounded,
                  useGradient: true,
                );
              },
            ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.05, end: 0),
            if (!_governmentOnly) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => Navigator.pushReplacementNamed(
                  context,
                  '/login',
                  arguments: const {'destination': 'admin'},
                ),
                icon: const Icon(Icons.admin_panel_settings_outlined),
                label: Text(context.t('Admin Sign In')),
              ).animate().fadeIn(delay: 550.ms),
            ],
            const SizedBox(height: 24),

            // Login Link
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _governmentOnly
                      ? '${t('Already have a government account?')} '
                      : '${t('Already have an account?')} ',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: _openLogin,
                    child: Text(
                      _governmentOnly
                          ? t('Login with Government Email')
                          : language.tr('signIn'),
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
      ),
    );
  }
}

// ─── Registration Branding Panel ────────────────────────────
class _RegisterAccountTypeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _RegisterAccountTypeCard({
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
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppTheme.animFast,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected ? AppTheme.bgCard : AppTheme.bgElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppTheme.primaryColor : AppTheme.glassBorder,
              width: selected ? 1.4 : 0.8,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.14),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: AppTheme.animFast,
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: selected
                      ? AppTheme.primaryGradient
                      : AppTheme.surfaceGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? AppTheme.textPrimary
                      : AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RegisterBrandingPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.t;

    return LayoutBuilder(
      builder: (context, constraints) {
        final topOrb = (constraints.maxWidth * 0.34).clamp(150, 200).toDouble();
        final bottomOrb = (constraints.maxWidth * 0.42)
            .clamp(170, 250)
            .toDouble();
        final sidePadding = constraints.maxWidth < 420 ? 24.0 : 48.0;

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
                  width: topOrb,
                  height: topOrb,
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
                  width: bottomOrb,
                  height: bottomOrb,
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
                padding: EdgeInsets.all(sidePadding),
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
      },
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
