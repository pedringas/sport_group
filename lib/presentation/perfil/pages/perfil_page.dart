import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/sg_widgets.dart';
import '../../../data/models/enums.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/grupo_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Perfil page
// ─────────────────────────────────────────────────────────────────────────────

class PerfilPage extends ConsumerWidget {
  final bool showBackButton;
  const PerfilPage({super.key, this.showBackButton = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final gruposAsync = ref.watch(userGruposProvider);
    final uid = ref.watch(authStateProvider).valueOrNull?.uid ?? '';
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      appBar: isDesktop ? null : AppBar(
        leading: showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => context.pop(),
              )
            : null,
        automaticallyImplyLeading: showBackButton,
        title: const Text('Mi perfil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Editar perfil',
            onPressed: () => context.push('/profile/edit'),
          ),
        ],
      ),
      body: userAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (user) {
          if (user == null) {
            return const Center(child: Text('No autenticado'));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 60),
            children: [
              // ── Hero card ──────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    SGAvatar(
                      name: user.nombreCompleto,
                      imageUrl: user.avatarUrl,
                      size: 72,
                      background: Colors.white24,
                      foreground: Colors.white,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.nombreCompleto,
                            style: GoogleFonts.bricolageGrotesque(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 20,
                              letterSpacing: -0.3,
                            ),
                          ),
                          if (user.alias != null && user.alias!.isNotEmpty)
                            Text(
                              '@${user.alias}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          if (user.telefono.isNotEmpty)
                            Text(
                              user.telefono,
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Mis grupos ─────────────────────────────────────────────────
              const SGEyebrow('Mis roles en grupos'),
              const SizedBox(height: 8),
              gruposAsync.maybeWhen(
                data: (grupos) {
                  if (grupos.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'No pertenecés a ningún grupo todavía',
                              style: TextStyle(
                                  fontSize: 13, color: AppTheme.textMuted),
                            ),
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: () => context.push('/search'),
                              icon: const Icon(Icons.search_rounded, size: 16),
                              label: const Text('Buscar grupos'),
                              style: TextButton.styleFrom(
                                  foregroundColor: AppTheme.primary),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < grupos.length; i++) ...[
                          _MyGroupTile(
                            grupoId: grupos[i].id,
                            nombre: grupos[i].nombre,
                            onTap: () =>
                                context.push('/group/${grupos[i].id}'),
                          ),
                          if (i < grupos.length - 1)
                            const Divider(
                                height: 1, indent: 56, endIndent: 12),
                        ],
                      ],
                    ),
                  );
                },
                orElse: () => const SizedBox(
                  height: 64,
                  child: Center(
                      child: CircularProgressIndicator(
                          color: AppTheme.primary)),
                ),
              ),

              const SizedBox(height: 20),

              // ── Preferencias ───────────────────────────────────────────────
              const SGEyebrow('Cuenta y preferencias'),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(children: [
                  _SettingRow(
                    icon: Icons.notifications_outlined,
                    label: 'Notificaciones',
                    sub: 'Push, email, WhatsApp',
                    onTap: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => _NotificacionesPrefsSheet(uid: uid),
                    ),
                  ),
                  const Divider(height: 1, indent: 56, endIndent: 12),
                  _SettingRow(
                    icon: Icons.account_balance_outlined,
                    label: 'Datos para transferencias',
                    sub: 'CBU y alias',
                    onTap: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => _DatosBancariosSheet(uid: uid),
                    ),
                  ),
                  const Divider(height: 1, indent: 56, endIndent: 12),
                  _SettingRow(
                    icon: Icons.security_outlined,
                    label: 'Privacidad y seguridad',
                    onTap: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => _PrivacidadSheet(uid: uid),
                    ),
                  ),
                  const Divider(height: 1, indent: 56, endIndent: 12),
                  _SettingRow(
                    icon: Icons.help_outline,
                    label: 'Ayuda y soporte',
                    onTap: () => context.push('/faq'),
                  ),
                ]),
              ),

              const SizedBox(height: 24),

              // ── Cerrar sesión ──────────────────────────────────────────────
              Center(
                child: TextButton.icon(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Cerrar sesión'),
                        content: const Text('¿Cerrás sesión en este dispositivo?'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancelar')),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: TextButton.styleFrom(
                                foregroundColor: AppTheme.danger),
                            child: const Text('Cerrar sesión'),
                          ),
                        ],
                      ),
                    );
                    if (confirm != true || !context.mounted) return;
                    await ref.read(authFlowProvider.notifier).signOut();
                    if (context.mounted) context.go('/login');
                  },
                  icon: const Icon(Icons.logout_rounded,
                      size: 18, color: AppTheme.danger),
                  label: const Text(
                    'Cerrar sesión',
                    style: TextStyle(
                      color: AppTheme.danger,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

}

// ─────────────────────────────────────────────────────────────────────────────
// My group tile — shows real role
// ─────────────────────────────────────────────────────────────────────────────

class _MyGroupTile extends ConsumerWidget {
  final String grupoId;
  final String nombre;
  final VoidCallback onTap;
  const _MyGroupTile({
    required this.grupoId,
    required this.nombre,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final miembroAsync = ref.watch(miembroActualProvider(grupoId));
    final rol = miembroAsync.valueOrNull?.rol ?? RolMiembro.miembro;

    final (icon, tone, label) = switch (rol) {
      RolMiembro.administrador =>
        (Icons.shield_outlined, SGChipTone.primary, 'Admin'),
      RolMiembro.moderador =>
        (Icons.shield_outlined, SGChipTone.neutral, 'Moderador'),
      RolMiembro.tesorero =>
        (Icons.account_balance_outlined, SGChipTone.good, 'Tesorero'),
      RolMiembro.delegado =>
        (Icons.assignment_outlined, SGChipTone.accent, 'Delegado'),
      RolMiembro.miembro =>
        (Icons.person_outline_rounded, SGChipTone.neutral, 'Miembro'),
    };

    return ListTile(
      onTap: onTap,
      leading: SGAvatar(name: nombre, size: 36),
      title: Text(nombre,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: SGChip(icon: icon, label: label, tone: tone),
      ),
      trailing: const Icon(Icons.chevron_right_rounded,
          color: AppTheme.textMuted),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Setting row
// ─────────────────────────────────────────────────────────────────────────────

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sub;
  final VoidCallback onTap;
  const _SettingRow({
    required this.icon,
    required this.label,
    this.sub,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppTheme.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: AppTheme.textMuted),
      ),
      title: Text(label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: sub != null
          ? Text(sub!,
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted))
          : null,
      trailing: const Icon(Icons.chevron_right_rounded,
          color: AppTheme.textMuted),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notificaciones preferences sheet
// ─────────────────────────────────────────────────────────────────────────────

class _NotificacionesPrefsSheet extends StatefulWidget {
  final String uid;
  const _NotificacionesPrefsSheet({required this.uid});

  @override
  State<_NotificacionesPrefsSheet> createState() =>
      _NotificacionesPrefsSheetState();
}

class _NotificacionesPrefsSheetState
    extends State<_NotificacionesPrefsSheet> {
  bool _push = true;
  bool _email = true;
  bool _whatsapp = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(widget.uid)
          .get();
      if (doc.exists) {
        final prefs = doc.data()?['preferenciasNotificaciones']
                as Map<String, dynamic>? ??
            {};
        if (mounted) {
          setState(() {
            _push = prefs['push'] as bool? ?? true;
            _email = prefs['email'] as bool? ?? true;
            _whatsapp = prefs['whatsapp'] as bool? ?? false;
          });
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    try {
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(widget.uid)
          .update({
        'preferenciasNotificaciones': {
          'push': _push,
          'email': _email,
          'whatsapp': _whatsapp,
        }
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 8, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SheetHandle(),
          Text(
            'Notificaciones',
            style: GoogleFonts.bricolageGrotesque(
                fontWeight: FontWeight.w700, fontSize: 20),
          ),
          const SizedBox(height: 4),
          const Text(
            'Elegí cómo querés recibir alertas y novedades.',
            style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 20),
          if (_loading)
            const Center(
                child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: AppTheme.primary),
            ))
          else ...[
            _ToggleRow(
              icon: Icons.notifications_outlined,
              label: 'Push',
              sub: 'Notificaciones en el dispositivo',
              value: _push,
              onChanged: (v) {
                setState(() => _push = v);
                _save();
              },
            ),
            const _Divider(),
            _ToggleRow(
              icon: Icons.email_outlined,
              label: 'Email',
              sub: 'Resúmenes y alertas importantes',
              value: _email,
              onChanged: (v) {
                setState(() => _email = v);
                _save();
              },
            ),
            const _Divider(),
            _ToggleRow(
              icon: Icons.chat_bubble_outline_rounded,
              label: 'WhatsApp',
              sub: 'Mensajes de recordatorio',
              value: _whatsapp,
              onChanged: (v) {
                setState(() => _whatsapp = v);
                _save();
              },
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Datos bancarios sheet
// ─────────────────────────────────────────────────────────────────────────────

class _DatosBancariosSheet extends StatefulWidget {
  final String uid;
  const _DatosBancariosSheet({required this.uid});

  @override
  State<_DatosBancariosSheet> createState() => _DatosBancariosSheetState();
}

class _DatosBancariosSheetState extends State<_DatosBancariosSheet> {
  final _cbuCtrl = TextEditingController();
  final _aliasCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _cbuCtrl.dispose();
    _aliasCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(widget.uid)
          .get();
      if (doc.exists) {
        final datos =
            doc.data()?['datosBancarios'] as Map<String, dynamic>? ?? {};
        _cbuCtrl.text = datos['cbu'] as String? ?? '';
        _aliasCtrl.text = datos['alias'] as String? ?? '';
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    final cbu = _cbuCtrl.text.trim();
    final alias = _aliasCtrl.text.trim();
    if (cbu.isNotEmpty && (cbu.length != 22 || !RegExp(r'^\d+$').hasMatch(cbu))) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('El CBU debe tener exactamente 22 dígitos'),
        backgroundColor: AppTheme.danger,
      ));
      return;
    }
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(widget.uid)
          .update({'datosBancarios': {'cbu': cbu, 'alias': alias}});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Datos guardados ✓'),
          backgroundColor: AppTheme.good,
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppTheme.danger,
        ));
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 8, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SheetHandle(),
          Text(
            'Datos para transferencias',
            style: GoogleFonts.bricolageGrotesque(
                fontWeight: FontWeight.w700, fontSize: 20),
          ),
          const SizedBox(height: 4),
          const Text(
            'Guardá tu CBU o alias para que otros miembros puedan transferirte.',
            style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 20),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: AppTheme.primary),
              ),
            )
          else ...[
            TextField(
              controller: _cbuCtrl,
              keyboardType: TextInputType.number,
              maxLength: 22,
              decoration: const InputDecoration(
                labelText: 'CBU',
                hintText: '22 dígitos numéricos',
                prefixIcon: Icon(Icons.account_balance_outlined),
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _aliasCtrl,
              keyboardType: TextInputType.text,
              decoration: const InputDecoration(
                labelText: 'Alias',
                hintText: 'ej: pedro.garcia.mp',
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Guardar datos'),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Privacidad sheet
// ─────────────────────────────────────────────────────────────────────────────

class _PrivacidadSheet extends ConsumerStatefulWidget {
  final String uid;
  const _PrivacidadSheet({required this.uid});

  @override
  ConsumerState<_PrivacidadSheet> createState() => _PrivacidadSheetState();
}

class _PrivacidadSheetState extends ConsumerState<_PrivacidadSheet> {
  bool _perfilPublico = true;
  bool _loading = true;
  bool _sendingReset = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(widget.uid)
          .get();
      if (doc.exists) {
        final prefs = doc.data()?['preferenciasPrivacidad']
                as Map<String, dynamic>? ??
            {};
        if (mounted) {
          setState(() =>
              _perfilPublico = prefs['perfilPublico'] as bool? ?? true);
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _savePerfilPublico(bool value) async {
    setState(() => _perfilPublico = value);
    try {
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(widget.uid)
          .update({'preferenciasPrivacidad': {'perfilPublico': value}});
    } catch (_) {}
  }

  Future<void> _sendPasswordReset() async {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Tu cuenta no tiene email vinculado'),
        backgroundColor: AppTheme.danger,
      ));
      return;
    }
    setState(() => _sendingReset = true);
    try {
      await ref.read(authRepositoryProvider).sendPasswordReset(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Email enviado a $email ✓'),
          backgroundColor: AppTheme.good,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppTheme.danger,
        ));
      }
    }
    if (mounted) setState(() => _sendingReset = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SheetHandle(),
          Text(
            'Privacidad y seguridad',
            style: GoogleFonts.bricolageGrotesque(
                fontWeight: FontWeight.w700, fontSize: 20),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(
                child: CircularProgressIndicator(color: AppTheme.primary))
          else ...[
            // Profile visibility toggle
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border),
              ),
              child: SwitchListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                title: const Text('Perfil visible para miembros',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text(
                  'Otros miembros del grupo pueden ver tu información',
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
                value: _perfilPublico,
                activeThumbColor: AppTheme.primary,
                onChanged: _savePerfilPublico,
              ),
            ),
            const SizedBox(height: 10),
            // Change password
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border),
              ),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.lock_reset_rounded,
                      size: 18, color: AppTheme.textMuted),
                ),
                title: const Text('Cambiar contraseña',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text(
                  'Recibís un email con el enlace de cambio',
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
                trailing: _sendingReset
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppTheme.primary))
                    : const Icon(Icons.chevron_right_rounded,
                        color: AppTheme.textMuted),
                onTap: _sendingReset ? null : _sendPasswordReset,
              ),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Apariencia sheet
// ─────────────────────────────────────────────────────────────────────────────


// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppTheme.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Divider(height: 1, color: AppTheme.border),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sub;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.label,
    this.sub,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppTheme.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: AppTheme.textMuted),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14)),
            if (sub != null)
              Text(sub!,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textMuted)),
          ],
        ),
      ),
      Switch(value: value, onChanged: onChanged, activeColor: AppTheme.primary),
    ]);
  }
}
