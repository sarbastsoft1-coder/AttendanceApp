import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../models/settings_model.dart';


/// Authentication Provider - Handles login, register, and token management
class AuthProvider with ChangeNotifier {
  final ApiService _api = ApiService();
  final StorageService _storage = StorageService();

  User? _user;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;

  // Getters
  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  bool get isAuthenticated => _user != null;
  bool get hasRegisteredFace => _user?.hasRegisteredFace ?? false;
  bool get isAdmin => _user?.isAdmin ?? false;
  String? get error => _error;

  /// Initialize - Check for existing token and load user
  Future<void> init() async {
    await _storage.init();

    final token = await _storage.getToken();
    if (token != null) {
      _api.setAuthToken(token);

      // Try to verify token and get user
      try {
        await verifyToken();
      } catch (e) {
        // Token invalid, clear it
        await logout();
      }
    }

    _isInitialized = true;
    notifyListeners();
  }

  /// Register new user
  Future<bool> register({
    required String email,
    required String fullName,
    required String password,
    String? phone,
    String? department,
  }) async {
    _setLoading(true);
    _error = null;

    try {
      final response = await _api.post(
        ApiConfig.authRegister,
        data: {
          'email': email,
          'full_name': fullName,
          'password': password,
          'phone': phone,
          'department': department,
          'role': 'student',
        },
      );

      final data = response.data;
      _user = User.fromJson(data['user']);
      final token = data['token']['access_token'];

      await _storage.saveToken(token);
      await _storage.saveUser(_user!);
      _api.setAuthToken(token);

      _setLoading(false);
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  /// Login with email and password
  Future<bool> login({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    _setLoading(true);
    _error = null;

    try {
      final response = await _api.post(
        ApiConfig.authLogin,
        data: {
          'email': email,
          'password': password,
        },
      );

      final data = response.data;
      _user = User.fromJson(data['user']);
      final token = data['token']['access_token'];

      await _storage.saveToken(token);
      await _storage.saveUser(_user!);
      _api.setAuthToken(token);

      if (rememberMe) {
        await _storage.saveRememberMe(true);
        await _storage.saveLastEmail(email);
      }

      _setLoading(false);
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  /// Verify current token
  Future<bool> verifyToken() async {
    try {
      final response = await _api.get(ApiConfig.authVerify);
      _user = User.fromJson(response.data);
      await _storage.saveUser(_user!);
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Register face with multiple images
  Future<bool> registerFace(List<File> images) async {
    if (images.length < 3) {
      _error = 'Please capture at least 3 images';
      notifyListeners();
      return false;
    }

    _setLoading(true);
    _error = null;

    try {
      final multipartFiles = <MultipartFile>[];
      for (var image in images) {
        final file = await MultipartFile.fromFile(
          image.path,
          filename: 'face_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        multipartFiles.add(file);
      }

      await _api.uploadFile(
        ApiConfig.registerFace,
        files: multipartFiles,
        fieldName: 'images',
      );

      // Refresh user data
      await verifyToken();

      _setLoading(false);
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  /// Remove face registration
  Future<bool> removeFace() async {
    _setLoading(true);
    _error = null;

    try {
      await _api.delete(ApiConfig.removeFace);
      await verifyToken();
      _setLoading(false);
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  /// Update user profile
  Future<bool> updateProfile({
    String? fullName,
    String? phone,
    String? department,
  }) async {
    if (_user == null) return false;

    _setLoading(true);
    _error = null;

    try {
      final Map<String, dynamic> body = {};
      if (fullName != null) body['full_name'] = fullName;
      if (phone != null) body['phone'] = phone;
      if (department != null) body['department'] = department;

      final response = await _api.put(
        '${ApiConfig.users}/${_user!.id}',
        data: body,
      );

      _user = User.fromJson(response.data);
      await _storage.saveUser(_user!);

      _setLoading(false);
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  /// Request password reset — returns the reset token (local/desktop mode)
  Future<String?> forgotPassword(String email) async {
    _setLoading(true);
    _error = null;

    try {
      final response = await _api.post(
        ApiConfig.forgotPassword,
        data: {'email': email},
      );
      _setLoading(false);
      // Backend returns reset_token in local mode
      return response.data['reset_token'] as String?;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _setLoading(false);
      return null;
    }
  }

  /// Reset password using a token from forgotPassword
  Future<bool> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    _setLoading(true);
    _error = null;

    try {
      await _api.post(
        ApiConfig.resetPassword,
        data: {
          'token': token,
          'new_password': newPassword,
        },
      );
      _setLoading(false);
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  /// Change password for the currently logged-in user
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _setLoading(true);
    _error = null;

    try {
      await _api.post(
        ApiConfig.changePassword,
        data: {
          'current_password': currentPassword,
          'new_password': newPassword,
        },
      );
      _setLoading(false);
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  /// Verify email address with a token
  Future<bool> verifyEmail(String token) async {
    _setLoading(true);
    _error = null;

    try {
      await _api.post(ApiConfig.verifyEmail(token), data: {});
      // Refresh user data so is_verified is updated
      await verifyToken();
      _setLoading(false);
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  /// Fetch and cache the app settings (called after login)
  AppSettings? _cachedSettings;
  AppSettings? get cachedSettings => _cachedSettings;

  Future<void> fetchAppSettings() async {
    try {
      final response = await _api.get(ApiConfig.appSettings);
      _cachedSettings = AppSettings.fromJson(response.data);
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('Could not fetch app settings: $e');
    }
  }

  /// Logout
  Future<void> logout() async {
    _user = null;
    _api.clearAuthToken();
    await _storage.clearAll();
    notifyListeners();
  }

  /// Get last saved email (for remember me)
  String? getLastEmail() {
    return _storage.getLastEmail();
  }

  /// Check if remember me is enabled
  bool isRememberMeEnabled() {
    return _storage.getRememberMe();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
