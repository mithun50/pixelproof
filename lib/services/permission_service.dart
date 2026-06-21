import 'package:photo_manager/photo_manager.dart';

/// Result of a photo-library permission request.
enum PhotoAccess {
  /// Full access to the entire library.
  full,

  /// Limited access — user selected a subset of photos (iOS 14+, Android 14+).
  limited,

  /// Access denied.
  denied,
}

/// Wraps photo-library permission handling via `photo_manager`.
///
/// `photo_manager` already bridges the platform-specific permission models
/// (Android `READ_MEDIA_IMAGES` / `READ_MEDIA_VISUAL_USER_SELECTED`, iOS
/// `PHPhotoLibrary`), so a separate permission plugin is unnecessary.
class PermissionService {
  /// Requests photo-library access, returning the granted level.
  Future<PhotoAccess> request() async {
    final PermissionState state =
        await PhotoManager.requestPermissionExtend();
    return _map(state);
  }

  /// Checks the current permission level without prompting.
  Future<PhotoAccess> current() async {
    final PermissionState state = await PhotoManager.requestPermissionExtend(
      requestOption: const PermissionRequestOption(),
    );
    return _map(state);
  }

  /// Opens the OS settings page so the user can change permissions manually.
  Future<void> openSettings() => PhotoManager.openSetting();

  /// Presents the limited-library picker (iOS) so the user can add more photos.
  Future<void> presentLimitedPicker() =>
      PhotoManager.presentLimited();

  PhotoAccess _map(PermissionState state) {
    switch (state) {
      case PermissionState.authorized:
        return PhotoAccess.full;
      case PermissionState.limited:
        return PhotoAccess.limited;
      case PermissionState.denied:
      case PermissionState.restricted:
      case PermissionState.notDetermined:
        return PhotoAccess.denied;
    }
  }
}
