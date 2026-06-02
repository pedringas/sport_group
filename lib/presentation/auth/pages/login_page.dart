import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/sg_widgets.dart';
import '../../../providers/auth_provider.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage>
    with SingleTickerProviderStateMixin {
  // Tab 0 = Email, Tab 1 = Teléfono (mobile only)
  int _tabIndex = 0;

  // Email
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _emailFormKey = GlobalKey<FormState>();
  bool _obscurePass = true;

  // Phone
  final _phoneCtrl = TextEditingController();
  final _phoneFormKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _loginEmail() async {
    if (!_emailFormKey.currentState!.validate()) return;
    await ref
        .read(authFlowProvider.notifier)
        .signInWithEmail(_emailCtrl.text.trim(), _passCtrl.text);
  }

  Future<void> _sendOtp() async {
    if (!_phoneFormKey.currentState!.validate()) return;
    final phone = '+54${_phoneCtrl.text.trim()}';
    await ref.read(authFlowProvider.notifier).sendOtp(phone);
  }

  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ingresá tu email primero')));
      return;
    }
    await ref.read(authFlowProvider.notifier).sendPasswordReset(email);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Email de recuperación enviado a $email')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authFlowProvider);

    ref.listen(authFlowProvider, (_, next) {
      if (next is AuthOtpSent) {
        // Propagate the ?redirect param through the OTP flow
        final redirectTo =
            GoRouterState.of(context).uri.queryParameters['redirect'];
        context.push('/otp', extra: {
          'verificationId': next.verificationId,
          'phone': '+54${_phoneCtrl.text.trim()}',
          if (redirectTo != null) 'redirect': redirectTo,
        });
      }
      if (next is AuthError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.message),
            backgroundColor: AppTheme.danger,
          ),
        );
        ref.read(authFlowProvider.notifier).reset();
      }
      if (next is AuthDone) {
        // Honour ?redirect param (e.g. coming from a join link)
        final redirectTo =
            GoRouterState.of(context).uri.queryParameters['redirect'];
        context.go(redirectTo ?? '/home');
      }
    });

    final isLoading =
        authState is AuthSendingOtp || authState is AuthVerifying;

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: SafeArea(
        child: Stack(
          children: [
            // Decorative blobs
            Positioned(
              top: 100, right: -60,
              child: Container(
                width: 220, height: 220,
                decoration: BoxDecoration(
                  color: AppTheme.primarySoft.withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              top: 60, left: -40,
              child: Container(
                width: 120, height: 120,
                decoration: BoxDecoration(
                  color: AppTheme.accentSoft.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                ),
              ),
            ),

            // Content
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // â”€â”€ Brand mark
                    Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: 0.35),
                            blurRadius: 32,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'SG',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 30,
                              letterSpacing: -1,
                            ),
                      ),
                    ),

                    const SizedBox(height: 28),
                    Text(
                      'Bienvenido\nde nuevo.',
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                            fontSize: 34,
                            height: 1.05,
                          ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Tu comunidad te está esperando.',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // â”€â”€ Segmented tabs
                    if (!kIsWeb)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _segTab('Email', 0),
                            _segTab('Teléfono', 1),
                          ],
                        ),
                      ),
                    const SizedBox(height: 20),

                    // â”€â”€ Form
                    if (_tabIndex == 0 || kIsWeb) ...[
                      Form(
                        key: _emailFormKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.alternate_email_rounded),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Ingresá tu email';
                                }
                                if (!v.contains('@')) return 'Email inválido';
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _passCtrl,
                              obscureText: _obscurePass,
                              decoration: InputDecoration(
                                labelText: 'Contraseña',
                                prefixIcon: const Icon(Icons.lock_outline_rounded),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscurePass
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined),
                                  onPressed: () =>
                                      setState(() => _obscurePass = !_obscurePass),
                                ),
                              ),
                              validator: (v) => v == null || v.isEmpty
                                  ? 'Ingresá tu contraseña'
                                  : null,
                              onFieldSubmitted: (_) =>
                                  isLoading ? null : _loginEmail(),
                            ),
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => context.push('/forgot-password'),
                                style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact),
                                child: const Text('Recuperar contraseña',
                                    style: TextStyle(fontSize: 12)),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: SGPillButton(
                                label: isLoading ? 'Ingresando...' : 'Entrar a mi comunidad',
                                icon: isLoading ? null : Icons.arrow_forward_rounded,
                                expand: true,
                                size: SGSize.lg,
                                onPressed: isLoading ? null : _loginEmail,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else
                      Form(
                        key: _phoneFormKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _phoneCtrl,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Número de teléfono',
                                prefixText: '+54 ',
                                hintText: '11 1234-5678',
                                prefixIcon: Icon(Icons.phone_outlined),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Ingresá tu teléfono';
                                }
                                if (v.replaceAll(RegExp(r'\D'), '').length < 10) {
                                  return 'Número inválido';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: SGPillButton(
                                label: isLoading ? 'Enviando...' : 'Enviar código SMS',
                                icon: isLoading ? null : Icons.sms_outlined,
                                expand: true,
                                size: SGSize.lg,
                                onPressed: isLoading ? null : _sendOtp,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 24),

                    Row(children: [
                      Expanded(child: Container(height: 1, color: AppTheme.border)),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('O CONTINUAR CON',
                            style: TextStyle(
                              color: AppTheme.textMuted, fontSize: 11,
                              letterSpacing: 1, fontWeight: FontWeight.w700,
                            )),
                      ),
                      Expanded(child: Container(height: 1, color: AppTheme.border)),
                    ]),
                    const SizedBox(height: 16),

                    // â”€â”€ Google
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: isLoading
                            ? null
                            : () => ref
                                .read(authFlowProvider.notifier)
                                .signInWithGoogle(),
                        icon: const _GoogleIcon(),
                        label: const Text('Continuar con Google'),
                      ),
                    ),

                    const SizedBox(height: 24),
                    Center(
                      child: TextButton(
                        onPressed: () => context.push('/register'),
                        child: const Text('¿Sos nuevo? Crear cuenta'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }

  Widget _segTab(String label, int idx) {
    final selected = _tabIndex == idx;
    return GestureDetector(
      onTap: () => setState(() => _tabIndex = idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppTheme.textMuted,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 20, height: 20,
      child: Icon(Icons.g_translate, size: 18, color: AppTheme.primary),
    );
  }
}
