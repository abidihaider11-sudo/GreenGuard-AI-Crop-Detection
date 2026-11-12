import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

class ScanRecord {
  final String diseaseDetected;
  final double confidence;
  final String recommendation;
  final String mode;
  final DateTime scannedAt;
  final String? imagePath;

  ScanRecord({
    required this.diseaseDetected,
    required this.confidence,
    required this.recommendation,
    required this.mode,
    required this.scannedAt,
    this.imagePath,
  });

  Map<String, dynamic> toJson() => {
    'diseaseDetected': diseaseDetected,
    'confidence': confidence,
    'recommendation': recommendation,
    'mode': mode,
    'scannedAt': scannedAt.toIso8601String(),
    'imagePath': imagePath,
  };

  factory ScanRecord.fromJson(Map<String, dynamic> json) => ScanRecord(
    diseaseDetected: json['diseaseDetected'] ?? '',
    confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
    recommendation: json['recommendation'] ?? '',
    mode: json['mode'] ?? '',
    scannedAt: DateTime.parse(json['scannedAt']),
    imagePath: json['imagePath'],
  );
}

class ScanHistoryService {
  static const _key = 'scan_history';

  static Future<List<ScanRecord>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final List<dynamic> decoded = jsonDecode(raw);
      return decoded.map((e) => ScanRecord.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> saveRecord(Map<String, dynamic> result, [Uint8List? imageBytes]) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await loadHistory();

    String? savedPath;
    if (imageBytes != null) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        final fileName = 'scan_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final file = File(p.join(dir.path, fileName));
        await file.writeAsBytes(imageBytes);
        savedPath = file.path;
      } catch (e) {
        // Silently fail image saving
      }
    }

    final record = ScanRecord(
      diseaseDetected: result['disease_detected']?.toString() ?? 'Unknown',
      confidence: (result['confidence'] as num?)?.toDouble() ?? 0.0,
      recommendation: result['recommendation']?.toString() ?? '',
      mode: result['mode']?.toString() ?? 'Offline',
      scannedAt: DateTime.now(),
      imagePath: savedPath,
    );

    // Limit to last 10 records as requested
    final updated = [record, ...existing].take(10).toList();
    
    // Clean up images of removed records
    if (existing.length >= 10) {
      for (int i = 9; i < existing.length; i++) {
        final oldPath = existing[i].imagePath;
        if (oldPath != null) {
          final oldFile = File(oldPath);
          if (await oldFile.exists()) await oldFile.delete();
        }
      }
    }

    final encoded = jsonEncode(updated.map((e) => e.toJson()).toList());
    await prefs.setString(_key, encoded);
  }

  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final history = await loadHistory();
    for (var record in history) {
      if (record.imagePath != null) {
        final file = File(record.imagePath!);
        if (await file.exists()) await file.delete();
      }
    }
    await prefs.remove(_key);
  }
}
