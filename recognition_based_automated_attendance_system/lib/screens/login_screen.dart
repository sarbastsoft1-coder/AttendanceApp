import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../localization/localization_extensions.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../providers/supervision_provider.dart';
import '../utils/input_validators.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_textfield.dart';
import '../widgets/language_selector.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/window_title_bar.dart';

enum _LoginDestination { main, admin }

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
  final _adminAccessKeyController = TextEditingController();
  bool _rememberMe = false;
  bool _didLoadRouteArguments = false;
  String? _redirectRoute;
  Object? _redirectArguments;
  _LoginDestination _selectedDestination = _LoginDestination.main;

  @override
  void initState() {
    super.initState();
    _loadSavedEmail();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoadRouteArguments) {
      return;
    }

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final route = args['route'];
      if (route is String && route.trim().isNotEmpty) {
        _redirectRoute = route.trim();
        _redirectArguments = args['arguments'];
      }

      final destination = args['destination'];
      if (destination == 'admin') {
        _selectedDestination = _LoginDestination.admin;
      }
    }

    _didLoadRouteArguments = true;
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
    _adminAccessKeyController.dispose();
    super.dispose();
  }

  String _defaultPostLoginRoute(AuthProvider authProvider) {
    return authProvider.hasRegisteredFace ? '/home' : '/face-capture';
  }

  String _resolvePostLoginRoute(AuthProvider authProvider) {
    if (_selectedDestination == _LoginDestination.admin &&
        authProvider.user?.isAdmin == true) {
      return '/admin';
    }
    return _defaultPostLoginRoute(authProvider);
  }

  String _formatRole(String? role) {
    final normalized = (role ?? '').trim();
    if (normalized.isEmpty) {
      return 'Unknown';
    }

    return normalized
        .split('_')
        .map(
          (segment) => segment.isEmpty
              ? segment
              : '${segment[0].toUpperCase()}${segment.substring(1)}',
        )
        .join(' ');
  }

  Future<void> _showAdminAccessDialog(AuthProvider authProvider) async {
    final roleLabel = _formatRole(authProvider.user?.role);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.t('Admin access required')),
        content: Text(
          context.t(
            'This account is signed in as {role}. Only admin or super admin accounts can open the admin dashboard.',
            params: {'role': roleLabel},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.t('Open Main Dashboard')),
          ),
        ],
      ),
    );
  }

  Future<bool> _shouldOpenPendingInvitations() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.user;
    if (user?.isTeacher != true) {
      return false;
    }

    final supervision = context.read<SupervisionProvider>();
    try {
      await supervision.fetchOverview();
    } catch (_) {
      return false;
    }

    if (!mounted) {
      return false;
    }

    return supervision.overview?.pendingInvitations.isNotEmpty == true;
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    TextInput.finishAutofillContext();

    final authProvider = context.read<AuthProvider>();
    final language = context.read<LanguageProvider>();
    final success = await authProvider.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      rememberMe: _rememberMe,
      adminAccessKey: _selectedDestination == _LoginDestination.admin
          ? _adminAccessKeyController.text.trim()
          : null,
    );

    if (!mounted) return;

    if (success) {
      if (_redirectRoute != null) {
        Navigator.pushReplacementNamed(
          context,
          _redirectRoute!,
          arguments: _redirectArguments,
        );
      } else {
        final shouldOpenInvitations = await _shouldOpenPendingInvitations();
        if (!mounted) return;
        if (shouldOpenInvitations) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(language.tr('pendingInvitationReviewPrompt')),
              backgroundColor: AppTheme.infoColor,
            ),
          );
          Navigator.pushReplacementNamed(context, '/supervision');
          return;
        }

        if (_selectedDestination == _LoginDestination.admin &&
            authProvider.user?.isAdmin != true) {
          await _showAdminAccessDialog(authProvider);
          if (!mounted) return;
          Navigator.pushReplacementNamed(
            context,
            _defaultPostLoginRoute(authProvider),
          );
          return;
        }

        Navigator.pushReplacementNamed(
          context,
          _resolvePostLoginRoute(authProvider),
        );
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

  Widget _buildDashboardSelector(LanguageProvider language) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          language.tr('dashboardDestination'),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          language.tr('chooseDashboardDestination'),
          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _DashboardDestinationCard(
                title: language.tr('mainDashboard'),
                subtitle: language.tr('mainDashboardDescription'),
                icon: Icons.dashboard_customize_outlined,
                selected: _selectedDestination == _LoginDestination.main,
                onTap: () {
                  setState(() {
                    _selectedDestination = _LoginDestination.main;
                    _adminAccessKeyController.clear();
                  });
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DashboardDestinationCard(
                title: language.tr('adminDashboard'),
                subtitle: language.tr('adminDashboardDescription'),
                icon: Icons.admin_panel_settings_outlined,
                selected: _selectedDestination == _LoginDestination.admin,
                onTap: () {
                  setState(
                    () => _selectedDestination = _LoginDestination.admin,
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAdminKeyNotice() {
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
              Icons.key_rounded,
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
                  context.t('Admin sign-in requires an access key'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.t(
                    'Existing admin accounts must enter the admin access key before the admin dashboard will open.',
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
          padding: ResponsiveLayout.pagePadding(
            context,
            compact: 16,
            mobile: 24,
            tablet: 24,
            desktop: 24,
          ),
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
    final isAdminDestination = _selectedDestination == _LoginDestination.admin;

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
              isAdminDestination
                  ? context.t(
                      'Sign in to the admin dashboard with your access key',
                    )
                  : language.tr('signInTeacherDashboard'),
              style: const TextStyle(
                fontSize: 15,
                color: AppTheme.textSecondary,
              ),
            ).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 24),
            _buildDashboardSelector(
              language,
            ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.05, end: 0),
            if (isAdminDestination) ...[
              const SizedBox(height: 18),
              _buildAdminKeyNotice()
                  .animate()
                  .fadeIn(delay: 280.ms)
                  .slideY(begin: 0.04, end: 0),
            ],
            const SizedBox(height: 28),
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
            ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.05, end: 0),
            const SizedBox(height: 16),
            CustomTextField(
              label: language.tr('password'),
              hint: language.tr('enterPassword'),
              controller: _passwordController,
              obscureText: true,
              prefixIcon: Icons.lock_outline,
              autofillHints: const [AutofillHints.password],
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: isAdminDestination
                  ? TextInputAction.next
                  : TextInputAction.done,
              onSubmitted: (_) {
                if (!isAdminDestination) {
                  _login();
                }
              },
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
            if (isAdminDestination) ...[
              const SizedBox(height: 16),
              CustomTextField(
                label: context.t('Admin Access Key'),
                hint: context.t('Enter the admin access key'),
                controller: _adminAccessKeyController,
                obscureText: true,
                prefixIcon: Icons.key_outlined,
                textInputAction: TextInputAction.done,
                autofillHints: const <String>[],
                autocorrect: false,
                enableSuggestions: false,
                onSubmitted: (_) => _login(),
                validator: (value) {
                  if (!isAdminDestination) {
                    return null;
                  }
                  if (value == null || value.trim().isEmpty) {
                    return context.t('Admin access key is required');
                  }
                  return null;
                },
              ).animate().fadeIn(delay: 450.ms).slideY(begin: 0.05, end: 0),
            ],
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
                    style: TextStyle(
                      color: AppTheme.primaryLight,
                      fontSize: 13,
                    ),
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
      ),
    );
  }
}

class _DashboardDestinationCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _DashboardDestinationCard({
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
                      color: AppTheme.primaryColor.withValues(alpha: 0.16),
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

class _BrandingPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final language = context.language;

    return LayoutBuilder(
      builder: (context, constraints) {
        final orbLarge = (constraints.maxWidth * 0.38)
            .clamp(160, 220)
            .toDouble();
        final orbSmall = (constraints.maxWidth * 0.32)
            .clamp(140, 180)
            .toDouble();
        final sidePadding = constraints.maxWidth < 420 ? 24.0 : 48.0;
        final titleSize = constraints.maxWidth < 420 ? 30.0 : 36.0;

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
                  width: orbLarge,
                  height: orbLarge,
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
                  width: orbSmall,
                  height: orbSmall,
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
                padding: EdgeInsets.all(sidePadding),
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
                    Text(
                      'FaceAttend',
                      style: TextStyle(
                        fontSize: titleSize,
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
      },
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
