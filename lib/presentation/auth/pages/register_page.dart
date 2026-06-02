import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/auth_provider.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  final _nombreCtrl = TextEditingController();
  final _apellidoCtrl = TextEditingController();

  // Email fields
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _emailFormKey = GlobalKey<FormState>();
  bool _obscurePass = true;

  // Phone fields
  final _phoneCtrl = TextEditingController();
  final _phoneFormKey = GlobalKey<FormState>();

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: kIsWeb ? 1 : 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _registerEmail() async {
    if (!_emailFormKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(authFlowProvider.notifier).signUpWithEmail(
            email: _emailCtrl.text.trim(),
            password: _passCtrl.text,
            nombre: _nombreCtrl.text.trim(),
            apellido: _apellidoCtrl.text.trim(),
          );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _registerPhone() async {
    if (!_phoneFormKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final phone = '+54${_phoneCtrl.text.trim()}';
    await ref.read(authFlowProvider.notifier).sendOtp(phone);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authFlowProvider, (_, next) {
      if (next is AuthOtpSent) {
        final redirectTo =
            GoRouterState.of(context).uri.queryParameters['redirect'];
        context.push('/otp', extra: {
          'verificationId': next.verificationId,
          'phone': '+54${_phoneCtrl.text.trim()}',
          'nombre': _nombreCtrl.text.trim(),
          'apellido': _apellidoCtrl.text.trim(),
          if (redirectTo != null) 'redirect': redirectTo,
        });
      }
      if (next is AuthError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(next.message), backgroundColor: AppTheme.danger),
        );
        ref.read(authFlowProvider.notifier).reset();
        setState(() => _loading = false);
      }
      if (next is AuthDone) {
        final redirectTo =
            GoRouterState.of(context).uri.queryParameters['redirect'];
        context.go(redirectTo ?? '/home');
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Name fields (shared between tabs) ──────────────────────
                Text('Tus datos',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _nombreCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration:
                          const InputDecoration(labelText: 'Nombre'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _apellidoCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration:
                          const InputDecoration(labelText: 'Apellido'),
                    ),
                  ),
                ]),
                const SizedBox(height: 24),

                // ── Tabs ──────────────────────────────────────────────────
                Text('Método de acceso',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),

                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tabCtrl,
                    indicator: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                            color:
                                Colors.black.withValues(alpha: 0.07),
                            blurRadius: 4,
                            offset: const Offset(0, 2))
                      ],
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: AppTheme.primary,
                    unselectedLabelColor: AppTheme.textMuted,
                    labelStyle: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: 'Email'),
                      if (!kIsWeb) Tab(text: 'Teléfono'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  height: kIsWeb ? 180 : 200,
                  child: TabBarView(
                    controller: _tabCtrl,
                    children: [
                      // Email tab
                      Form(
                        key: _emailFormKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _emailCtrl,
                              keyboardType:
                                  TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                  labelText: 'Email',
                                  prefixIcon:
                                      Icon(Icons.email_outlined)),
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Ingresá tu email';
                                }
                                if (!v.contains('@')) {
                                  return 'Email inválido';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _passCtrl,
                              obscureText: _obscurePass,
                              decoration: InputDecoration(
                                labelText: 'Contraseña (mín. 6 caracteres)',
                                prefixIcon:
                                    const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscurePass
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined),
                                  onPressed: () => setState(() =>
                                      _obscurePass = !_obscurePass),
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Ingresá una contraseña';
                                }
                                if (v.length < 6) {
                                  return 'Mínimo 6 caracteres';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed:
                                  _loading ? null : _registerEmail,
                              style: FilledButton.styleFrom(
                                  minimumSize:
                                      const Size(double.infinity, 52)),
                              child: _loading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white))
                                  : const Text('Crear cuenta'),
                            ),
                          ],
                        ),
                      ),

                      // Phone tab (mobile only)
                      if (!kIsWeb)
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
                                  prefixIcon:
                                      Icon(Icons.phone_outlined),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Ingresá tu teléfono';
                                  }
                                  if (v
                                          .replaceAll(
                                              RegExp(r'\D'), '')
                                          .length <
                                      10) {
                                    return 'Número inválido';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                onPressed:
                                    _loading ? null : _registerPhone,
                                icon: _loading
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child:
                                            CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white))
                                    : const Icon(Icons.sms_outlined),
                                label: const Text('Verificar con SMS'),
                                style: FilledButton.styleFrom(
                                    minimumSize: const Size(
                                        double.infinity, 52)),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                // ── Google ────────────────────────────────────────────────
                const Row(children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child:
                        Text('o', style: TextStyle(color: AppTheme.textMuted)),
                  ),
                  Expanded(child: Divider()),
                ]),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: _loading
                      ? null
                      : () => ref
                          .read(authFlowProvider.notifier)
                          .signInWithGoogle(),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFD1D1E0)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _GoogleIcon(),
                      SizedBox(width: 12),
                      Text('Registrarme con Google',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A2E))),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: TextButton(
                    onPressed: () => context.pop(),
                    child: const Text('¿Ya tenés cuenta? Iniciá sesión'),
                  ),
                ),
              ],
            ),
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
      width: 22,
      height: 22,
      child: Stack(children: [
        Icon(Icons.circle, color: Colors.white, size: 22),
        Icon(Icons.g_mobiledata_rounded, color: Colors.red, size: 22),
      ]),
    );
  }
}
