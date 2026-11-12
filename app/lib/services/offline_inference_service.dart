import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import '../utils/image_preprocessor.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Normalization strategy — change this ONE value to switch between options:
//
//   NormalizationMode.optionA  →  pixel / 255.0           (values 0.0 – 1.0)
//   NormalizationMode.optionB  →  (pixel / 127.5) - 1.0   (values -1.0 – 1.0)
//   NormalizationMode.none     →  raw uint8 cast to double (values 0 – 255)
// ─────────────────────────────────────────────────────────────────────────────
enum NormalizationMode { optionA, optionB, none }

const NormalizationMode _activeNormalization = NormalizationMode.optionA;

// ─────────────────────────────────────────────────────────────────────────────

class OfflineInferenceService {
  static Interpreter? _diseaseInterpreter;
  static List<String>? _labels;

  /// Loads the model and labels into memory.
  static Future<void> initialize() async {
    try {
      if (_diseaseInterpreter == null) {
        const modelPath = 'assets/model/green_guard_fresh_finetuned.tflite';
        debugPrint('[OfflineInference] Loading model: $modelPath');
        _diseaseInterpreter = await Interpreter.fromAsset(modelPath);
        debugPrint('[OfflineInference] Model loaded successfully.');
      }

      if (_labels == null) {
        debugPrint('[OfflineInference] Loading labels: assets/model/labels.txt');
        final labelData =
            await rootBundle.loadString('assets/model/labels.txt');
        _labels = labelData
            .split('\n')
            .where((s) => s.trim().isNotEmpty)
            .map((s) {
              final trimmed = s.trim();
              final parts = trimmed.split(' ');
              return parts.length > 1 ? parts.sublist(1).join(' ') : trimmed;
            })
            .toList();
        debugPrint(
            '[OfflineInference] Loaded ${_labels!.length} labels.');
      }
    } catch (e) {
      debugPrint('[OfflineInference] FAILED to initialize: $e');
      rethrow; // Propagate the error so the UI can report it
    }
  }

  /// Runs classification on a local image file.
  static Future<Map<String, dynamic>> analyzeImage(File imageFile) async {
    final imageBytes = await imageFile.readAsBytes();
    return analyzeImageBytes(imageBytes);
  }

  /// Runs classification on raw image bytes.
  static Future<Map<String, dynamic>> analyzeImageBytes(
      Uint8List imageBytes) async {
    debugPrint('[OfflineInference] Starting analysis...');
    await initialize();

    if (_diseaseInterpreter == null || _labels == null) {
      throw Exception('Offline model not initialized.');
    }

    // ── 1. Preprocess ────────────────────────────────────────────────────────
    debugPrint('[OfflineInference] Decoding image...');
    img.Image? originalImage = img.decodeImage(imageBytes);
    if (originalImage == null) throw Exception('Failed to decode image.');

    debugPrint('[OfflineInference] Bypassing preprocessing for testing...');
    img.Image preprocessedImage = originalImage;

    debugPrint('[OfflineInference] Resizing to 224x224...');
    img.Image resizedImage =
        img.copyResize(preprocessedImage, width: 224, height: 224);

    // ── 2. Build input tensor [1, 224, 224, 3] ───────────────────────────────
    debugPrint('[OfflineInference] Building input tensor...');
    var input = _buildInputTensor(resizedImage);
    
    // Log theoretical shape helpfully
    debugPrint('[OfflineInference] Input tensor built. Shape: [1, 224, 224, 3]');

    // ── 3. Run inference ─────────────────────────────────────────────────────
    // NOTE: The model actually has 46 outputs. We map them to our 8 labels.
    const int modelOutputSize = 46;
    debugPrint('[OfflineInference] Preparing output buffer for $modelOutputSize raw outputs...');
    var rawOutput = List.filled(1, List.filled(modelOutputSize, 0.0));
    
    debugPrint('[OfflineInference] RUNNING INFERENCE...');
    try {
      _diseaseInterpreter!.run(input, rawOutput);
      debugPrint('[OfflineInference] Inference completed successfully.');
    } catch (e) {
      debugPrint('[OfflineInference] ERROR during interpreter.run(): $e');
      rethrow;
    }

    // ── 4. Use 46 outputs ───────────────────────────────────────────────────
    List<double> finalProbabilities = List<double>.from(rawOutput[0]);

    // ── 5. Process results ───────────────────────────────────────────────────
    return _processOutput(finalProbabilities, tag: 'SINGLE-FRAME');
  }

  /// Runs classification over multiple frames and averages probabilities.
  static Future<Map<String, dynamic>> analyzeMultipleFrames(
      List<Uint8List> framesBytes) async {
    debugPrint('[OfflineInference] Starting multi-frame analysis (${framesBytes.length} frames)...');
    try {
      await initialize();
    } catch (e) {
      debugPrint('[OfflineInference] Multi-frame analysis failed during initialization: $e');
      rethrow;
    }

    if (_diseaseInterpreter == null || _labels == null) {
      throw Exception('Offline model not initialized.');
    }
    if (framesBytes.isEmpty) throw Exception('No frames provided.');

    List<double> summedProbabilities = List.filled(46, 0.0);
    int processedFrames = 0;

    for (int i = 0; i < framesBytes.length; i++) {
      try {
        var imageBytes = framesBytes[i];
        img.Image? originalImage = img.decodeImage(imageBytes);
        if (originalImage == null) {
          debugPrint('[OfflineInference] Frame #$i: Failed to decode.');
          continue;
        }

        img.Image preprocessedImage = originalImage;
        img.Image resizedImage =
            img.copyResize(preprocessedImage, width: 224, height: 224);

        var input = _buildInputTensor(resizedImage);
        var rawOutput = List.filled(1, List.filled(46, 0.0));
        
        _diseaseInterpreter!.run(input, rawOutput);

        List<double> probabilities = rawOutput[0];
        for (int j = 0; j < probabilities.length; j++) {
          summedProbabilities[j] += probabilities[j];
        }
        processedFrames++;
      } catch (e) {
        debugPrint('[OfflineInference] Frame #$i: Error during processing/inference: $e');
        // Continue to next frame if one fails
      }
    }

    if (processedFrames == 0) {
      throw Exception('All multi-frame analysis attempts failed.');
    }

    debugPrint('[OfflineInference] Multi-frame analysis complete. Processed $processedFrames frames.');

    // Average over processed frames
    for (int i = 0; i < summedProbabilities.length; i++) {
      summedProbabilities[i] /= processedFrames;
    }

    // Use 46 outputs directly
    List<double> finalProbabilities = summedProbabilities;

    return _processOutput(finalProbabilities, tag: 'MULTI-FRAME');
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  /// Normalizes a single channel value according to [_activeNormalization].
  static double _normalizeChannel(num channelValue) {
    switch (_activeNormalization) {
      case NormalizationMode.optionA:
        return channelValue / 255.0;
      case NormalizationMode.optionB:
        return (channelValue / 127.5) - 1.0;
      case NormalizationMode.none:
        return channelValue.toDouble();
    }
  }

  /// Builds the [1, 224, 224, 3] float input tensor from a 224×224 image.
  static List _buildInputTensor(img.Image image) {
    return List.generate(
      1,
      (_) => List.generate(
        224,
        (y) => List.generate(
          224,
          (x) {
            final pixel = image.getPixel(x, y);
            return [
              _normalizeChannel(pixel.r),
              _normalizeChannel(pixel.g),
              _normalizeChannel(pixel.b),
            ];
          },
        ),
      ),
    );
  }

  /// Sorts probabilities, prints top-3, applies fallback logic, and returns
  /// the result map.
  static Map<String, dynamic> _processOutput(
    List<double> probabilities, {
    required String tag,
  }) {
    const normLabels = {
      NormalizationMode.optionA: 'Option A (pixel / 255.0)',
      NormalizationMode.optionB: 'Option B ((pixel / 127.5) - 1)',
      NormalizationMode.none: 'None (raw uint8)',
    };
    final normName = normLabels[_activeNormalization]!;

    var indexed = probabilities.asMap().entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    var top3 = indexed.take(3).toList();

    // ── Debug output ──────────────────────────────────────────────────────────
    debugPrint('');
    debugPrint('════════════════════════════════════════');
    debugPrint('  [$tag] INFERENCE RESULT');
    debugPrint('  Normalization: $normName');
    debugPrint('────────────────────────────────────────');
    for (int i = 0; i < top3.length; i++) {
      final label = _labels![top3[i].key];
      final conf = (top3[i].value * 100).toStringAsFixed(2);
      debugPrint('  #${i + 1}: $label  →  $conf%');
    }
    debugPrint('════════════════════════════════════════');
    debugPrint('');

    int bestIndex = top3[0].key;
    double maxProb = top3[0].value;
    String rawDiseaseClass = _labels![bestIndex];
    
    // Clean and format label (e.g. "apple___apple_scab" -> "Apple - Apple Scab")
    String s = rawDiseaseClass.replaceAll('___', ' - ')
                              .replaceAll('_', ' ')
                              .replaceAll('(', '')
                              .replaceAll(')', '')
                              .replaceAll(',', '');

    String diseaseClass = s.split(' ').map((word) {
      if (word.isEmpty) return '';
      if (word == '-') return '-';
      
      if (word.contains('-') && word.length > 1) {
        return word.split('-').map((sub) {
           if (sub.isEmpty) return '';
           return '${sub[0].toUpperCase()}${sub.substring(1).toLowerCase()}';
        }).join('-');
      }

      return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
    }).join(' ');
    
    diseaseClass = diseaseClass.replaceAll(RegExp(r'\s+'), ' ').trim();

    List<String> recommendations = [];

    if (maxProb < 0.5) {
      recommendations.add('Unclear image. Please try again.');
    } else {
      if (diseaseClass.toLowerCase().contains('healthy')) {
        recommendations.add('Plant looks healthy! Continue standard care.');
      } else {
        recommendations.add('Species/Condition detected: $diseaseClass.');
      }
    }

    return {
      'disease_detected': diseaseClass,
      'confidence': maxProb,
      'recommendation': recommendations.join(' | '),
      'mode': tag == 'MULTI-FRAME' ? 'Offline Multi-Frame' : 'Offline',
    };
  }


}
