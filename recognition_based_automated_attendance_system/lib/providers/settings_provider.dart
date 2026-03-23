import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../models/settings_model.dart';
import '../services/api_service.dart';

/// Settings Provider — manages system-wide app settings
class SettingsProvider with ChangeNotifier {
  final ApiService _api = ApiService();

  AppSettings _settings = const AppSettings();
  bool _isLoading = false;
  String? _error;
  bool _initialized = false;

  AppSettings get settings => _settings;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get initialized => _initialized;

  /// Fetch parsed app settings (available to all authenticated users)
  Future<void> fetchSettings() async {
    _setLoading(true);
    _error = null;

    try {
      final response = await _api.get(ApiConfig.appSettings);
      _settings = AppSettings.fromJson(response.data);
      _initialized = true;
      _setLoading(false);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _setLoading(false);
    }
  }

  /// Save all settings at once via bulk update (admin only)
  Future<bool> saveSettings(AppSettings updated) async {
    _setLoading(true);
    _error = null;

    try {
      await _api.post(
        ApiConfig.settingsBulk,
        data: {'settings': updated.toBulkUpdateMap()},
      );

      _settings = updated;
      _initialized = true;
      _setLoading(false);
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  /// Update a single setting by key (admin only)
  Future<bool> updateSetting(String key, String value) async {
    _setLoading(true);
    _error = null;

    try {
      await _api.put(
        ApiConfig.settingByKey(key),
        data: {'value': value},
      );

      // Re-fetch to get the updated AppSettings object
      await fetchSettings();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  /// Update late threshold time (convenience method)
  Future<bool> updateLateThreshold(int hour, int minute) async {
    _setLoading(true);
    _error = null;

    try {
      await _api.post(
        ApiConfig.settingsBulk,
        data: {
          'settings': {
            'late_threshold_hour': hour.toString(),
            'late_threshold_minute': minute.toString(),
          }
        },
      );

      _settings = _settings.copyWith(
        lateThresholdHour: hour,
        lateThresholdMinute: minute,
      );
      _setLoading(false);
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  /// Update attendance alert percentage threshold
  Future<bool> updateAlertThreshold(double percentage) async {
    return updateSetting('attendance_alert_pct', percentage.toString());
  }

  /// Toggle an attendance method on/off
  Future<bool> toggleAttendanceMethod(String method, bool enabled) async {
    String key;
    switch (method) {
      case 'face':
        key = 'allow_face_attendance';
        break;
      case 'qr':
        key = 'allow_qr_attendance';
        break;
      case 'manual':
        key = 'allow_manual_entry';
        break;
      default:
        return false;
    }
    return updateSetting(key, enabled.toString());
  }

  /// Update QR session duration
  Future<bool> updateQrSessionDuration(int minutes) async {
    return updateSetting('qr_session_minutes', minutes.toString());
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
