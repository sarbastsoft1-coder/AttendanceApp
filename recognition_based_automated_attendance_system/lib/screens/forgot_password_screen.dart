import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_textfield.dart';

/// Forgot Password Screen
/// Step 1: Enter email → get reset token
/// Step 2: Enter token + new password → reset
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  // Step tracking
  int _step = 1; // 1 = email, 2 = token + new password

  // Controllers
  final _emailController = TextEditingController();
  final _tokenController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Form keys
  final _emailFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();

  // State
  String? _resetToken; // Token returned by backend (local/desktop mode)
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;

  @override
  void dispose() {
    _emailController.dispose();
    _tokenController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────
  // Step 1: Request reset token
  // ──────────────────────────────────────────────────────────────

  Future<void> _requestToken() async {
    if (!_emailFormKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final token = await auth.forgotPassword(_emailController.text.trim());

    if (!mounted) return;

    if (auth.error != null) {
      _showSnack(auth.error!, isError: true);
      return;
    }

    // In local/desktop mode the backend returns the token directly.
    // In production this would be sent via email.
    setState(() {
      _step = 2;
      _resetToken = token;
      if (token != null) {
        _tokenController.text = token;
      }
    });

    if (token != null) {
      _showSnack(
        'Reset token generated. It has been pre-filled below.',
        isError: false,
      );
    } else {
      _showSnack(
        'If that email exists, a reset token has been sent.',
        isError: false,
      );
    }
  }

  // ──────────────────────────────────────────────────────────────
  // Step 2: Submit token + new password
  // ──────────────────────────────────────────────────────────────

  Future<void> _resetPassword() async {
    if (!_resetFormKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final success = await auth.resetPassword(
      token: _tokenController.text.trim(),
      newPassword: _newPasswordController.text,
    );

    if (!mounted) return;

    if (success) {
      _showSnack('Password reset successfully! Please log in.', isError: false);
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    } else {
      _showSnack(auth.error ?? 'Failed to reset password', isError: true);
    }
  }

  void _showSnack(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.errorColor : AppTheme.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // Build
  // ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Forgot Password'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_step == 2) {
              setState(() => _step = 1);
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress indicator
            _StepIndicator(currentStep: _step),
            const SizedBox(height: 32),

            // Step content
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.05, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: _step == 1
                  ? _EmailStep(
                      key: const ValueKey('step1'),
                      formKey: _emailFormKey,
                      emailController: _emailController,
                      onSubmit: _requestToken,
                    )
                  : _ResetStep(
                      key: const ValueKey('step2'),
                      formKey: _resetFormKey,
                      tokenController: _tokenController,
                      newPasswordController: _newPasswordController,
                      confirmPasswordController: _confirmPasswordController,
                      showNewPassword: _showNewPassword,
                      showConfirmPassword: _showConfirmPassword,
                      onToggleNew: () =>
                          setState(() => _showNewPassword = !_showNewPassword),
                      onToggleConfirm: () => setState(
                          () => _showConfirmPassword = !_showConfirmPassword),
                      onSubmit: _resetPassword,
                      hasPrefilledToken: _resetToken != null,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Step Indicator Widget
// ──────────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final int currentStep;
  const _StepIndicator({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StepDot(number: 1, isActive: currentStep == 1, isDone: currentStep > 1),
        Expanded(
          child: Container(
            height: 2,
            color: currentStep > 1
                ? AppTheme.primaryColor
                : AppTheme.glassBorder,
          ),
        ),
        _StepDot(number: 2, isActive: currentStep == 2, isDone: false),
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  final int number;
  final bool isActive;
  final bool isDone;

  const _StepDot({
    required this.number,
    required this.isActive,
    required this.isDone,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Widget child;

    if (isDone) {
      bg = AppTheme.primaryColor;
      child = const Icon(Icons.check, size: 16, color: Colors.white);
    } else if (isActive) {
      bg = AppTheme.primaryColor;
      child = Text(
        '$number',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      );
    } else {
      bg = AppTheme.bgElevated;
      child = Text(
        '$number',
        style: const TextStyle(
          color: AppTheme.textMuted,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      );
    }

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(
          color: isActive || isDone ? AppTheme.primaryColor : AppTheme.glassBorder,
          width: 2,
        ),
      ),
      child: Center(child: child),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Step 1 — Email Input
// ──────────────────────────────────────────────────────────────

class _EmailStep extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final VoidCallback onSubmit;

  const _EmailStep({
    super.key,
    required this.formKey,
    required this.emailController,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Reset Your Password',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Enter the email address associated with your account. '
          'A password reset token will be generated.',
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),

        Form(
          key: formKey,
          child: Column(
            children: [
              CustomTextField(
                controller: emailController,
                label: 'Email Address',
                hint: 'Enter your registered email',
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter your email address';
                  }
                  if (!RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$').hasMatch(val.trim())) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              Consumer<AuthProvider>(
                builder: (context, auth, _) {
                  return CustomButton(
                    text: 'Get Reset Token',
                    isLoading: auth.isLoading,
                    onPressed: onSubmit,
                    icon: Icons.send_rounded,
                  );
                },
              ),
              const SizedBox(height: 16),

              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Back to Login',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // Info box
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.infoColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.infoColor.withValues(alpha: 0.3),
            ),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: AppTheme.infoColor, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'In this local deployment, the reset token is returned '
                  'directly and pre-filled for convenience. In production, '
                  'it would be sent to your email.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Step 2 — Token + New Password
// ──────────────────────────────────────────────────────────────

class _ResetStep extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController tokenController;
  final TextEditingController newPasswordController;
  final TextEditingController confirmPasswordController;
  final bool showNewPassword;
  final bool showConfirmPassword;
  final VoidCallback onToggleNew;
  final VoidCallback onToggleConfirm;
  final VoidCallback onSubmit;
  final bool hasPrefilledToken;

  const _ResetStep({
    super.key,
    required this.formKey,
    required this.tokenController,
    required this.newPasswordController,
    required this.confirmPasswordController,
    required this.showNewPassword,
    required this.showConfirmPassword,
    required this.onToggleNew,
    required this.onToggleConfirm,
    required this.onSubmit,
    required this.hasPrefilledToken,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Set New Password',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Enter your reset token and choose a new password.',
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),

        Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Reset Token field
              const Text(
                'Reset Token',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: tokenController,
                decoration: InputDecoration(
                  hintText: 'Paste your reset token here',
                  prefixIcon: const Icon(Icons.vpn_key_outlined),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    tooltip: 'Copy token',
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: tokenController.text),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Token copied'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter the reset token';
                  }
                  return null;
                },
              ),

              if (hasPrefilledToken) ...[
                const SizedBox(height: 8),
                const Row(
                  children: [
                    Icon(Icons.check_circle,
                        size: 14, color: AppTheme.successColor),
                    SizedBox(width: 6),
                    Text(
                      'Token pre-filled from backend response',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.successColor,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),

              // New Password
              const Text(
                'New Password',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: newPasswordController,
                obscureText: !showNewPassword,
                decoration: InputDecoration(
                  hintText: 'Enter new password (min 6 characters)',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      showNewPassword ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: onToggleNew,
                  ),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) {
                    return 'Please enter a new password';
                  }
                  if (val.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Confirm Password
              const Text(
                'Confirm New Password',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: confirmPasswordController,
                obscureText: !showConfirmPassword,
                decoration: InputDecoration(
                  hintText: 'Re-enter your new password',
                  prefixIcon: const Icon(Icons.check_circle_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      showConfirmPassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: onToggleConfirm,
                  ),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) {
                    return 'Please confirm your new password';
                  }
                  if (val != newPasswordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 40),

              Consumer<AuthProvider>(
                builder: (context, auth, _) {
                  return CustomButton(
                    text: 'Reset Password',
                    isLoading: auth.isLoading,
                    onPressed: onSubmit,
                    icon: Icons.lock_reset_rounded,
                    backgroundColor: AppTheme.successColor,
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
