import 'package:flutter/foundation.dart';

class DiseaseInfo {
  final String crop;
  final String disease;
  final String description;
  final List<String> treatments;

  DiseaseInfo({
    required this.crop,
    required this.disease,
    required this.description,
    required this.treatments,
  });

  /// Now simply returns the raw label as provided by the model.
  String get formattedName => disease;
}

class DiseaseData {
  /// Legacy hardcoded mappings removed.
  /// New model integration uses raw labels.
  static DiseaseInfo getInfo(String rawLabel) {
    final cleanLabel = rawLabel.trim();
    debugPrint("Fetching info for new model label: '$cleanLabel'");
    
    final bool isHealthy = cleanLabel.toLowerCase().contains('healthy');

    if (isHealthy) {
      return DiseaseInfo(
        crop: cleanLabel,
        disease: cleanLabel,
        description: 'This plant variety appears to be in good health based on visual analysis.',
        treatments: [
          'Continue standard irrigation and fertilization.',
          'Monitor for future signs of stress or pests.',
          'Practice good sanitation in the field.',
        ],
      );
    }

    return DiseaseInfo(
      crop: cleanLabel,
      disease: cleanLabel,
      description: 'Potential disease or stress detected. Specific variety data is currently pending integration.',
      treatments: [
        'Quarantine affected plants if possible.',
        'Consult with a local agronomist for a precise field check.',
        'Scan again in better lighting for verified confidence.',
        'Detailed treatment steps for this variety will be updated soon.',
      ],
    );
  }
}
