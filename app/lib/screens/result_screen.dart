import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import '../data/disease_data.dart';
import '../widgets/gg_card.dart';
import '../widgets/gg_button.dart';
import '../services/scan_history_service.dart';
import 'treatment_screen.dart';

class ResultScreen extends StatefulWidget {
  final Map<String, dynamic> result;
  final Uint8List imageBytes;

  const ResultScreen({super.key, required this.result, required this.imageBytes});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  @override
  void initState() {
    super.initState();
    // Save this scan to history
    ScanHistoryService.saveRecord(widget.result, widget.imageBytes);
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final imageBytes = widget.imageBytes;
    final String diseaseLabel = result['disease_detected']?.toString() ?? 'Unknown';
    debugPrint("ResultScreen received label: '$diseaseLabel'");
    final diseaseInfo = DiseaseData.getInfo(diseaseLabel);
    
    final bool isHealthy = diseaseLabel.toLowerCase().contains('healthy');
    final double confidence = ((result['confidence'] as num?)?.toDouble() ?? 0.0) * 100;
    


    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: const Text('Analysis Report'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Center(
              child: SizedBox(
                height: 120,
                child: Lottie.network(
                  isHealthy 
                    ? 'https://lottie.host/8048f70d-f06b-4df2-8951-4091f0f4a46a/7vT01f9r7z.json' 
                    : 'https://lottie.host/c5c16304-4b4d-4581-9f22-38605c363d39/S1L88K9n9k.json',
                  repeat: false,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Preview Image
            Hero(
              tag: 'image_preview',
              child: GGCard(
                padding: EdgeInsets.zero,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.memory(imageBytes, height: 260, width: double.infinity, fit: BoxFit.cover),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Main Diagnosis Card
            _buildMainDiagnosisCard(context, diseaseLabel, confidence / 100, diseaseInfo),
            
            const SizedBox(height: 24),
            
            // Description Card
            _buildInfoCard(context, "About the Condition", diseaseInfo.description, Icons.info_outline_rounded),
            
            const SizedBox(height: 16),
            
            // Recommendation Section
            _buildRecommendationCard(context, diseaseInfo),
            const SizedBox(height: 32),
            
            // Action Buttons
            GGButton(
              label: 'Proceed to Treatment',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => TreatmentScreen(result: result),
                  ),
                );
              },
              icon: Icons.medical_services_outlined,
            ),
            const SizedBox(height: 12),
            GGButton(
              label: 'Scan Again',
              onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
              isSecondary: true,
              icon: Icons.refresh_rounded,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, String title, String content, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        GGCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: colorScheme.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  content,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: colorScheme.onSurface.withValues(alpha: 0.8),
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMainDiagnosisCard(BuildContext context, String rawLabel, double confidence, DiseaseInfo info) {
    final bool isHealthy = rawLabel.toLowerCase().contains('healthy');
    final Color statusColor = isHealthy ? const Color(0xFF2E7D32) : const Color(0xFFD32F2F);
    final Color bgColor = isHealthy ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE);
    final String confidenceText = '${(confidence * 100).toStringAsFixed(1)}%';

    return GGCard(
      color: bgColor,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isHealthy ? Icons.check_circle_rounded : Icons.warning_rounded,
                  color: statusColor,
                  size: 32,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Display logic: check if confidence meets threshold
                    Text(
                      confidence < 0.5 
                          ? 'Unclear image. Please try again.' 
                          : rawLabel,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: confidence < 0.5 ? const Color(0xFFD32F2F) : statusColor,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Confidence badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.analytics_outlined, size: 14, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            'Confidence: $confidenceText',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Confidence bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: confidence,
                  backgroundColor: statusColor.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                confidenceText,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: statusColor.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard(BuildContext context, DiseaseInfo info) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            "Treatment Recommendations",
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        GGCard(
          color: colorScheme.primaryContainer.withValues(alpha: 0.4),
          child: Column(
            children: info.treatments.map((t) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_outline_rounded, color: colorScheme.primary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      t,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: colorScheme.onPrimaryContainer,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            )).toList(),
          ),
        ),
      ],
    );
  }
}
