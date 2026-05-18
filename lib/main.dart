import 'package:flutter/material.dart';
import 'data/datasources/local/local_database.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'services/api_service.dart';
import 'services/fraud_flag_sync_service.dart';
import 'services/offline_scan_sync_service.dart';
import 'services/status_sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize local database
  await LocalDatabase.init();

  // Restore saved auth token so the user stays logged in after restarts
  await ApiService.loadToken();

  // REQ-2.6.4: Initialize offline fraud flag sync service
  await FraudFlagSyncService.init();

  // Problem A fix: Initialize offline scan sync service.
  // Replays scans that occurred while the API was unreachable back to
  // PostgreSQL verification_logs when connectivity is restored.
  await OfflineScanSyncService.init();

  // REQ-2.9.1 / REQ-2.9.3: Start polling for credential status changes.
  // Propagates revoked/suspended IDs to this device within 10 seconds.
  await StatusSyncService.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'iDetect',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const LoginScreen(),
    );
  }
}
