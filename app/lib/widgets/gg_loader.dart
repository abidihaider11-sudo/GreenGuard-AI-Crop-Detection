import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

class GGLoader extends StatelessWidget {
  final String message;

  const GGLoader({super.key, this.message = "Analyzing with AI..."});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 🎭 Lottie Scanning Animation
          SizedBox(
            height: 200,
            child: Lottie.network(
              'https://lottie.host/02008fb5-635b-4c12-9860-2646c2436d41/lAEv6lUfG0.json',
              errorBuilder: (context, error, stackTrace) => const CircularProgressIndicator(),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            message,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Analyzing crop health and detecting weeds...",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
