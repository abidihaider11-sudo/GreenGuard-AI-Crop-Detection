import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'offline_inference_service.dart';

class ApiService {
  // CONFIGURATION
  static const bool useMockMode = false;
  static bool isOfflineMode = false; // User can toggle this
  
  // URLS
  // 💡 TIP: Set this to your PC's local IP (e.g., 192.168.1.XX) for mobile testing
  static String serverIp = "127.0.0.1"; 
  static String get baseUrl => "http://$serverIp:8000";

  /// Sends the selected image to the backend for analysis or runs offline
  static Future<Map<String, dynamic>> analyzeField(XFile imageFile) async {
    if (useMockMode) {
      await Future.delayed(const Duration(seconds: 2));
      return {
        "weed_density": "12.5%",
        "disease_detected": "tomato___early_blight",
        "confidence": 0.92,
        "recommendation": "Mock: High weed density! | Detected Early Blight on Tomato."
      };
    }

    // 1️⃣ OFFLINE MODE CHECK
    if (isOfflineMode) {
      debugPrint("ApiService: Using Offline Mode.");
      return await OfflineInferenceService.analyzeImage(File(imageFile.path));
    }

    try {
      // 2️⃣ ONLINE ATTEMPT
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/analyze-field'));
      Uint8List bytes = await imageFile.readAsBytes();
      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: imageFile.name));

      // Add a timeout for the server check
      var streamedResponse = await request.send().timeout(const Duration(seconds: 5));
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception("Server Error: ${response.statusCode}. Falling back to offline?");
      }
    } catch (e) {
      // 3️⃣ AUTOMATIC FALLBACK
      debugPrint("ApiService: Online failed ($e). Falling back to Offline Inference...");
      try {
        return await OfflineInferenceService.analyzeImage(File(imageFile.path));
      } catch (offlineError) {
        throw Exception("Both Online and Offline analysis failed. Offline Error: $offlineError");
      }
    }
  }

  /// Health check
  static Future<bool> checkHealth() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/health'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['status'] == "Green Guard API is running";
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
