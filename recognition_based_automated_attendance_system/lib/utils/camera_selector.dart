import 'package:camera/camera.dart';

import 'platform_utils.dart';

/// Picks cameras in a consistent way across mobile and desktop.
class CameraSelector {
  static CameraDescription forSelfie(List<CameraDescription> cameras) {
    _ensureCameras(cameras);

    final front = _firstByLens(cameras, CameraLensDirection.front);
    if (front != null) return front;

    final namedSelfie = _firstByNameKeyword(cameras, const [
      'front',
      'selfie',
      'integrated',
      'webcam',
      'facetime',
      'hd camera',
    ]);
    if (namedSelfie != null) return namedSelfie;

    final external = _firstByLens(cameras, CameraLensDirection.external);
    if (external != null) return external;

    return cameras.first;
  }

  static CameraDescription forRoomScan(List<CameraDescription> cameras) {
    _ensureCameras(cameras);

    // On laptops, back camera often does not exist.
    if (PlatformUtils.isNativeDesktop) {
      return forSelfie(cameras);
    }

    final back = _firstByLens(cameras, CameraLensDirection.back);
    if (back != null) return back;

    return forSelfie(cameras);
  }

  static CameraDescription? _firstByLens(
    List<CameraDescription> cameras,
    CameraLensDirection lensDirection,
  ) {
    for (final camera in cameras) {
      if (camera.lensDirection == lensDirection) {
        return camera;
      }
    }
    return null;
  }

  static CameraDescription? _firstByNameKeyword(
    List<CameraDescription> cameras,
    List<String> keywords,
  ) {
    for (final camera in cameras) {
      final lowerName = camera.name.toLowerCase();
      for (final keyword in keywords) {
        if (lowerName.contains(keyword)) {
          return camera;
        }
      }
    }
    return null;
  }

  static void _ensureCameras(List<CameraDescription> cameras) {
    if (cameras.isEmpty) {
      throw StateError('No cameras available');
    }
  }
}
