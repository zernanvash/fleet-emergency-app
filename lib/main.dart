import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/sos_screen.dart';
import 'services/api_service.dart';
import 'services/directus_auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Auto-discover working Next.js BFF base URL
  await ApiService().autoDiscoverBaseUrl();

  // Check if a Directus session exists (user_id stored locally)
  final hasActiveSession = await DirectusAuthService().hasSession();

  runApp(MyApp(hasActiveSession: hasActiveSession));
}

class MyApp extends StatelessWidget {
  final bool hasActiveSession;

  const MyApp({
    super.key,
    required this.hasActiveSession,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VOS Fleet SOS',
      debugShowCheckedModeBanner: false,

      // VOS enterprise light operational theming.
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF1D4ED8), // Primary VOS Blue
          secondary: Color(0xFF3B82F6), // Supporting Blue
          surface: Color(0xFFFFFFFF), // White cards
          error: Color(0xFFEF4444), // Destructive Red
        ),
        scaffoldBackgroundColor: const Color(0xFFF9F9FB),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFFFFFF),
          foregroundColor: Color(0xFF09090B),
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
        ),
        cardTheme: const CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            side: BorderSide(color: Color(0xFFE4E4E7)),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1D4ED8),
            foregroundColor: Colors.white,
            elevation: 0,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFFFFFFFF),
          labelStyle: TextStyle(color: Color(0xFF71717A)),
          floatingLabelStyle: TextStyle(color: Color(0xFF1D4ED8)),
          hintStyle: TextStyle(color: Color(0xFFA1A1AA)),
          prefixIconColor: Color(0xFF71717A),
          suffixIconColor: Color(0xFF71717A),
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: Color(0xFFE4E4E7)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: Color(0xFFE4E4E7)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: Color(0xFF1D4ED8), width: 1.4),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: Color(0xFFEF4444)),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: Color(0xFFEF4444), width: 1.4),
          ),
        ),
      ),

      home: hasActiveSession ? const SosScreen() : const LoginScreen(),
    );
  }
}
