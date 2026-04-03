import 'dart:io';

import 'package:flutter/foundation.dart';

class PlatformUtils {
  static bool get isWeb => kIsWeb;

  static bool get isNativeDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  static bool get isNativeMobile =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);
}
