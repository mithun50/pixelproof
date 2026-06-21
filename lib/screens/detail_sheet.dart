import 'package:flutter/material.dart';

import '../models/classified_asset.dart';
import '../models/detection_result.dart';
import '../widgets/confidence_badge.dart';

/// Bottom sheet with the full explainable breakdown for one image.
class DetailSheet extends StatelessWidget {
  const DetailSheet({super.key, required this.item});

  final ClassifiedAsset item;

  static Future<void> show(BuildContext context, ClassifiedAsset item) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => DetailSheet(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = item.result;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (result == null)
            const Text('Not yet scanned.')
          else ...[
            Row(
              children: [
                Icon(VerdictColors.iconOf(result.verdict),
                    color: VerdictColors.of(result.verdict)),
                const SizedBox(width: 8),
                Text(
                  result.verdict.label,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: VerdictColors.of(result.verdict),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text('${result.confidencePercent} confidence',
                    style: theme.textTheme.bodyMedium),
              ],
            ),
            const SizedBox(height: 8),
            Text(result.reason, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 4),
            Text('Decided by: ${result.decidingSignal.displayName}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline)),
            const Divider(height: 28),
            Text('Signal breakdown', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            ...result.tiers.map((t) => _TierRow(tier: t)),
          ],
        ],
      ),
    );
  }
}

class _TierRow extends StatelessWidget {
  const _TierRow({required this.tier});

  final TierResult tier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            tier.fired ? Icons.check_circle : Icons.remove_circle_outline,
            size: 18,
            color: tier.fired
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tier.signal.displayName,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                if (tier.detail.isNotEmpty)
                  Text(tier.detail,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.outline)),
              ],
            ),
          ),
          if (tier.aiProbability != null)
            Text('${(tier.aiProbability! * 100).round()}% AI',
                style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
