import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/api_config.dart';
import '../../config/app_theme.dart';
import '../../models/settings_model.dart';
import '../../providers/settings_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';

/// Admin Settings Screen — configure all system settings + backend URL
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Late threshold
  late int _lateHour;
  late int _lateMinute;

  // Numeric sliders / text fields
  late TextEditingController _alertPctController;
  late TextEditingController _qrMinutesController;
  late TextEditingController _minFaceController;
  late TextEditingController _maxFaceController;
  late TextEditingController _appNameController;

  // Toggle switches
  late bool _allowFace;
  late bool _allowQr;
  late bool _allowManual;

  // Backend URL
  late TextEditingController _urlController;

  bool _hasUnsavedChanges = false;
  bool _isSaving = false;
  bool _isTestingUrl = false;
  String? _urlTestResult;

  @override
  void initState() {
    super.initState();
    _alertPctController = TextEditingController();
    _qrMinutesController = TextEditingController();
    _minFaceController = TextEditingController();
    _maxFaceController = TextEditingController();
    _appNameController = TextEditingController();
    _urlController = TextEditingController(text: ApiConfig.baseUrl);
    _lateHour = 9;
    _lateMinute = 0;
    _allowFace = true;
    _allowQr = true;
    _allowManual = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<SettingsProvider>().fetchSettings();
      _populateFields();
    });
  }

  void _populateFields() {
    final s = context.read<SettingsProvider>().settings;
    setState(() {
      _lateHour = s.lateThresholdHour;
      _lateMinute = s.lateThresholdMinute;
      _alertPctController.text = s.attendanceAlertPct.toStringAsFixed(0);
      _qrMinutesController.text = s.qrSessionMinutes.toString();
      _minFaceController.text = s.minFaceImages.toString();
      _maxFaceController.text = s.maxFaceImages.toString();
      _appNameController.text = s.appName;
      _allowFace = s.allowFaceAttendance;
      _allowQr = s.allowQrAttendance;
      _allowManual = s.allowManualEntry;
      _hasUnsavedChanges = false;
    });
  }

  @override
  void dispose() {
    _alertPctController.dispose();
    _qrMinutesController.dispose();
    _minFaceController.dispose();
    _maxFaceController.dispose();
    _appNameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  void _markChanged() {
    if (!_hasUnsavedChanges) {
      setState(() => _hasUnsavedChanges = true);
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);

    final updated = AppSettings(
      lateThresholdHour: _lateHour,
      lateThresholdMinute: _lateMinute,
      attendanceAlertPct:
          double.tryParse(_alertPctController.text) ?? 75.0,
      qrSessionMinutes:
          int.tryParse(_qrMinutesController.text) ?? 15,
      minFaceImages: int.tryParse(_minFaceController.text) ?? 3,
      maxFaceImages: int.tryParse(_maxFaceController.text) ?? 10,
      appName: _appNameController.text.trim().isEmpty
          ? 'Face Attendance System'
          : _appNameController.text.trim(),
      allowFaceAttendance: _allowFace,
      allowQrAttendance: _allowQr,
      allowManualEntry: _allowManual,
    );

    final provider = context.read<SettingsProvider>();
    final success = await provider.saveSettings(updated);

    if (!mounted) return;
    setState(() {
      _isSaving = false;
      if (success) _hasUnsavedChanges = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success
            ? 'Settings saved successfully'
            : (provider.error ?? 'Failed to save settings')),
        backgroundColor:
            success ? AppTheme.successColor : AppTheme.errorColor,
      ),
    );
  }

  Future<void> _saveBackendUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    await ApiConfig.setBaseUrl(url);
    ApiService().setBaseUrl(url);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Backend URL updated. Restart the app to apply fully.'),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }

  Future<void> _testUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _isTestingUrl = true;
      _urlTestResult = null;
    });

    try {
      // Try a GET /health to the new URL
      final dio = ApiService().createTestDio(url);
      final response = await dio.get('/health').timeout(
        const Duration(seconds: 5),
      );
      setState(() {
        _isTestingUrl = false;
        _urlTestResult = response.statusCode == 200
            ? 'Connected! Server is healthy.'
            : 'Server responded with status ${response.statusCode}';
      });
    } catch (e) {
      setState(() {
        _isTestingUrl = false;
        _urlTestResult = 'Failed to connect: ${e.toString().split(':').first}';
      });
    }
  }

  Future<void> _pickLateTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _lateHour, minute: _lateMinute),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primaryColor,
              surface: AppTheme.bgCard,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _lateHour = picked.hour;
        _lateMinute = picked.minute;
      });
      _markChanged();
    }
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Settings'),
        actions: [
          if (_hasUnsavedChanges)
            _isSaving
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  )
                : TextButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save_rounded,
                        size: 18, color: AppTheme.primaryColor),
                    label: const Text(
                      'Save',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Reload from server',
            onPressed: () async {
              await context.read<SettingsProvider>().fetchSettings();
              _populateFields();
            },
          ),
        ],
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && !provider.initialized) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Unsaved changes banner
                if (_hasUnsavedChanges)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color:
                          AppTheme.warningColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.warningColor.withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: AppTheme.warningColor, size: 18),
                        SizedBox(width: 10),
                        Text(
                          'You have unsaved changes',
                          style: TextStyle(
                            color: AppTheme.warningColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── Theme ──────────────────────────────────
                _SectionHeader(
                  icon: Icons.palette_outlined,
                  title: 'Appearance',
                ),
                const SizedBox(height: 12),
                _SettingsCard(
                  child: _ThemeToggleRow(),
                ),
                const SizedBox(height: 24),

                // ── Backend URL ────────────────────────────
                _SectionHeader(
                  icon: Icons.cloud_outlined,
                  title: 'Backend Connection',
                ),
                const SizedBox(height: 12),
                _SettingsCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'API Base URL',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _urlController,
                              decoration: const InputDecoration(
                                hintText: 'http://localhost:8000',
                                prefixIcon: Icon(Icons.link_rounded),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                              ),
                              onChanged: (_) => setState(
                                  () => _urlTestResult = null),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _isTestingUrl ? null : _testUrl,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.secondaryColor,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 14),
                            ),
                            child: _isTestingUrl
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white),
                                  )
                                : const Text('Test',
                                    style: TextStyle(color: Colors.white)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _saveBackendUrl,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 14),
                            ),
                            child: const Text('Apply'),
                          ),
                        ],
                      ),
                      if (_urlTestResult != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              _urlTestResult!.startsWith('Connected')
                                  ? Icons.check_circle_rounded
                                  : Icons.error_outline_rounded,
                              size: 14,
                              color: _urlTestResult!.startsWith('Connected')
                                  ? AppTheme.successColor
                                  : AppTheme.errorColor,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _urlTestResult!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      _urlTestResult!.startsWith('Connected')
                                          ? AppTheme.successColor
                                          : AppTheme.errorColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () async {
                          _urlController.text = ApiConfig.defaultBaseUrl;
                          await ApiConfig.resetBaseUrl();
                          ApiService().setBaseUrl(ApiConfig.defaultBaseUrl);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('URL reset to default')),
                            );
                          }
                        },
                        child: const Text(
                          'Reset to default (localhost:8000)',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.primaryLight,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Attendance Time ────────────────────────
                _SectionHeader(
                  icon: Icons.access_time_rounded,
                  title: 'Attendance Time',
                ),
                const SizedBox(height: 12),
                _SettingsCard(
                  child: Column(
                    children: [
                      _SettingRow(
                        icon: Icons.watch_later_outlined,
                        title: 'Late Check-In Threshold',
                        subtitle: 'Students arriving after this time are marked late',
                        trailing: GestureDetector(
                          onTap: _pickLateTime,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppTheme.primaryColor
                                    .withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.edit_rounded,
                                    size: 14,
                                    color: AppTheme.primaryLight),
                                const SizedBox(width: 6),
                                Text(
                                  _formatTime(_lateHour, _lateMinute),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryLight,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const Divider(color: AppTheme.glassBorder, height: 24),
                      _TextInputRow(
                        icon: Icons.warning_amber_rounded,
                        title: 'Attendance Alert Threshold',
                        subtitle: 'Notify when attendance falls below this %',
                        controller: _alertPctController,
                        suffix: '%',
                        keyboardType: TextInputType.number,
                        onChanged: (_) => _markChanged(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Attendance Methods ─────────────────────
                _SectionHeader(
                  icon: Icons.how_to_reg_rounded,
                  title: 'Attendance Methods',
                ),
                const SizedBox(height: 12),
                _SettingsCard(
                  child: Column(
                    children: [
                      _SwitchRow(
                        icon: Icons.face_retouching_natural,
                        title: 'Face Recognition',
                        subtitle: 'Allow attendance via facial recognition',
                        value: _allowFace,
                        onChanged: (v) {
                          setState(() => _allowFace = v);
                          _markChanged();
                        },
                      ),
                      const Divider(color: AppTheme.glassBorder, height: 24),
                      _SwitchRow(
                        icon: Icons.qr_code_scanner_rounded,
                        title: 'QR Code Attendance',
                        subtitle: 'Allow attendance via QR code scanning',
                        value: _allowQr,
                        onChanged: (v) {
                          setState(() => _allowQr = v);
                          _markChanged();
                        },
                      ),
                      const Divider(color: AppTheme.glassBorder, height: 24),
                      _SwitchRow(
                        icon: Icons.edit_note_rounded,
                        title: 'Manual Entry',
                        subtitle: 'Allow teachers to manually mark attendance',
                        value: _allowManual,
                        onChanged: (v) {
                          setState(() => _allowManual = v);
                          _markChanged();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Face Recognition ───────────────────────
                _SectionHeader(
                  icon: Icons.face_outlined,
                  title: 'Face Registration',
                ),
                const SizedBox(height: 12),
                _SettingsCard(
                  child: Column(
                    children: [
                      _TextInputRow(
                        icon: Icons.photo_library_outlined,
                        title: 'Minimum Face Images',
                        subtitle:
                            'Minimum photos required for face registration',
                        controller: _minFaceController,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => _markChanged(),
                      ),
                      const Divider(color: AppTheme.glassBorder, height: 24),
                      _TextInputRow(
                        icon: Icons.photo_library_rounded,
                        title: 'Maximum Face Images',
                        subtitle: 'Maximum photos allowed for registration',
                        controller: _maxFaceController,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => _markChanged(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── QR Session ────────────────────────────
                _SectionHeader(
                  icon: Icons.qr_code_2_rounded,
                  title: 'QR Session',
                ),
                const SizedBox(height: 12),
                _SettingsCard(
                  child: _TextInputRow(
                    icon: Icons.timer_outlined,
                    title: 'Session Duration',
                    subtitle: 'How many minutes a QR session stays active',
                    controller: _qrMinutesController,
                    suffix: 'min',
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _markChanged(),
                  ),
                ),
                const SizedBox(height: 24),

                // ── App ────────────────────────────────────
                _SectionHeader(
                  icon: Icons.apps_rounded,
                  title: 'Application',
                ),
                const SizedBox(height: 12),
                _SettingsCard(
                  child: _TextInputRow(
                    icon: Icons.label_outline_rounded,
                    title: 'App Name',
                    subtitle: 'Display name shown in the application',
                    controller: _appNameController,
                    onChanged: (_) => _markChanged(),
                  ),
                ),
                const SizedBox(height: 32),

                // ── Save Button ────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save_rounded),
                    label: Text(_isSaving ? 'Saving...' : 'Save All Settings'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_hasUnsavedChanges)
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: _populateFields,
                      child: const Text(
                        'Discard Changes',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                  ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatTime(int hour, int minute) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour =
        hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final minuteStr = minute.toString().padLeft(2, '0');
    return '$displayHour:$minuteStr $period';
  }
}

// ─── Theme Toggle Row (embedded) ─────────────────────────────

class _ThemeToggleRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return _SwitchRow(
          icon: themeProvider.isDark
              ? Icons.dark_mode_rounded
              : Icons.light_mode_rounded,
          title: themeProvider.isDark ? 'Dark Mode' : 'Light Mode',
          subtitle: 'Toggle between dark and light theme',
          value: themeProvider.isDark,
          onChanged: (v) => themeProvider.toggle(),
          activeColor: themeProvider.isDark
              ? AppTheme.primaryColor
              : AppTheme.accentColor,
        );
      },
    );
  }
}

// ─── Reusable Widgets ────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final Widget child;

  const _SettingsCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration(),
      child: child,
    );
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;

  const _SettingRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppTheme.primaryColor),
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
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        trailing,
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color? activeColor;

  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: (value
                    ? (activeColor ?? AppTheme.successColor)
                    : AppTheme.textMuted)
                .withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 18,
            color: value
                ? (activeColor ?? AppTheme.successColor)
                : AppTheme.textMuted,
          ),
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
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: activeColor ?? AppTheme.successColor,
        ),
      ],
    );
  }
}

class _TextInputRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final TextEditingController controller;
  final String? suffix;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  const _TextInputRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.controller,
    this.suffix,
    this.keyboardType,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppTheme.primaryColor),
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
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: suffix != null ? 80 : 100,
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            textAlign: TextAlign.center,
            onChanged: onChanged,
            decoration: InputDecoration(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              suffixText: suffix,
              suffixStyle: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
