import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/offline_inference_service.dart';
import 'result_screen.dart';
import '../widgets/gg_button.dart';
import '../widgets/gg_loader.dart';

class CameraScanScreen extends StatefulWidget {
  const CameraScanScreen({super.key});

  @override
  State<CameraScanScreen> createState() => _CameraScanScreenState();
}

class _CameraScanScreenState extends State<CameraScanScreen> {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitializing = true;
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        _controller = CameraController(
          _cameras[0],
          ResolutionPreset.medium,
          enableAudio: false,
        );
        await _controller!.initialize();
      }
    } catch (e) {
      debugPrint("Camera error: $e");
    } finally {
      if (mounted) {
        setState(() => _isInitializing = false);
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _captureMultiFrame() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    setState(() => _isCapturing = true);

    try {
      List<Uint8List> frames = [];
      for (int i = 0; i < 3; i++) {
        final XFile file = await _controller!.takePicture();
        frames.add(await file.readAsBytes());
        // Small delay between frames for variation
        await Future.delayed(const Duration(milliseconds: 200));
      }

      final result = await OfflineInferenceService.analyzeMultipleFrames(frames);

      if (mounted) {
        Navigator.pop(context); // Optional if replacing, but we push Replacement instead
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ResultScreen(
              result: result,
              imageBytes: frames.last,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isCapturing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) return const Scaffold(body: GGLoader(message: "Initializing camera..."));
    if (_controller == null || !_controller!.value.isInitialized) {
      return Scaffold(
        appBar: AppBar(title: const Text('CameraScan')),
        body: const Center(child: Text('No camera found or initialization failed.')),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'Multi-Frame Scan',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: _isCapturing
          ? const GGLoader(message: "Analyzing leaf...")
          : Stack(
              children: [
                Positioned.fill(
                  child: CameraPreview(_controller!),
                ),
                Positioned(
                  bottom: 40,
                  left: 20,
                  right: 20,
                  child: GGButton(
                    label: 'Capture 3-Frame Burst',
                    onPressed: _captureMultiFrame,
                    icon: Icons.camera_rounded,
                  ),
                ),
              ],
            ),
    );
  }
}
