import 'package:flutter/material.dart';
import 'data/datasources/local/local_database.dart';
import 'presentation/screens/splash/splash_screen.dart';
import 'services/api_service.dart';
import 'services/fraud_flag_sync_service.dart';
import 'services/offline_scan_sync_service.dart';
import 'services/session_expiry_service.dart';
import 'services/status_sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize local database
  await LocalDatabase.init();

  // Restore saved auth token so the user stays logged in after restarts.
  // If it has expired, the splash screen sends the user to login once the
  // server is reachable; offline they can still scan.
  await ApiService.loadToken();

  // Sign out when the server rejects the token, or when the app resumes or
  // comes back online holding an expired one.
  SessionExpiryService.init();

  // REQ-2.6.4: Initialize offline fraud flag sync service
  await FraudFlagSyncService.init();

  // Initialize offline scan sync service. Replays scans queued while the API
  // was unreachable to verification_logs when connectivity is restored.
  await OfflineScanSyncService.init();

  // REQ-2.9.1 / REQ-2.9.3: Start polling for credential status changes.
  // Propagates revoked/suspended IDs to this device within seconds.
  await StatusSyncService.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'iDetect',
      scaffoldMessengerKey: OfflineScanSyncService.messengerKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const SplashScreen(),
    );
  }
}
