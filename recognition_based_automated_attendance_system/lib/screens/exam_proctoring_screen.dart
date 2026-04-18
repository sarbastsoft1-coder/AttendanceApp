import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../config/api_config.dart';
import '../config/app_theme.dart';
import '../localization/localization_extensions.dart';
import '../models/captured_image.dart';
import '../providers/student_management_provider.dart';
import '../services/api_service.dart';
import '../utils/camera_selector.dart';
import '../utils/platform_utils.dart';
import '../widgets/custom_button.dart';

class ExamProctoringScreen extends StatefulWidget {
  const ExamProctoringScreen({super.key});

  @override
  State<ExamProctoringScreen> createState() => _ExamProctoringScreenState();
}

class _ExamProctoringScreenState extends State<ExamProctoringScreen> {
  final ApiService _api = ApiService();
  CameraController? _cameraController;
  bool _isCameraReady = false;
  String? _cameraError;
  bool _isScanning = false;
  int? _selectedClassId;
  int _previewQuarterTurns = 0;
  Timer? _scanTimer;
  bool _isProctoring = false;

  Map<String, dynamic>? _lastResult;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadClasses();
    });
  }

  void _loadClasses() {
    final studentProvider = context.read<StudentManagementProvider>();
    if (studentProvider.classes.isEmpty) {
      studentProvider.fetchClasses();
    }
  }

  Future<void> _initCamera() async {
    final t = context.t;

    try {
      if (PlatformUtils.requiresSecureWebCameraContext) {
        throw Exception(PlatformUtils.webCameraContextMessage);
      }
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _cameraError = t('No cameras found');
        });
        return;
      }

      final frontCamera = CameraSelector.forSelfie(cameras);

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();

      if (PlatformUtils.isNativeDesktop && frontCamera.sensorOrientation == 0) {
        _previewQuarterTurns = 2;
      }

      if (mounted) {
        setState(() {
          _isCameraReady = true;
          _cameraError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cameraError = e.toString().replaceFirst('Exception: ', '');
          _isCameraReady = false;
        });
      }
    }
  }

  Future<void> _captureAndScan() async {
    if (_cameraController == null || !_isCameraReady || _isScanning) return;

    setState(() {
      _isScanning = true;
    });

    try {
      final XFile image = await _cameraController!.takePicture();
      final imageBytes = await image.readAsBytes();

      final multipartFile = MultipartFile.fromBytes(
        imageBytes,
        filename: 'exam_scan.jpg',
      );

      final response = await _api.uploadExamProctorImage(
        ApiConfig.examProctor,
        file: multipartFile,
        classId: _selectedClassId,
      );

      setState(() {
        _lastResult = response.data;
        _isScanning = false;
      });
    } catch (e) {
      setState(() {
        _isScanning = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scan failed: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _startProctoring() {
    setState(() {
      _isProctoring = true;
    });
    _initCamera();
    _scanTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_selectedClassId != null) {
        _captureAndScan();
      }
    });
  }

  void _stopProctoring() {
    _scanTimer?.cancel();
    _cameraController?.dispose();
    setState(() {
      _isProctoring = false;
      _isCameraReady = false;
    });
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  Widget _buildCameraPreview() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return Center(child: Text(_cameraError ?? 'Camera not available'));
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

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(t('examProctoring')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_isProctoring) {
              _stopProctoring();
            }
            Navigator.pop(context);
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('examProctoring'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t('examProctoringDescription'),
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Consumer<StudentManagementProvider>(
                    builder: (context, provider, child) {
                      final classes = provider.classes;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t('Select Class'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<int>(
                            initialValue: _selectedClassId,
                            decoration: InputDecoration(
                              hintText: t('Select Class'),
                              prefixIcon: const Icon(Icons.class_rounded),
                            ),
                            items: classes.map((c) {
                              return DropdownMenuItem(
                                value: c.id,
                                child: Text(c.name),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedClassId = value;
                              });
                            },
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  if (!_isProctoring)
                    CustomButton(
                      text: t('startProctoring'),
                      onPressed: _selectedClassId != null
                          ? _startProctoring
                          : null,
                      icon: Icons.play_arrow,
                    )
                  else
                    CustomButton(
                      text: t('stopProctoring'),
                      onPressed: _stopProctoring,
                      icon: Icons.stop,
                      backgroundColor: AppTheme.errorColor,
                    ),
                ],
              ),
            ),
            if (_isProctoring) ...[
              const SizedBox(height: 24),
              Container(
                height: 300,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.primaryColor, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: _isCameraReady
                      ? Stack(
                          children: [
                            _buildCameraPreview(),
                            if (_isScanning)
                              Container(
                                color: Colors.black54,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        )
                      : Center(
                          child: _cameraError != null
                              ? Text(_cameraError!)
                              : const CircularProgressIndicator(),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              CustomButton(
                text: _isScanning ? 'Scanning...' : 'Scan Now',
                isLoading: _isScanning,
                onPressed: _captureAndScan,
                icon: Icons.camera_alt,
              ),
            ],
            if (_lastResult != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: AppTheme.cardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Scan Results',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildResultRow(
                      t('studentVerified'),
                      _lastResult!['student_verified'] == true
                          ? t('yes')
                          : t('no'),
                      _lastResult!['student_verified'] == true
                          ? AppTheme.successColor
                          : AppTheme.errorColor,
                    ),
                    _buildResultRow(
                      t('faceCount'),
                      '${_lastResult!['face_count']}',
                      AppTheme.infoColor,
                    ),
                    _buildResultRow(
                      t('gazeDirection'),
                      _lastResult!['gaze_direction'] ?? 'N/A',
                      AppTheme.infoColor,
                    ),
                    _buildResultRow(
                      t('suspicionScore'),
                      '${((_lastResult!['suspicion_score'] ?? 0) * 100).toStringAsFixed(1)}%',
                      (_lastResult!['suspicion_score'] ?? 0) > 0.5
                          ? AppTheme.errorColor
                          : AppTheme.successColor,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      t('violations'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if ((_lastResult!['violations'] as List?)?.isEmpty ?? true)
                      Text(
                        t('noViolations'),
                        style: TextStyle(color: AppTheme.textSecondary),
                      )
                    else
                      ...((_lastResult!['violations'] as List).map((v) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.errorColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.warning,
                                color: AppTheme.errorColor,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                v.toString(),
                                style: const TextStyle(
                                  color: AppTheme.errorColor,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        );
                      })),
                    if (_lastResult!['is_cheating'] == true) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.errorColor),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.warning,
                              color: AppTheme.errorColor,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              t('cheatingDetected'),
                              style: const TextStyle(
                                color: AppTheme.errorColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
