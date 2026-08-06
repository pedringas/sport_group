import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/auth_provider.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _resolve();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _resolve() async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    final user = ref.read(authStateProvider).valueOrNull;
    if (user != null) {
      context.go('/home');
      return;
    }

    bool seen = true; // default: ir a login si no se puede leer storage
    try {
      final prefs = await SharedPreferences.getInstance();
      seen = prefs.getBool('onboarding_seen') ?? false;
    } catch (_) {
      // iOS Safari (modo privado) puede bloquear localStorage
    }

    if (!mounted) return;
    context.go(seen ? '/login' : '/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) => Transform.scale(
                scale: 1.0 + _pulse.value * 0.04,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withValues(
                            alpha: 0.35 + _pulse.value * 0.15),
                        blurRadius: 24 + _pulse.value * 8,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      'T',
                      style: GoogleFonts.bricolageGrotesque(
                        fontWeight: FontWeight.w800,
                        fontSize: 34,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Tacheros',
              style: GoogleFonts.bricolageGrotesque(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                color: AppTheme.text,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
