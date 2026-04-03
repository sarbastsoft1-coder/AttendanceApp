import 'dart:io';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../localization/localization_extensions.dart';
import '../providers/attendance_provider.dart';
import '../utils/camera_selector.dart';
import '../widgets/custom_button.dart';

/// Attendance Screen - Mark attendance using face recognition
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  CameraController? _cameraController;
  bool _isCameraReady = false;
  bool _isCapturing = false;
  File? _capturedImage;
  int _previewQuarterTurns = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initCamera();
    });
  }

  Future<void> _initCamera() async {
    final t = context.t;

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _showError(t('No cameras found'));
        return;
      }

      final frontCamera = CameraSelector.forSelfie(cameras);

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();

      final isDesktop =
          Platform.isWindows || Platform.isLinux || Platform.isMacOS;
      if (isDesktop && frontCamera.sensorOrientation == 0) {
        _previewQuarterTurns = 2;
      }

      if (mounted) {
        setState(() {
          _isCameraReady = true;
        });
      }
    } catch (e) {
      _showError(
        t('Failed to initialize camera: {error}', params: {'error': '$e'}),
      );
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppTheme.errorColor),
      );
    }
  }

  Future<void> _captureImage() async {
    if (_cameraController == null || !_isCameraReady || _isCapturing) return;

    setState(() {
      _isCapturing = true;
    });

    try {
      final XFile image = await _cameraController!.takePicture();

      // Save image to a persistent directory
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'attendance_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedPath = path.join(directory.path, fileName);

      await image.saveTo(savedPath);
      final savedFile = File(savedPath);

      if (await savedFile.exists()) {
        setState(() {
          _capturedImage = savedFile;
          _isCapturing = false;
        });
      } else {
        throw Exception('Failed to save attendance photo');
      }
    } catch (e) {
      setState(() {
        _isCapturing = false;
      });
      if (!mounted) return;
      _showError(context.t('Failed to capture image'));
    }
  }

  void _retake() {
    setState(() {
      _capturedImage = null;
    });
  }

  Future<void> _confirmAttendance() async {
    if (_capturedImage == null) return;

    final attendanceProvider = context.read<AttendanceProvider>();
    final success = await attendanceProvider.markAttendance(_capturedImage!);

    if (!mounted) return;

    if (success) {
      final attendance = attendanceProvider.lastMarkedAttendance;
      _showSuccessDialog(
        attendance?.displayName ?? context.t('User'),
        attendance?.confidence ?? 0,
        attendance?.status ?? 'present',
      );
    } else {
      _showError(
        attendanceProvider.error ?? context.t('Failed to mark attendance'),
      );
    }
  }

  void _showSuccessDialog(String name, double confidence, String status) {
    final t = context.t;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: status == 'present'
                    ? AppTheme.successColor.withValues(alpha: 0.1)
                    : AppTheme.warningColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                status == 'present' ? Icons.check_circle : Icons.access_time,
                size: 64,
                color: status == 'present'
                    ? AppTheme.successColor
                    : AppTheme.warningColor,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              t('Welcome, {name}!', params: {'name': name}),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              status == 'present'
                  ? t('Check-In Recorded')
                  : t('Recorded as Late'),
              style: TextStyle(
                fontSize: 16,
                color: status == 'present'
                    ? AppTheme.successColor
                    : AppTheme.warningColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                t(
                  'Confidence: {value}%',
                  params: {'value': (confidence * 100).toStringAsFixed(1)},
                ),
                style: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Go back to home
              },
              child: Text(t('Done')),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;

    return Scaffold(
      appBar: AppBar(
        title: Text(t('Take Attendance')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isCameraReady)
            IconButton(
              icon: const Icon(Icons.rotate_right),
              tooltip: t('Rotate Camera'),
              onPressed: () {
                setState(() {
                  _previewQuarterTurns = (_previewQuarterTurns + 1) % 4;
                });
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Instructions
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.infoColor.withValues(alpha: 0.1),
            child: Row(
              children: [
                const Icon(Icons.face, color: AppTheme.infoColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    t('Position your face within the circle and capture'),
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Camera Preview or Captured Image
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.primaryColor, width: 3),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(21),
                child: _capturedImage != null
                    ? Image.file(
                        _capturedImage!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                      )
                    : _isCameraReady && _cameraController != null
                    ? Stack(
                        alignment: Alignment.center,
                        children: [
                          _buildCameraPreview(),
                          // Circular overlay
                          Container(
                            width: 250,
                            height: 300,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.5),
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(150),
                            ),
                          ),
                        ],
                      )
                    : const Center(child: CircularProgressIndicator()),
              ),
            ),
          ),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: _capturedImage != null
                ? Row(
                    children: [
                      Expanded(
                        child: CustomButton(
                          text: 'Retake',
                          isOutlined: true,
                          onPressed: _retake,
                          icon: Icons.refresh,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Consumer<AttendanceProvider>(
                          builder: (context, attendance, child) {
                            return CustomButton(
                              text: 'Confirm',
                              isLoading: attendance.isLoading,
                              onPressed: _confirmAttendance,
                              icon: Icons.check,
                              backgroundColor: AppTheme.successColor,
                            );
                          },
                        ),
                      ),
                    ],
                  )
                : CustomButton(
                    text: _isCapturing ? 'Capturing...' : 'Capture',
                    isLoading: _isCapturing,
                    onPressed: _captureImage,
                    icon: Icons.camera_alt,
                  ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    final previewSize = _cameraController!.value.previewSize;
    if (previewSize == null) {
      return CameraPreview(_cameraController!);
    }

    final sensorTurns =
        (_cameraController!.description.sensorOrientation ~/ 90) % 4;
    final totalTurns = (sensorTurns + _previewQuarterTurns) % 4;

    Widget preview = SizedBox(
      width: previewSize.height,
      height: previewSize.width,
      child: CameraPreview(_cameraController!),
    );

    if (totalTurns != 0) {
      preview = RotatedBox(quarterTurns: totalTurns, child: preview);
    }

    return SizedBox.expand(
      child: FittedBox(fit: BoxFit.cover, child: preview),
    );
  }
}
