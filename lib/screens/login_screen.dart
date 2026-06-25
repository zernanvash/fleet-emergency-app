import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'sos_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _urlController = TextEditingController(text: ApiService().baseUrl);
  
  bool _isLoading = false;
  bool _showConfig = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill out all credentials.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Save server URL override if changed
      ApiService().setBaseUrl(_urlController.text.trim());

      // 2. Authenticate
      final success = await ApiService().login(email, password);

      if (success && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const SosScreen()),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Login failed. Please verify credentials.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Network error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FB),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // LOGO / BRANDING
                const Icon(
                  Icons.notifications_active_rounded,
                  size: 80,
                  color: Color(0xFF1D4ED8),
                ),
                const SizedBox(height: 16),
                Text(
                  'VOS FLEET SOS',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: const Color(0xFF09090B),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  'Driver Distress Companion App',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF71717A),
                  ),
                ),
                const SizedBox(height: 40),

                // LOGIN CARD
                Card(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFFE4E4E7)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                           controller: _emailController,
                           keyboardType: TextInputType.emailAddress,
                           style: const TextStyle(color: Colors.black87),
                           decoration: const InputDecoration(
                             labelText: 'Driver Email',
                             labelStyle: TextStyle(color: Color(0xFF71717A)),
                             prefixIcon: Icon(Icons.email, color: Color(0xFF71717A)),
                             enabledBorder: UnderlineInputBorder(
                               borderSide: BorderSide(color: Color(0xFFE4E4E7)),
                             ),
                             focusedBorder: UnderlineInputBorder(
                               borderSide: BorderSide(color: Color(0xFF1D4ED8)),
                             ),
                           ),
                         ),
                        const SizedBox(height: 16),
                        TextField(
                           controller: _passwordController,
                           obscureText: true,
                           style: const TextStyle(color: Colors.black87),
                           decoration: const InputDecoration(
                             labelText: 'Password',
                             labelStyle: TextStyle(color: Color(0xFF71717A)),
                             prefixIcon: Icon(Icons.lock, color: Color(0xFF71717A)),
                             enabledBorder: UnderlineInputBorder(
                               borderSide: BorderSide(color: Color(0xFFE4E4E7)),
                             ),
                             focusedBorder: UnderlineInputBorder(
                               borderSide: BorderSide(color: Color(0xFF1D4ED8)),
                             ),
                           ),
                         ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                           onPressed: _isLoading ? null : _handleLogin,
                           style: ElevatedButton.styleFrom(
                             backgroundColor: const Color(0xFF1D4ED8),
                             foregroundColor: Colors.white,
                             padding: const EdgeInsets.symmetric(vertical: 16),
                             shape: RoundedRectangleBorder(
                               borderRadius: BorderRadius.circular(8),
                             ),
                           ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'LOGIN',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // DEV SERVER GATEWAY ACCORDION
                TextButton.icon(
                   onPressed: () => setState(() => _showConfig = !_showConfig),
                   icon: Icon(
                     _showConfig ? Icons.expand_less : Icons.settings_ethernet,
                     color: const Color(0xFF71717A),
                     size: 16,
                   ),
                   label: const Text(
                     'Server Configuration',
                     style: TextStyle(color: Color(0xFF71717A), fontSize: 12),
                   ),
                 ),
                if (_showConfig) ...[
                   Card(
                     color: const Color(0xFFF4F4F5),
                     elevation: 0,
                     margin: const EdgeInsets.symmetric(horizontal: 12),
                     shape: RoundedRectangleBorder(
                       borderRadius: BorderRadius.circular(8),
                       side: const BorderSide(color: Color(0xFFE4E4E7)),
                     ),
                     child: Padding(
                       padding: const EdgeInsets.all(12.0),
                       child: TextField(
                         controller: _urlController,
                         style: const TextStyle(color: Colors.black87, fontSize: 12),
                         decoration: const InputDecoration(
                           labelText: 'API Gateway Endpoint',
                           labelStyle: TextStyle(color: Color(0xFF71717A), fontSize: 11),
                           isDense: true,
                           enabledBorder: UnderlineInputBorder(
                             borderSide: BorderSide(color: Color(0xFFE4E4E7)),
                           ),
                           focusedBorder: UnderlineInputBorder(
                             borderSide: BorderSide(color: Color(0xFF1D4ED8)),
                           ),
                         ),
                       ),
                     ),
                   ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
