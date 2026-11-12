import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/gg_card.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('About'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // App Identity
            Icon(Icons.shield_rounded, size: 80, color: colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              "Green Guard v1.0.0",
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            Text(
              "AI-Powered Agriculture Diagnostic Tool",
              style: GoogleFonts.poppins(fontSize: 14, color: colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 32),

            // Project Info
            GGCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle(context, "Our Mission"),
                  const Text(
                    "To empower farmers with high-precision AI diagnostics for sustainable and efficient crop protection.",
                    style: TextStyle(height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTitle(context, "Tech Stack"),
                  _buildTechItem("Frontend", "Flutter (Material 3)"),
                  _buildTechItem("Backend", "FastAPI (Python)"),
                  _buildTechItem("Intelligence", "TensorFlow Lite"),
                  _buildTechItem("Inference", "EfficientNetV2 & MobileNetV2"),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Text(
              "Developed for Final Year Project (FYP)",
              style: GoogleFonts.poppins(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.4)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildTechItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(value, style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }
}
