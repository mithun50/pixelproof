import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

import '../models/classified_asset.dart';
import 'confidence_badge.dart';

/// A single grid tile showing a cached thumbnail and (once known) a verdict badge.
///
/// Uses [AssetEntityImage] (photo_manager's cached image provider) plus a
/// [RepaintBoundary] so fast scrolling doesn't re-decode or repaint neighbours.
class AssetTile extends StatelessWidget {
  const AssetTile({super.key, required this.item, this.onTap});

  final ClassifiedAsset item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            AssetEntityImage(
              item.asset,
              isOriginal: false,
              thumbnailSize: const ThumbnailSize.square(200),
              thumbnailFormat: ThumbnailFormat.jpeg,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              frameBuilder: (context, child, frame, _) {
                if (frame == null) {
                  return Container(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                  );
                }
                return child;
              },
            ),
            if (item.result != null)
              Positioned(
                left: 4,
                bottom: 4,
                child: ConfidenceBadge(result: item.result!),
              ),
          ],
        ),
      ),
    );
  }
}
