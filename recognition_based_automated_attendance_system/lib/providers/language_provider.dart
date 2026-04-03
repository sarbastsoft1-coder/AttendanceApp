import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../localization/app_strings.dart';

class LanguageOption {
  final String code;
  final String label;

  const LanguageOption(this.code, this.label);
}

class LanguageProvider with ChangeNotifier {
  static const String _languageKey = 'app_language';

  String _languageCode = AppStrings.englishCode;

  String get languageCode => _languageCode;
  bool get isSorani => _languageCode == AppStrings.soraniCode;
  TextDirection get textDirection =>
      isSorani ? TextDirection.rtl : TextDirection.ltr;

  Locale get materialLocale =>
      isSorani ? const Locale('ar') : const Locale('en');

  List<LanguageOption> get languageOptions => [
    LanguageOption(AppStrings.englishCode, tr('languageEnglish')),
    LanguageOption(AppStrings.soraniCode, tr('languageSorani')),
  ];

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_languageKey);
    if (saved == AppStrings.englishCode || saved == AppStrings.soraniCode) {
      _languageCode = saved!;
    }
  }

  Future<void> setLanguageCode(String code) async {
    if (code != AppStrings.englishCode && code != AppStrings.soraniCode) {
      return;
    }
    if (_languageCode == code) return;
    _languageCode = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, code);
    notifyListeners();
  }

  String tr(String key, {Map<String, String> params = const {}}) {
    var value =
        AppStrings.translations[_languageCode]?[key] ??
        AppStrings.translations[AppStrings.englishCode]?[key] ??
        key;

    params.forEach((name, replacement) {
      value = value.replaceAll('{$name}', replacement);
    });

    return value;
  }

  String text(String english, {Map<String, String> params = const {}}) {
    var value = isSorani
        ? (AppStrings.soraniPhrases[english] ?? english)
        : english;

    params.forEach((name, replacement) {
      value = value.replaceAll('{$name}', replacement);
    });

    return value;
  }
}
