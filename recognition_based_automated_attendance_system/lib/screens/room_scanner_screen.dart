import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_theme.dart';
import '../config/api_config.dart';
import '../providers/attendance_provider.dart';
import '../models/attendance_model.dart';
import '../services/api_service.dart';
import '../utils/camera_selector.dart';
import '../widgets/custom_button.dart';
import '../widgets/loading_widget.dart';

class RoomScannerScreen extends StatefulWidget {
  const RoomScannerScreen({super.key});

  @override
  State<RoomScannerScreen> createState() => _RoomScannerScreenState();
}

class _RoomScannerClassOption {
  final int id;
  final String name;
  final int studentCount;

  const _RoomScannerClassOption({
    required this.id,
    required this.name,
    required this.studentCount,
  });

  factory _RoomScannerClassOption.fromJson(Map<String, dynamic> json) {
    return _RoomScannerClassOption(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Unnamed Class',
      studentCount: json['student_count'] ?? 0,
    );
  }
}

class _RoomScannerScreenState extends State<RoomScannerScreen> {
  final ApiService _api = ApiService();

  CameraController? _controller;
  bool _isLoadingClasses = true;
  String? _classLoadError;
  List<_RoomScannerClassOption> _classes = [];
  _RoomScannerClassOption? _selectedClass;
  bool _isInitializing = true;
  bool _isProcessing = false;
  RoomScanResult? _result;
  int _previewQuarterTurns = 0;
  String? _rotationPreferenceKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadClasses();
    });
  }

  Future<void> _loadClasses() async {
    if (mounted) {
      setState(() {
        _isLoadingClasses = true;
        _classLoadError = null;
      });
    }

    try {
      final response = await _api.get(ApiConfig.classes);
      final data = response.data as List<dynamic>;
      final parsedClasses = data
          .map(
            (item) =>
                _RoomScannerClassOption.fromJson(item as Map<String, dynamic>),
          )
          .toList();

      if (!mounted) return;
      setState(() {
        _classes = parsedClasses;
        _isLoadingClasses = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _classLoadError = e.toString().replaceFirst('Exception: ', '');
        _isLoadingClasses = false;
      });
    }
  }

  Future<void> _selectClass(_RoomScannerClassOption classOption) async {
    if (!mounted) return;
    setState(() {
      _selectedClass = classOption;
      _isInitializing = true;
      _result = null;
    });
    await _initializeCamera();
  }


  Future<void> _initializeCamera() async {
    // Fully dispose old controller first, set to null immediately
    final oldController = _controller;
    _controller = null;
    try {
      await oldController?.dispose();
    } catch (_) {}

    if (!mounted) return;

    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      if (mounted) setState(() => _isInitializing = false);
      return;
    }

    final backCamera = CameraSelector.forRoomScan(cameras);
    _rotationPreferenceKey = _buildRotationPreferenceKey(backCamera);

    // On Windows, the camera device can take time to release.
    // Retry up to 3 times with increasing delays.
    const delays = [500, 1000, 2000];
    bool initialized = false;

    for (final delayMs in delays) {
      await Future.delayed(Duration(milliseconds: delayMs));
      if (!mounted) return;

      try {
        await _controller?.dispose();
      } catch (_) {}
      _controller = null;

      _controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      try {
        await _controller!.initialize();
        initialized = true;
        break; // Success — stop retrying
      } catch (e) {
        // Camera still busy, will retry
        try { await _controller?.dispose(); } catch (_) {}
        _controller = null;
        if (delayMs == delays.last) {
          // All retries exhausted
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'Camera is busy. Close any other app using the camera and try again.',
                ),
                duration: const Duration(seconds: 5),
              ),
            );
          }
        }
      }
    }

    if (initialized && _rotationPreferenceKey != null && mounted) {
      _previewQuarterTurns = await _loadSavedRotation(
        camera: backCamera,
        preferenceKey: _rotationPreferenceKey!,
      );
    }

    if (mounted) setState(() => _isInitializing = false);
  }


  Future<void> _captureAndScan() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isProcessing) {
      return;
    }
    if (!mounted) return;

    final attendanceProvider = context.read<AttendanceProvider>();

    setState(() {
      _isProcessing = true;
    });

    try {
      final XFile image = await _controller!.takePicture();
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'room_scan_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedPath = path.join(directory.path, fileName);
      await image.saveTo(savedPath);
      final savedFile = File(savedPath);

      if (await savedFile.exists()) {
        final result = await attendanceProvider.performRoomScan(
          savedFile,
          classId: _selectedClass?.id,
        );

        if (!mounted) return;

        setState(() {
          _result = result;
          _isProcessing = false;
        });
      } else {
        throw Exception('Failed to save room scan photo');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error during scan: $e')));
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingClasses) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_selectedClass == null) {
      return _buildClassSelectionScreen();
    }

    if (_isInitializing) {
      return Scaffold(
        appBar: AppBar(title: const Text('Room Scanner')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Room Scanner - ${_selectedClass!.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.class_rounded),
            tooltip: 'Change Class',
            onPressed: () async {
              final oldController = _controller;
              _controller = null;
              if (!mounted) return;
              setState(() {
                _selectedClass = null;
                _result = null;
                _isInitializing = true;
              });
              try { await oldController?.dispose(); } catch (_) {}
            },
          ),
          if (_result == null)
            IconButton(
              icon: const Icon(Icons.rotate_right),
              tooltip: 'Rotate Camera',
              onPressed: () {
                setState(() {
                  _previewQuarterTurns = (_previewQuarterTurns + 1) % 4;
                });
                _saveRotation(_previewQuarterTurns);
              },
            ),
          if (_result != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                setState(() {
                  _result = null;
                });
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          if (_result == null)
            _buildScannerInterface()
          else
            _buildResultsInterface(),

          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: LoadingWidget(message: 'Analyzing Hall...'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildClassSelectionScreen() {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Class')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose a class before starting Room Scanner',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            if (_classLoadError != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
                ),
                child: Text(
                  _classLoadError!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _loadClasses,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ),
            ] else if (_classes.isEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.25),
                  ),
                ),
                child: const Text(
                  'No classes found. Create a class first in Batch Register.',
                  style: TextStyle(color: Colors.orange),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () =>
                    Navigator.pushNamed(context, '/batch-registration'),
                icon: const Icon(Icons.group_add),
                label: const Text('Open Batch Register'),
              ),
            ] else ...[
              Expanded(
                child: ListView.separated(
                  itemCount: _classes.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final classOption = _classes[index];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.class_rounded),
                        title: Text(classOption.name),
                        subtitle: Text('${classOption.studentCount} students'),
                        trailing: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 16,
                        ),
                        onTap: () => _selectClass(classOption),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScannerInterface() {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(child: Text('Camera not available'));
    }

    final mediaQuery = MediaQuery.of(context);
    final isNarrowLayout = mediaQuery.size.width < 980;

    return Column(
      children: [
        Expanded(child: _buildCameraPreview()),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Scan Room',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Class: ${_selectedClass?.name ?? '-'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Take one photo to detect all faces in the selected class.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 20),
                if (isNarrowLayout) ...[
                  CustomButton(
                    text: 'START ROOM SCAN',
                    onPressed: _captureAndScan,
                    icon: Icons.qr_code_scanner,
                  ),
                  const SizedBox(height: 12),
                  CustomButton(
                    text: 'EXPORT ABSENT',
                    onPressed: _exportAbsent,
                    isOutlined: true,
                    icon: Icons.download,
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: CustomButton(
                          text: 'START ROOM SCAN',
                          onPressed: _captureAndScan,
                          icon: Icons.qr_code_scanner,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CustomButton(
                          text: 'EXPORT ABSENT',
                          onPressed: _exportAbsent,
                          isOutlined: true,
                          icon: Icons.download,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCameraPreview() {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(child: Text('Camera not available'));
    }

    final previewSize = _controller!.value.previewSize;
    if (previewSize == null) {
      return CameraPreview(_controller!);
    }

    final sensorTurns = (_controller!.description.sensorOrientation ~/ 90) % 4;
    final totalTurns = (sensorTurns + _previewQuarterTurns) % 4;

    Widget preview = SizedBox(
      width: previewSize.height,
      height: previewSize.width,
      child: CameraPreview(_controller!),
    );

    if (totalTurns != 0) {
      preview = RotatedBox(quarterTurns: totalTurns, child: preview);
    }

    return SizedBox.expand(
      child: FittedBox(fit: BoxFit.cover, child: preview),
    );
  }

  String _buildRotationPreferenceKey(CameraDescription camera) {
    final safeCameraName = camera.name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return 'room_scanner_rotation_$safeCameraName';
  }

  Future<int> _loadSavedRotation({
    required CameraDescription camera,
    required String preferenceKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(preferenceKey);
    if (saved != null) {
      return saved % 4;
    }

    // Desktop webcam drivers can report wrong orientation metadata.
    final isDesktop =
        Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    if (isDesktop && camera.sensorOrientation == 0) {
      return 2;
    }

    return 0;
  }

  Future<void> _saveRotation(int quarterTurns) async {
    final key = _rotationPreferenceKey;
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, quarterTurns % 4);
  }

  Widget _buildResultsInterface() {
    final result = _result!;

    // If no students recognized, show a dedicated "No Students Found" view
    if (result.presentCount == 0) {
      return _buildNoStudentsFoundView(result);
    }

    return Column(
      children: [
        _buildStatsHeader(result),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (result.absentUsers.isNotEmpty) ...[
                _buildSectionHeader('Missing Attendees', Colors.red),
                ...result.absentUsers.map((u) => _buildUserTile(u, false)),
              ],
              const SizedBox(height: 24),
              if (result.presentUsers.isNotEmpty) ...[
                _buildSectionHeader('Present Attendees', Colors.green),
                ...result.presentUsers.map((u) => _buildUserTile(u, true)),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: CustomButton(
            text: 'DONE',
            onPressed: () => Navigator.pop(context),
            isOutlined: true,
          ),
        ),
      ],
    );
  }

  Widget _buildNoStudentsFoundView(RoomScanResult result) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.face_retouching_off_rounded,
                size: 80,
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'No Students Recognized',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              result.message.isNotEmpty
                  ? result.message
                  : 'No faces in this photo match any students in the selected class.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.grey, height: 1.5),
            ),
            const SizedBox(height: 48),
            CustomButton(
              text: 'RETRY SCAN',
              onPressed: () {
                setState(() {
                  _result = null;
                });
              },
              icon: Icons.refresh_rounded,
            ),
            const SizedBox(height: 16),
            CustomButton(
              text: 'DONE',
              onPressed: () => Navigator.pop(context),
              isOutlined: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsHeader(RoomScanResult result) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Total', result.totalStudents.toString()),
          _buildStatItem(
            'Present',
            result.presentCount.toString(),
            color: Colors.greenAccent,
          ),
          _buildStatItem(
            'Missing',
            result.absentCount.toString(),
            color: Colors.orangeAccent,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value, {
    Color color = Colors.white,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          Text(
            title.contains('Missing')
                ? '${_result?.absentCount}'
                : '${_result?.presentCount}',
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(dynamic user, bool isPresent) {
    final rawEmail = (user.email ?? '').toString();
    final subtitleText = rawEmail.endsWith('@student.example.com')
        ? 'Student ID: ${user.id}'
        : rawEmail;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isPresent
              ? Colors.green.withValues(alpha: 0.1)
              : Colors.red.withValues(alpha: 0.1),
          child: Icon(
            isPresent ? Icons.check_circle : Icons.error_outline,
            color: isPresent ? Colors.green : Colors.red,
          ),
        ),
        title: Text(
          user.fullName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(subtitleText),
        trailing: Text(
          user.department ?? '',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ),
    );
  }

  Future<void> _exportAbsent() async {
    if (_result == null || _result!.absentUsers.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No absent attendees to export.')),
      );
      return;
    }

    String escapeCsv(String value) {
      final escaped = value.replaceAll('"', '""');
      if (escaped.contains(',') ||
          escaped.contains('\n') ||
          escaped.contains('"')) {
        return '"$escaped"';
      }
      return escaped;
    }

    try {
      final buffer = StringBuffer();
      buffer.writeln('Class,Name,Email,Department');
      final selectedClassName = _selectedClass?.name ?? '';

      for (final user in _result!.absentUsers) {
        final department = user.department ?? '';
        buffer.writeln(
          '${escapeCsv(selectedClassName)},${escapeCsv(user.fullName)},${escapeCsv(user.email)},${escapeCsv(department)}',
        );
      }

      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'absent_export_class_${_selectedClass?.id ?? 'na'}_${DateTime.now().millisecondsSinceEpoch}.csv';
      final exportFile = File(path.join(directory.path, fileName));
      await exportFile.writeAsString(buffer.toString());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Saved ${_result!.absentUsers.length} absent records to $fileName',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export absent list: $e')),
      );
    }
  }
}
