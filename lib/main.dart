import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/classifier_service.dart';
import 'services/detection_engine.dart';
import 'services/background_scan_service.dart';
import 'services/gallery_service.dart';
import 'services/metadata_service.dart';
import 'services/notification_service.dart';
import 'services/permission_service.dart';
import 'services/result_cache.dart';
import 'services/synthid_detector.dart';
import 'state/scan_controller.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init();
  await configureBackgroundService();
  runApp(const PixelProofApp());
}

class PixelProofApp extends StatelessWidget {
  const PixelProofApp({super.key});

  @override
  Widget build(BuildContext context) {
    final permissionService = PermissionService();
    final engine = DetectionEngine(
      metadata: const MetadataService(),
      synthid: const SynthIdDetector(),
      classifier: ClassifierService(),
    );

    return ChangeNotifierProvider(
      create: (_) => ScanController(
        permissionService: permissionService,
        galleryService: GalleryService(),
        engine: engine,
        cache: ResultCache(),
      ),
      child: MaterialApp(
        title: 'PixelProof',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3E63DD)),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF3E63DD),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const _RootGate(),
      ),
    );
  }
}

/// Decides whether to show onboarding or the home screen based on existing
/// photo permission.
class _RootGate extends StatefulWidget {
  const _RootGate();

  @override
  State<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<_RootGate> {
  late final Future<PhotoAccess> _access =
      context.read<ScanController>().refreshAccess();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PhotoAccess>(
      future: _access,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final access = snapshot.data!;
        if (access == PhotoAccess.full || access == PhotoAccess.limited) {
          return const HomeScreen();
        }
        return const OnboardingScreen();
      },
    );
  }
}
