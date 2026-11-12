import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/gg_card.dart';
import '../widgets/gg_button.dart';
import '../data/disease_data.dart';

class TreatmentScreen extends StatelessWidget {
  final Map<String, dynamic> result;

  const TreatmentScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final String rawDisease = result['disease_detected']?.toString() ?? 'Unknown';
    final info = DiseaseData.getInfo(rawDisease);
    final bool isHealthy = rawDisease.toLowerCase().contains('healthy');
    final String weedPercentString = result['weed_density']?.toString().replaceAll('%', '') ?? '0';
    final double weedDensity = double.tryParse(weedPercentString) ?? 0.0;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Treatment Plan'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, isHealthy, info.formattedName),
            const SizedBox(height: 24),
            
            _buildSectionTitle(context, "Disease Overview"),
            const SizedBox(height: 8),
            Text(
              info.description,
              style: GoogleFonts.poppins(fontSize: 14, color: colorScheme.onSurface.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 20),
            
            _buildSectionTitle(context, "Management Steps"),
            const SizedBox(height: 12),
            _buildTreatmentCard(
              context,
              title: "Recommended Actions",
              steps: info.treatments,
              icon: Icons.healing_outlined,
              color: isHealthy ? Colors.green[700]! : Colors.orange[800]!,
            ),
            const SizedBox(height: 24),

            _buildSectionTitle(context, "Weed Control"),
            const SizedBox(height: 12),
            _buildTreatmentCard(
              context,
              title: "Density Management",
              steps: [_getWeedTreatment(weedDensity)],
              icon: Icons.grass_outlined,
              color: Colors.green[700]!,
            ),
            const SizedBox(height: 24),

            _buildSectionTitle(context, "Expert Consultation"),
            const SizedBox(height: 12),
            GGCard(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                   CircleAvatar(
                    radius: 30,
                    backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                    child: Icon(Icons.support_agent_rounded, color: colorScheme.primary, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Talk to an Agronomist",
                          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "Get personalized advice for your specific soil and crop conditions.",
                          style: GoogleFonts.poppins(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.6)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            GGButton(
              label: 'Return to Dashboard',
              onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
              icon: Icons.home_rounded,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isHealthy, String diseaseName) {
    final colorScheme = Theme.of(context).colorScheme;
    return GGCard(
      color: isHealthy ? Colors.green[50]?.withValues(alpha: 0.1) : Colors.red[50]?.withValues(alpha: 0.1),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Icon(
            isHealthy ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded,
            color: isHealthy ? Colors.green : Colors.red,
            size: 40,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  diseaseName,
                  style: GoogleFonts.poppins(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold,
                    color: isHealthy ? Colors.green : Colors.red,
                  ),
                ),
                Text(
                  isHealthy 
                    ? "Your crops are in excellent condition. Follow preventive care."
                    : "Immediate intervention recommended to prevent spread.",
                  style: GoogleFonts.poppins(fontSize: 13, color: colorScheme.onSurface.withValues(alpha: 0.7)),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  Widget _buildTreatmentCard(BuildContext context, {
    required String title,
    required List<String> steps,
    required IconData icon,
    required Color color,
  }) {
    return GGCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
          const Divider(height: 24),
          ...steps.map((step) => Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("• ", style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                Expanded(
                  child: Text(
                    step,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  String _getWeedTreatment(double density) {
    if (density > 20) {
      return "Critical Level: Immediate mechanical weeding or broad-spectrum herbicide application is required to prevent yield loss. Competition for nutrients is currently high.";
    } else if (density > 10) {
      return "Warning Level: Targeted weeding recommended. Consider using mulch to suppress further growth and focus on removing weeds before they flower.";
    } else if (density > 5) {
      return "Maintenance Level: Light hand weeding should suffice. Monitor for aggressive species that might spread quickly.";
    }
    return "Healthy Level: Weed density is within acceptable limits. Standard maintenance and monitoring are sufficient.";
  }
}
