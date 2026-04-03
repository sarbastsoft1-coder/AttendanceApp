import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../providers/language_provider.dart';

extension LocalizationBuildContext on BuildContext {
  LanguageProvider get language => watch<LanguageProvider>();
  LanguageProvider get languageRead => read<LanguageProvider>();
  String tr(String key, {Map<String, String> params = const {}}) =>
      language.tr(key, params: params);
  String t(String english, {Map<String, String> params = const {}}) =>
      language.text(english, params: params);
  String trRead(String key, {Map<String, String> params = const {}}) =>
      languageRead.tr(key, params: params);
  String tRead(String english, {Map<String, String> params = const {}}) =>
      languageRead.text(english, params: params);
}
