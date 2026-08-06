import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/auth_provider.dart';
import 'ob_shared.dart';

class OBRegister extends ConsumerStatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onSuccess;
  const OBRegister({
    super.key,
    required this.onBack,
    required this.onSuccess,
  });

  @override
  ConsumerState<OBRegister> createState() => _OBRegisterState();
}

class _OBRegisterState extends ConsumerState<OBRegister> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      await ref.read(authFlowProvider.notifier).signUpWithEmail(
            email: _emailCtrl.text.trim(),
            password: _passCtrl.text,
            nombre: _nameCtrl.text.trim(),
            apellido: '',
          );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _google() async {
    setState(() => _loading = true);
    try {
      await ref.read(authFlowProvider.notifier).signInWithGoogle();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authFlowProvider, (_, next) {
      if (next is AuthDone) widget.onSuccess();
      if (next is AuthError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.message)),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                OBBreadcrumb(step: 2, onBack: widget.onBack),
                const SizedBox(height: 28),
                Text(
                  'Creá tu cuenta.',
                  style: GoogleFonts.bricolageGrotesque(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.txt(context),
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Empezá gratis. Sin tarjeta requerida.',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    color: AppTheme.txtMuted(context),
                  ),
                ),
                const SizedBox(height: 28),
                OBField(
                  label: 'Nombre',
                  hint: 'Tu nombre completo',
                  icon: Icons.person_outline_rounded,
                  controller: _nameCtrl,
                  textInputAction: TextInputAction.next,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Ingresá tu nombre' : null,
                ),
                const SizedBox(height: 14),
                OBField(
                  label: 'Email',
                  hint: 'tu@email.com',
                  icon: Icons.mail_outline_rounded,
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Ingresá tu email';
                    if (!v.contains('@')) return 'Email inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                OBField(
                  label: 'Contraseña',
                  hint: 'Mínimo 8 caracteres',
                  icon: Icons.lock_outline_rounded,
                  controller: _passCtrl,
                  obscureText: _obscurePass,
                  textInputAction: TextInputAction.done,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Ingresá una contraseña';
                    if (v.length < 8) return 'Mínimo 8 caracteres';
                    return null;
                  },
                  suffix: IconButton(
                    icon: Icon(
                      _obscurePass
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                      color: AppTheme.textMuted,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePass = !_obscurePass),
                  ),
                ),
                const SizedBox(height: 24),
                OBBtn(
                  'Crear cuenta',
                  onTap: _loading ? null : _register,
                  isLoading: _loading,
                ),
                const SizedBox(height: 24),
                Row(children: [
                  Expanded(child: Divider(color: AppTheme.brd(context))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'o',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.txtMuted(context),
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: AppTheme.brd(context))),
                ]),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(child: _SocialBtn(
                    label: 'Google',
                    icon: Icons.g_mobiledata_rounded,
                    onTap: _loading ? null : _google,
                  )),
                ]),
                const SizedBox(height: 24),
                Text(
                  'Al registrarte aceptás nuestros Términos de servicio\ny Política de privacidad.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: AppTheme.txtMuted(context),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SocialBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  const _SocialBtn({required this.label, required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: AppTheme.surf(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.brd(context)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 26, color: AppTheme.txt(context)),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.txt(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
