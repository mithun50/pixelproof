import 'dart:typed_data';

import 'package:photo_manager/photo_manager.dart';

/// Loads image assets from the device photo library.
class GalleryService {
  /// Loads all image assets across the library, newest first.
  ///
  /// Returns a flat list of [AssetEntity]. Thumbnails and full bytes are
  /// fetched lazily per-asset to keep memory bounded on large libraries.
  Future<List<AssetEntity>> loadAllImages({int pageSize = 200}) async {
    final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: true,
    );
    if (albums.isEmpty) return const [];

    final AssetPathEntity all = albums.first;
    final int count = await all.assetCountAsync;
    if (count == 0) return const [];

    final List<AssetEntity> assets = [];
    final int pages = (count / pageSize).ceil();
    for (int page = 0; page < pages; page++) {
      final List<AssetEntity> batch =
          await all.getAssetListPaged(page: page, size: pageSize);
      assets.addAll(batch);
    }
    return assets;
  }

  /// Returns a thumbnail for grid display.
  Future<Uint8List?> thumbnail(
    AssetEntity asset, {
    int size = 256,
  }) {
    return asset.thumbnailDataWithSize(ThumbnailSize.square(size));
  }

  /// Returns medium-resolution bytes suitable for model inference.
  ///
  /// Using a bounded thumbnail (rather than the full-res original) keeps
  /// decode + preprocessing fast; the classifier downsamples to 224px anyway.
  Future<Uint8List?> bytesForInference(
    AssetEntity asset, {
    int maxSide = 512,
  }) async {
    final Uint8List? data =
        await asset.thumbnailDataWithSize(ThumbnailSize.square(maxSide));
    if (data != null) return data;
    // Fallback to the original file bytes.
    final file = await asset.originBytes;
    return file;
  }
}
