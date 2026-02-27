import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:plant_detection/features/scanner/result_screen.dart';
import 'package:plant_detection/core/services/tflite_service.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  final DetectionMode mode;
  const ScannerScreen({super.key, required this.mode});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _cameraController = CameraController(
          _cameras![0],
          ResolutionPreset.high,
          enableAudio: false,
        );
        await _cameraController!.initialize();
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _processImage(String imagePath) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Colors.greenAccent),
      ),
    );

    try {
      final tflite = ref.read(tfliteServiceProvider);
      await tflite.loadModel();

      Map<String, dynamic>? result;
      if (widget.mode == DetectionMode.plant) {
        result = await tflite.identifyPlant(imagePath);
      } else {
        result = await tflite.detectDisease(imagePath);
      }

      if (mounted) {
        Navigator.pop(context); // close loader
        if (result != null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ResultScreen(imagePath: imagePath, inferenceResult: result!),
            ),
          );
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Inference failed.')));
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint('Error processing image: $e');
    }
  }

  Future<void> _takePicture() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized)
      return;
    if (_cameraController!.value.isTakingPicture) return;
    try {
      final XFile image = await _cameraController!.takePicture();
      await _processImage(image.path);
    } catch (e) {
      debugPrint('Error taking picture: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        await _processImage(image.path);
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPlantMode = widget.mode == DetectionMode.plant;
    final title = isPlantMode ? 'scan_plant'.tr() : 'detect_disease'.tr();
    final accentColor = isPlantMode ? Colors.greenAccent : Colors.orangeAccent;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: _isCameraInitialized
          ? Stack(
              children: [
                Positioned.fill(child: CameraPreview(_cameraController!)),
                Center(
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(color: accentColor, width: 3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                // Mode indicator
                Positioned(
                  top: 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isPlantMode
                            ? '🌿 Plant ID Mode'
                            : '🔬 Disease Detection Mode',
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 30,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      FloatingActionButton(
                        heroTag: 'gallery',
                        onPressed: _pickFromGallery,
                        backgroundColor: Colors.white70,
                        child: const Icon(
                          Icons.photo_library,
                          color: Colors.black,
                          size: 28,
                        ),
                      ),
                      FloatingActionButton.large(
                        heroTag: 'camera',
                        onPressed: _takePicture,
                        backgroundColor: Colors.white,
                        child: const Icon(
                          Icons.camera,
                          color: Colors.black,
                          size: 36,
                        ),
                      ),
                      const SizedBox(width: 56),
                    ],
                  ),
                ),
              ],
            )
          : const Center(
              child: CircularProgressIndicator(color: Colors.greenAccent),
            ),
    );
  }
}
