import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/sg_widgets.dart';
import '../../../providers/auth_provider.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() =>
      _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _emailCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _sent = false;
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref
          .read(authFlowProvider.notifier)
          .sendPasswordReset(_emailCtrl.text.trim());
      if (mounted) setState(() { _sent = true; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: _sent ? _SuccessState(email: _emailCtrl.text.trim()) : _FormState(
              formKey: _formKey,
              emailCtrl: _emailCtrl,
              loading: _loading,
              onSend: _send,
            ),
          ),
        ),
      ),
    );
  }
}

class _FormState extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final bool loading;
  final VoidCallback onSend;

  const _FormState({
    required this.formKey,
    required this.emailCtrl,
    required this.loading,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button
          GestureDetector(
            onTap: () => context.canPop() ? context.pop() : context.go('/login'),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 16, color: AppTheme.text),
            ),
          ),

          const SizedBox(height: 28),

          Text(
            'Recuperar\ncontraseña.',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              fontSize: 34, height: 1.05,
            ),
          ),

          const SizedBox(height: 10),

          Text(
            'Ingresá tu email y te mandamos un link para resetear tu contraseña.',
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 15,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 32),

          TextFormField(
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => loading ? null : onSend(),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.alternate_email_rounded),
              labelText: 'Email',
              hintText: 'tucorreo@email.com',
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Ingresá tu email';
              if (!v.contains('@')) return 'Email inválido';
              return null;
            },
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: SGPillButton(
              label: loading ? 'Enviando...' : 'Enviar instrucciones',
              onPressed: loading ? null : onSend,
              icon: Icons.send_rounded,
            ),
          ),

          const SizedBox(height: 20),

          Center(
            child: TextButton(
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go('/login'),
              child: const Text('Volver al login',
                  style: TextStyle(fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessState extends StatelessWidget {
  final String email;
  const _SuccessState({required this.email});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            color: AppTheme.goodSoft,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.mark_email_read_outlined,
              size: 32, color: AppTheme.good),
        ),

        const SizedBox(height: 28),

        Text(
          'Revisá tu\nbandeja de entrada.',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            fontSize: 34, height: 1.05,
          ),
        ),

        const SizedBox(height: 12),

        RichText(
          text: TextSpan(
            style: TextStyle(
              color: AppTheme.textMuted, fontSize: 15, height: 1.5),
            children: [
              const TextSpan(text: 'Enviamos un link de recuperación a '),
              TextSpan(
                text: email,
                style: const TextStyle(
                  color: AppTheme.text, fontWeight: FontWeight.w600),
              ),
              const TextSpan(
                  text: '. Revisá también la carpeta de spam.'),
            ],
          ),
        ),

        const SizedBox(height: 36),

        SizedBox(
          width: double.infinity,
          child: SGPillButton(
            label: 'Volver al login',
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/login'),
          ),
        ),
      ],
    );
  }
}
