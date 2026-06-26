import 'package:flutter/material.dart';
import '../services/directus_auth_service.dart';
import 'sos_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _pageController = PageController();

  late final AnimationController _introController;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  bool _isLoading = false;
  bool _obscurePassword = true;
  int _activePage = 0;

  final List<_ReadinessPanel> _panels = const [
    _ReadinessPanel(
      icon: Icons.verified_user_rounded,
      eyebrow: 'SECURE ACCESS',
      title: 'Sign in with your VOS driver credentials.',
      body: 'Your session opens the SOS console and links dispatch context.',
    ),
    _ReadinessPanel(
      icon: Icons.route_rounded,
      eyebrow: 'TRIP CONTEXT',
      title: 'Active vehicle and route are checked after login.',
      body: 'The console resolves your assigned trip before any alert is sent.',
    ),
    _ReadinessPanel(
      icon: Icons.emergency_share_rounded,
      eyebrow: 'CONTROLLED SOS',
      title: 'Emergency alerts require confirmation.',
      body: 'Location, contact, and incident metadata are sent to dispatch.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..forward();
    _fadeIn = CurvedAnimation(
      parent: _introController,
      curve: Curves.easeOutCubic,
    );
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _introController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _pageController.dispose();
    _introController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = await DirectusAuthService().login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (userId != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const SosScreen()),
        );
      } else if (mounted) {
        _showError('Invalid email or password. Please try again.');
      }
    } on DirectusAuthException catch (e) {
      if (mounted) {
        _showError(e.message);
      }
    } catch (e) {
      if (mounted) {
        _showError('Connection error: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFB91C1C),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _nextPanel() {
    final nextPage = (_activePage + 1) % _panels.length;
    _pageController.animateToPage(
      nextPage,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Driver email is required.';
    if (!email.contains('@') || !email.contains('.')) {
      return 'Enter a valid VOS email address.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if ((value ?? '').isEmpty) return 'Password is required.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FB),
      body: SafeArea(
        child: AutofillGroup(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final contentHeight = constraints.maxHeight > 40
                  ? constraints.maxHeight - 40
                  : constraints.maxHeight;

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: contentHeight),
                  child: IntrinsicHeight(
                    child: FadeTransition(
                      opacity: _fadeIn,
                      child: SlideTransition(
                        position: _slideUp,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _Header(theme: theme),
                            Expanded(
                              child: Center(
                                child: _LoginStage(
                                  panels: _panels,
                                  activePage: _activePage,
                                  pageController: _pageController,
                                  formKey: _formKey,
                                  emailController: _emailController,
                                  passwordController: _passwordController,
                                  obscurePassword: _obscurePassword,
                                  isLoading: _isLoading,
                                  onPanelChanged: (index) {
                                    setState(() => _activePage = index);
                                  },
                                  onNextPanel: _nextPanel,
                                  onTogglePassword: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                  onSubmit: _handleLogin,
                                  validateEmail: _validateEmail,
                                  validatePassword: _validatePassword,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            const _TrustFooter(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LoginStage extends StatelessWidget {
  final List<_ReadinessPanel> panels;
  final int activePage;
  final PageController pageController;
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final bool isLoading;
  final ValueChanged<int> onPanelChanged;
  final VoidCallback onNextPanel;
  final VoidCallback onTogglePassword;
  final VoidCallback onSubmit;
  final FormFieldValidator<String> validateEmail;
  final FormFieldValidator<String> validatePassword;

  const _LoginStage({
    required this.panels,
    required this.activePage,
    required this.pageController,
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.isLoading,
    required this.onPanelChanged,
    required this.onNextPanel,
    required this.onTogglePassword,
    required this.onSubmit,
    required this.validateEmail,
    required this.validatePassword,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ReadinessCarousel(
              panels: panels,
              activePage: activePage,
              pageController: pageController,
              onChanged: onPanelChanged,
              onNext: onNextPanel,
            ),
            const SizedBox(height: 16),
            _LoginCard(
              formKey: formKey,
              emailController: emailController,
              passwordController: passwordController,
              obscurePassword: obscurePassword,
              isLoading: isLoading,
              onTogglePassword: onTogglePassword,
              onSubmit: onSubmit,
              validateEmail: validateEmail,
              validatePassword: validatePassword,
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final ThemeData theme;

  const _Header({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE4E4E7)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFF1D4ED8).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
              color: Color(0xFF1D4ED8),
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VOS FLEET SOS',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: const Color(0xFF09090B),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Driver emergency access console',
                  style: TextStyle(
                    color: Color(0xFF71717A),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFF86EFAC)),
            ),
            child: const Text(
              'ONLINE',
              style: TextStyle(
                color: Color(0xFF166534),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.9,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadinessCarousel extends StatelessWidget {
  final List<_ReadinessPanel> panels;
  final int activePage;
  final PageController pageController;
  final ValueChanged<int> onChanged;
  final VoidCallback onNext;

  const _ReadinessCarousel({
    required this.panels,
    required this.activePage,
    required this.pageController,
    required this.onChanged,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 126,
              child: PageView.builder(
                controller: pageController,
                itemCount: panels.length,
                onPageChanged: onChanged,
                itemBuilder: (context, index) {
                  final panel = panels[index];
                  return _PanelContent(panel: panel);
                },
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                ...List.generate(
                  panels.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(right: 6),
                    width: index == activePage ? 20 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: index == activePage
                          ? const Color(0xFF1D4ED8)
                          : const Color(0xFFE4E4E7),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: onNext,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: const Text('NEXT'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF1D4ED8),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PanelContent extends StatelessWidget {
  final _ReadinessPanel panel;

  const _PanelContent({required this.panel});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.86, end: 1),
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutBack,
          builder: (context, scale, child) {
            return Transform.scale(scale: scale, child: child);
          },
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF1D4ED8).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Icon(panel.icon, color: const Color(0xFF1D4ED8), size: 30),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                panel.eyebrow,
                style: const TextStyle(
                  color: Color(0xFF71717A),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                panel.title,
                style: const TextStyle(
                  color: Color(0xFF09090B),
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  height: 1.18,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                panel.body,
                style: const TextStyle(
                  color: Color(0xFF71717A),
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LoginCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final bool isLoading;
  final VoidCallback onTogglePassword;
  final VoidCallback onSubmit;
  final FormFieldValidator<String> validateEmail;
  final FormFieldValidator<String> validatePassword;

  const _LoginCard({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.isLoading,
    required this.onTogglePassword,
    required this.onSubmit,
    required this.validateEmail,
    required this.validatePassword,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(Icons.lock_outline_rounded,
                      color: Color(0xFF1D4ED8), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Corporate sign in',
                    style: TextStyle(
                      color: Color(0xFF09090B),
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Use the same credentials assigned for VOS operations.',
                style: TextStyle(color: Color(0xFF71717A), fontSize: 12),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: emailController,
                validator: validateEmail,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username],
                enabled: !isLoading,
                decoration: const InputDecoration(
                  labelText: 'Driver email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: passwordController,
                validator: validatePassword,
                obscureText: obscurePassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                enabled: !isLoading,
                onFieldSubmitted: (_) {
                  if (!isLoading) onSubmit();
                },
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    tooltip:
                        obscurePassword ? 'Show password' : 'Hide password',
                    onPressed: isLoading ? null : onTogglePassword,
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const _SessionNote(),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.center,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 240,
                    maxWidth: 280,
                  ),
                  child: ElevatedButton(
                    onPressed: isLoading ? null : onSubmit,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: isLoading
                          ? const SizedBox(
                              key: ValueKey('loading'),
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'CONTINUE TO SOS CONSOLE',
                              key: ValueKey('label'),
                              textAlign: TextAlign.center,
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionNote extends StatelessWidget {
  const _SessionNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E4E7)),
      ),
      child: const Row(
        children: [
          Icon(Icons.admin_panel_settings_outlined,
              color: Color(0xFF64748B), size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Session stays active on this device until logout.',
              style: TextStyle(
                color: Color(0xFF475569),
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustFooter extends StatelessWidget {
  const _TrustFooter();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.shield_outlined, size: 15, color: Color(0xFF71717A)),
        SizedBox(width: 6),
        Flexible(
          child: Text(
            'VOS credentials are verified before driver trip data loads.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF71717A), fontSize: 11),
          ),
        ),
      ],
    );
  }
}

class _ReadinessPanel {
  final IconData icon;
  final String eyebrow;
  final String title;
  final String body;

  const _ReadinessPanel({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.body,
  });
}
