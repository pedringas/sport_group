import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/grupo_provider.dart';
import '../../../providers/auth_provider.dart';

/// Full-screen danger dialog shown before leaving a group.
/// Usage:
///   await showAbandonarDialog(context, grupoId: '...', grupoNombre: '...');
Future<void> showAbandonarDialog(
  BuildContext context, {
  required String grupoId,
  required String grupoNombre,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => AbandonarDialog(
      grupoId: grupoId,
      grupoNombre: grupoNombre,
    ),
  );
}

class AbandonarDialog extends ConsumerStatefulWidget {
  final String grupoId;
  final String grupoNombre;

  const AbandonarDialog({
    super.key,
    required this.grupoId,
    required this.grupoNombre,
  });

  @override
  ConsumerState<AbandonarDialog> createState() => _AbandonarDialogState();
}

class _AbandonarDialogState extends ConsumerState<AbandonarDialog> {
  bool _loading = false;

  Future<void> _abandonar() async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    setState(() => _loading = true);
    try {
      await ref
          .read(grupoRepositoryProvider)
          .leaveGrupo(widget.grupoId, uid);
      if (mounted) {
        Navigator.of(context).pop(); // close dialog
        context.go('/home'); // go home
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo abandonar: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 60,
              offset: const Offset(0, 24),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Danger icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.danger.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.logout_rounded,
                size: 32,
                color: AppTheme.danger,
              ),
            ),

            const SizedBox(height: 16),

            // ── Title
            Text(
              '¿Abandonar el grupo?',
              style: GoogleFonts.bricolageGrotesque(
                fontWeight: FontWeight.w700,
                fontSize: 22,
                letterSpacing: -0.3,
                color: AppTheme.text,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 10),

            // ── Description
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textMuted,
                  height: 1.5,
                ),
                children: [
                  const TextSpan(text: 'Vas a perder acceso a '),
                  TextSpan(
                    text: widget.grupoNombre,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, color: AppTheme.text),
                  ),
                  const TextSpan(
                    text:
                        '.\nTus aportes y comprobantes quedan registrados, pero ya no vas a poder ver el feed, cuotas pendientes ni eventos del grupo.',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // ── Warning list
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _WarnRow(
                      text: 'Vas a perder acceso al chat y noticias'),
                  SizedBox(height: 4),
                  _WarnRow(
                      text:
                          'No vas a recibir más notificaciones del grupo'),
                  SizedBox(height: 4),
                  _WarnRow(
                      text:
                          'Si querés volver, te van a tener que aprobar de nuevo'),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // ── Actions
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _abandonar,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.logout_rounded, size: 18),
                label: const Text(
                  'Sí, abandonar',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.danger,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Mejor no',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textMuted,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Warning row ────────────────────────────────────────────────────────────────

class _WarnRow extends StatelessWidget {
  final String text;
  const _WarnRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.warning_rounded,
            size: 14, color: AppTheme.danger),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.danger.withValues(alpha: 0.85),
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
