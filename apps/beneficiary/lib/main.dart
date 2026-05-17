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
        useMaterial3: true,
        primaryColor: AppDesignSystem.primaryBlue,
        scaffoldBackgroundColor: AppDesignSystem.backgroundWarm,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppDesignSystem.primaryBlue,
          primary: AppDesignSystem.primaryBlue,
          secondary: AppDesignSystem.interactiveBlue,
          surface: AppDesignSystem.backgroundWarm,
          error: AppDesignSystem.accentRed,
        ),
        // AppBar — match the deep blue header with white text
        appBarTheme: const AppBarTheme(
          backgroundColor: AppDesignSystem.primaryBlue,
          foregroundColor: AppDesignSystem.textOnDark,
          elevation: 0,
          titleTextStyle: AppDesignSystem.heading4,
          toolbarHeight: 64,
        ),
        // Text Theme — apply the accessible scale globally
        textTheme:
            const TextTheme(
              displayLarge: AppDesignSystem.displayLarge,
              headlineLarge: AppDesignSystem.heading1,
              headlineMedium: AppDesignSystem.heading3,
              headlineSmall: AppDesignSystem.heading4,
              titleLarge: AppDesignSystem.heading4,
              bodyLarge: AppDesignSystem.bodyLarge,
              bodyMedium: AppDesignSystem.bodyMedium,
              bodySmall: AppDesignSystem.bodySmall,
              labelLarge: AppDesignSystem.buttonMedium,
              labelMedium: AppDesignSystem.label,
              labelSmall: AppDesignSystem.caption,
            ).apply(
              bodyColor: AppDesignSystem.textPrimary,
              displayColor: AppDesignSystem.textPrimary,
            ),
        // ElevatedButton — use primary style by default
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: AppDesignSystem.primaryButton,
        ),
        // OutlinedButton
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: AppDesignSystem.secondaryButton,
        ),
        // TextButton
        textButtonTheme: TextButtonThemeData(style: AppDesignSystem.textButton),
        // Input fields
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppDesignSystem.backgroundInput,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 18,
          ),
          border: OutlineInputBorder(
            borderRadius: AppDesignSystem.inputRadius,
            borderSide: const BorderSide(color: AppDesignSystem.borderLight),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppDesignSystem.inputRadius,
            borderSide: const BorderSide(
              color: AppDesignSystem.borderLight,
              width: 1.5,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppDesignSystem.inputRadius,
            borderSide: const BorderSide(
              color: AppDesignSystem.borderFocus,
              width: 2.5,
            ),
          ),
          hintStyle: AppDesignSystem.bodyMedium.copyWith(
            color: AppDesignSystem.textHint,
          ),
          labelStyle: AppDesignSystem.label,
        ),
        // Navigation bar
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: AppDesignSystem.backgroundWhite,
          indicatorColor: AppDesignSystem.primaryBlue.withOpacity(0.12),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppDesignSystem.bodySmall.copyWith(
                color: AppDesignSystem.primaryBlue,
                fontWeight: FontWeight.w700,
              );
            }
            return AppDesignSystem.bodySmall.copyWith(
              color: AppDesignSystem.textSecondary,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(
                color: AppDesignSystem.primaryBlue,
                size: AppDesignSystem.navIconSize,
              );
            }
            return const IconThemeData(
              color: AppDesignSystem.textSecondary,
              size: AppDesignSystem.navIconSize,
            );
          }),
          height: AppDesignSystem.navBarHeight,
        ),
        // Card
        cardTheme: CardThemeData(
          color: AppDesignSystem.backgroundWhite,
          elevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: AppDesignSystem.cardRadius,
          ),
          margin: const EdgeInsets.all(0),
        ),
        // Divider
        dividerTheme: const DividerThemeData(
          color: AppDesignSystem.borderLight,
          thickness: 1,
          space: 0,
        ),
        // SnackBar
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: const RoundedRectangleBorder(
            borderRadius: AppDesignSystem.buttonRadius,
          ),
          contentTextStyle: AppDesignSystem.bodySmall.copyWith(
            color: AppDesignSystem.textOnDark,
          ),
        ),
      ),
      home: ApiService.isLoggedIn ? const HomeScreen() : const LoginScreen(),
    );
  }
}
