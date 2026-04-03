import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

/// Storage Service for secure token storage and user data
class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  SharedPreferences? _prefs;

  StorageService._internal();

  // Keys
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';
  static const String _rememberMeKey = 'remember_me';
  static const String _lastEmailKey = 'last_email';

  /// Initialize shared preferences
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ========================
  // SECURE STORAGE (Token)
  // ========================

  /// Save authentication token
  Future<void> saveToken(String token) async {
    await _secureStorage.write(key: _tokenKey, value: token);
  }

  /// Get authentication token
  Future<String?> getToken() async {
    return await _secureStorage.read(key: _tokenKey);
  }

  /// Delete authentication token
  Future<void> deleteToken() async {
    await _secureStorage.delete(key: _tokenKey);
  }

  /// Check if token exists
  Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // ========================
  // SHARED PREFERENCES (User Data)
  // ========================

  /// Save user data
  Future<void> saveUser(User user) async {
    await _prefs?.setString(_userKey, jsonEncode(user.toJson()));
  }

  /// Get user data
  User? getUser() {
    final userJson = _prefs?.getString(_userKey);
    if (userJson != null) {
      return User.fromJson(jsonDecode(userJson));
    }
    return null;
  }

  /// Delete user data
  Future<void> deleteUser() async {
    await _prefs?.remove(_userKey);
  }

  /// Save remember me preference
  Future<void> saveRememberMe(bool value) async {
    await _prefs?.setBool(_rememberMeKey, value);
  }

  /// Get remember me preference
  bool getRememberMe() {
    return _prefs?.getBool(_rememberMeKey) ?? false;
  }

  /// Save last used email
  Future<void> saveLastEmail(String email) async {
    await _prefs?.setString(_lastEmailKey, email);
  }

  /// Get last used email
  String? getLastEmail() {
    return _prefs?.getString(_lastEmailKey);
  }

  // ========================
  // CLEAR ALL
  // ========================

  /// Clear all stored data (for logout)
  Future<void> clearAll() async {
    await _secureStorage.deleteAll();
    await _prefs?.remove(_userKey);
    // Keep remember me and last email for convenience
  }

  /// Clear everything including preferences
  Future<void> clearEverything() async {
    await _secureStorage.deleteAll();
    await _prefs?.clear();
  }
}
