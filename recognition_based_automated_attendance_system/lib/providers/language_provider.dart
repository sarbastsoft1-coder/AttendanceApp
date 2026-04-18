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
  static final Map<String, String> _englishValueToKey = {
    for (final entry
        in (AppStrings.translations[AppStrings.englishCode] ?? {}).entries)
      entry.value: entry.key,
  };

  String _languageCode = AppStrings.englishCode;

  String get languageCode => _languageCode;
  bool get isSorani => _languageCode == AppStrings.soraniCode;
  bool get isArabic => _languageCode == AppStrings.arabicCode;
  bool get isRtl => isSorani || isArabic;
  TextDirection get textDirection =>
      isRtl ? TextDirection.rtl : TextDirection.ltr;

  Locale get materialLocale => isRtl ? const Locale('ar') : const Locale('en');

  List<LanguageOption> get languageOptions => [
    LanguageOption(AppStrings.englishCode, tr('languageEnglish')),
    LanguageOption(AppStrings.soraniCode, tr('languageSorani')),
    LanguageOption(AppStrings.arabicCode, tr('languageArabic')),
  ];

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_languageKey);
    if (saved == AppStrings.englishCode ||
        saved == AppStrings.soraniCode ||
        saved == AppStrings.arabicCode) {
      _languageCode = saved!;
    }
  }

  Future<void> setLanguageCode(String code) async {
    if (code != AppStrings.englishCode &&
        code != AppStrings.soraniCode &&
        code != AppStrings.arabicCode) {
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

  String? _lookupTranslatedEnglishValue(String english) {
    final key = _englishValueToKey[english];
    if (key == null) {
      return null;
    }
    return AppStrings.translations[_languageCode]?[key];
  }

  String text(String english, {Map<String, String> params = const {}}) {
    var value = switch (_languageCode) {
      AppStrings.soraniCode =>
        AppStrings.soraniPhrases[english] ??
            _lookupTranslatedEnglishValue(english) ??
            english,
      AppStrings.arabicCode =>
        AppStrings.arabicPhrases[english] ??
            _lookupTranslatedEnglishValue(english) ??
            english,
      _ => english,
    };

    params.forEach((name, replacement) {
      value = value.replaceAll('{$name}', replacement);
    });

    return value;
  }
}
