import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/usuario_model.dart';
import '../../../providers/auth_provider.dart';

class OtpPage extends ConsumerStatefulWidget {
  final Map<String, dynamic> extra;
  const OtpPage({super.key, required this.extra});

  @override
  ConsumerState<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends ConsumerState<OtpPage> {
  final _otpController = TextEditingController();
  bool _loading = false;

  String get _verificationId => widget.extra['verificationId'] as String;
  String get _phone => widget.extra['phone'] as String;
  String? get _nombre => widget.extra['nombre'] as String?;
  String? get _apellido => widget.extra['apellido'] as String?;
  String? get _redirect => widget.extra['redirect'] as String?;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _otpController.text.trim();
    if (code.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresá el código de 6 dígitos')),
      );
      return;
    }
    setState(() => _loading = true);
    await ref.read(authFlowProvider.notifier).verifyOtp(_verificationId, code);
  }

  Future<void> _afterVerification(String uid) async {
    final repo = ref.read(authRepositoryProvider);
    final exists = await repo.userExists(uid);
    if (!exists) {
      final now = DateTime.now();
      await repo.createUser(UsuarioModel(
        uid: uid,
        nombre: _nombre ?? '',
        apellido: _apellido ?? '',
        telefono: _phone,
        createdAt: now,
      ));
    }
    if (mounted) context.go(_redirect ?? '/home');
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authFlowProvider, (_, next) {
      if (next is AuthDone) {
        final user = ref.read(authRepositoryProvider).currentUser;
        if (user != null) {
          _afterVerification(user.uid);
        }
      }
      if (next is AuthError) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.message), backgroundColor: Colors.red),
        );
        ref.read(authFlowProvider.notifier).reset();
        setState(() => _loading = false);
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Verificar código')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text('Ingresá el código enviado a',
                  style: Theme.of(context).textTheme.bodyLarge),
              Text(_phone,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),
              TextFormField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
                decoration: const InputDecoration(
                  labelText: 'Código SMS',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loading ? null : _verify,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Verificar'),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('Reenviar código'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
