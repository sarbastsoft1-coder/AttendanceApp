import 'dart:io';

import 'package:flutter/foundation.dart';

class PlatformUtils {
  static bool get isWeb => kIsWeb;

  static bool get isNativeDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  static bool get isNativeMobile =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static bool get requiresSecureWebCameraContext =>
      kIsWeb &&
      Uri.base.scheme != 'https' &&
      Uri.base.host != 'localhost' &&
      Uri.base.host != '127.0.0.1';

  static String get webCameraContextMessage =>
      'Browser camera access requires HTTPS or localhost. Enable HTTPS for this site in Coolify or use localhost for testing.';
}
