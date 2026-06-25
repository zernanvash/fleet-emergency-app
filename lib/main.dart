import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/sos_screen.dart';
import 'services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Check if session token exists on startup to skip login
  final hasActiveSession = await ApiService().hasSession();

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
      
      // VOS ENTERPRISE LIGHT OPERATIONAL THEMING
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF1D4ED8),       // Primary VOS Blue
          secondary: Color(0xFF3B82F6),     // Supporting Blue
          background: Color(0xFFF9F9FB),    // Light background
          surface: Color(0xFFFFFFFF),       // White cards
          error: Color(0xFFEF4444),         // Destructive Red
        ),
        scaffoldBackgroundColor: const Color(0xFFF9F9FB),
        inputDecorationTheme: const InputDecorationTheme(
          labelStyle: TextStyle(color: Color(0xFF71717A)),
          border: UnderlineInputBorder(
            borderSide: BorderSide(color: Color(0xFFE4E4E7)),
          ),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Color(0xFFE4E4E7)),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF1D4ED8)),
          ),
        ),
      ),
      
      home: hasActiveSession ? const SosScreen() : const LoginScreen(),
    );
  }
}
