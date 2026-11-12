import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'result_screen.dart';
import 'camera_scan_screen.dart';
import '../services/api_service.dart';
import '../widgets/gg_button.dart';
import '../widgets/gg_card.dart';
import '../widgets/gg_loader.dart';

class UploadScreen extends StatefulWidget {
  final String type; // 'Field' or 'Leaf'
  const UploadScreen({super.key, required this.type});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  XFile? _imageFile;
  Uint8List? _imageBytes;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  Future<void> _pickImage(ImageSource source) async {
    final XFile? selectedImage = await _picker.pickImage(source: source);
    if (selectedImage != null) {
      final bytes = await selectedImage.readAsBytes();
      setState(() {
        _imageFile = selectedImage;
        _imageBytes = bytes;
      });
    }
  }

  Future<void> _analyzeImage() async {
    if (_imageFile == null || _imageBytes == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await ApiService.analyzeField(_imageFile!);
      
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ResultScreen(
              result: result, 
              imageBytes: _imageBytes!,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Analyze ${widget.type}',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _isLoading 
        ? const GGLoader(message: "AI is processing your image...")
        : Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                // Immersive Preview Area
                Expanded(
                  child: Hero(
                    tag: 'image_preview',
                    child: GGCard(
                      padding: EdgeInsets.zero,
                      child: _imageBytes == null
                          ? _buildEmptyState()
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.memory(_imageBytes!, fit: BoxFit.cover),
                                  _buildRemoveButton(),
                                ],
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                
                // Interaction Buttons
                if (_imageBytes == null) _buildSourceButtons(),
                
                const SizedBox(height: 16),
                
                // Primary Action Button
                GGButton(
                  label: 'Start Analysis',
                  onPressed: _imageBytes == null ? null : _analyzeImage,
                  icon: Icons.auto_awesome,
                  isLoading: _isLoading,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
    );
  }

  Widget _buildEmptyState() {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_a_photo_outlined, size: 64, color: colorScheme.primary.withValues(alpha: 0.3)),
        const SizedBox(height: 16),
        Text(
          'Upload or Capture a Photo',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Our AI will detect weeds or diseases automatically.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildSourceButtons() {
    return Row(
      children: [
        Expanded(
          child: GGButton(
            label: 'Camera (Burst)',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CameraScanScreen())),
            icon: Icons.camera_alt_outlined,
            isSecondary: true,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: GGButton(
            label: 'Gallery',
            onPressed: () => _pickImage(ImageSource.gallery),
            icon: Icons.photo_library_outlined,
            isSecondary: true,
          ),
        ),
      ],
    );
  }

  Widget _buildRemoveButton() {
    return Positioned(
      top: 16,
      right: 16,
      child: IconButton.filled(
        onPressed: () => setState(() {
          _imageFile = null;
          _imageBytes = null;
        }),
        icon: const Icon(Icons.close),
        style: IconButton.styleFrom(
          backgroundColor: Colors.black.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}
