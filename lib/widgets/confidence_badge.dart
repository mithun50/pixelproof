import 'package:flutter/material.dart';

import '../models/detection_result.dart';

/// Shared colors for verdicts.
class VerdictColors {
  static Color of(Verdict verdict) => switch (verdict) {
        Verdict.ai => const Color(0xFFE5484D), // red
        Verdict.real => const Color(0xFF30A46C), // green
        Verdict.uncertain => const Color(0xFFF5A623), // amber
      };

  static IconData iconOf(Verdict verdict) => switch (verdict) {
        Verdict.ai => Icons.smart_toy_outlined,
        Verdict.real => Icons.photo_camera_outlined,
        Verdict.uncertain => Icons.help_outline,
      };
}

/// A small pill showing the verdict and confidence over a thumbnail.
class ConfidenceBadge extends StatelessWidget {
  const ConfidenceBadge({super.key, required this.result});

  final DetectionResult result;

  @override
  Widget build(BuildContext context) {
    final color = VerdictColors.of(result.verdict);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(VerdictColors.iconOf(result.verdict),
              size: 12, color: Colors.white),
          const SizedBox(width: 3),
          Text(
            result.confidencePercent,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
