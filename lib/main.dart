import 'package:flutter/material';
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
      
      // SLEEK PREMIUM DARK-RED EMERGENCY THEMING
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: Colors.red[500]!,
          secondary: Colors.redAccent,
          background: Colors.grey[950]!,
          surface: Colors.grey[900]!,
          error: Colors.red[700]!,
        ),
        scaffoldBackgroundColor: Colors.grey[950],
        inputDecorationTheme: InputDecorationTheme(
          labelStyle: const TextStyle(color: Colors.grey),
          border: UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.grey[800]!),
          ),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.grey[800]!),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.red[500]!),
          ),
        ),
      ),
      
      home: hasActiveSession ? const SosScreen() : const LoginScreen(),
    );
  }
}
