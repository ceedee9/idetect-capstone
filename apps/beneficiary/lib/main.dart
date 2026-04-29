import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/constants/app_design_system.dart';
import 'services/api_service.dart';
import 'services/fcm_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Initialize Firebase (required for FCM)
  await Firebase.initializeApp();

  // Pre-load saved token
  await ApiService.loadToken();

  // Initialize FCM — requests permission, registers token
  await FcmService.initialize();

  runApp(const IDetectBeneficiaryApp());
}

class IDetectBeneficiaryApp extends StatelessWidget {
  const IDetectBeneficiaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'iDetect Beneficiary',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: AppDesignSystem.primaryBlue,
        scaffoldBackgroundColor: AppDesignSystem.backgroundLight,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppDesignSystem.primaryBlue,
          primary: AppDesignSystem.primaryBlue,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppDesignSystem.primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: ApiService.isLoggedIn ? const HomeScreen() : const LoginScreen(),
    );
  }
}
