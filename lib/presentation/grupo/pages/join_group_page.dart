import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/nav_ext.dart';
import '../../../data/models/enums.dart';
import '../../../providers/grupo_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/sg_widgets.dart';

class JoinGroupPage extends ConsumerWidget {
  final String grupoId;
  const JoinGroupPage({super.key, required this.grupoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grupoAsync = ref.watch(grupoProvider(grupoId));
    final miembroAsync = ref.watch(miembroActualProvider(grupoId));
    final solicitudAsync = ref.watch(miSolicitudProvider(grupoId));
    final currentUid = ref.watch(authStateProvider).valueOrNull?.uid;

    return Scaffold(
      body: grupoAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const SGErrorState(message: 'Error al cargar el grupo'),
        data: (grupo) {
          if (grupo == null) {
            return const Center(child: Text('Grupo no encontrado'));
          }

          final yaEsMiembro =
              miembroAsync.valueOrNull?.estado == EstadoMiembro.activo;
          final solicitudPendiente = solicitudAsync.valueOrNull?.estado ==
              EstadoSolicitud.pendiente;
          final isPublico = grupo.tipo == TipoGrupo.publico;

          return CustomScrollView(
            slivers: [
              // ── Cover photo app bar ─────────────────────────────────────
              SliverAppBar(
                expandedHeight: grupo.portadaUrl != null ? 220 : 80,
                pinned: true,
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () =>
                      context.popOr('/home'),
                ),
                flexibleSpace: grupo.portadaUrl != null
                    ? FlexibleSpaceBar(
                        background: Stack(
                          fit: StackFit.expand,
                          children: [
                            CachedNetworkImage(imageUrl: grupo.portadaUrl!,
                                fit: BoxFit.cover),
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black26,
                                    Colors.transparent,
                                    Colors.black38,
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : null,
              ),

              // ── Group info card ─────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Logo + name + type
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 32,
                            backgroundImage: grupo.logoUrl != null
                                ? NetworkImage(grupo.logoUrl!)
                                : null,
                            backgroundColor:
                                AppTheme.primary.withValues(alpha: 0.1),
                            child: grupo.logoUrl == null
                                ? Text(
                                    grupo.nombre.isNotEmpty
                                        ? grupo.nombre[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  grupo.nombre,
                                  style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      isPublico
                                          ? Icons.public
                                          : Icons.lock_outline,
                                      size: 14,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isPublico ? 'Grupo público' : 'Grupo privado',
                                      style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 13),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Stats row
                      Row(
                        children: [
                          _InfoChip(
                            icon: Icons.people_outline,
                            label: '${grupo.miembrosCount} miembros',
                          ),
                          const SizedBox(width: 10),
                          _InfoChip(
                            icon: Icons.calendar_today_outlined,
                            label:
                                'Desde ${grupo.createdAt.year}',
                          ),
                        ],
                      ),

                      if (grupo.descripcion != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            grupo.descripcion!,
                            style: TextStyle(
                                color: Colors.grey[700], fontSize: 14),
                          ),
                        ),
                      ],

                      const SizedBox(height: 32),

                      // ── Action section ─────────────────────────────────
                      if (yaEsMiembro) ...[
                        const _StatusBanner(
                          icon: Icons.check_circle,
                          text: 'Ya sos miembro de este grupo',
                          color: Colors.green,
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () => context.go('/home'),
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('Ir al grupo'),
                          style: FilledButton.styleFrom(
                              minimumSize: const Size(double.infinity, 52)),
                        ),
                      ] else if (solicitudPendiente) ...[
                        const _StatusBanner(
                          icon: Icons.hourglass_empty,
                          text: 'Tu solicitud está pendiente de aprobación',
                          color: Colors.orange,
                        ),
                      ] else if (currentUid == null) ...[
                        const _StatusBanner(
                          icon: Icons.login,
                          text: 'Necesitás una cuenta para unirte a este grupo',
                          color: AppTheme.info,
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () {
                            final dest = Uri.encodeComponent('/join/$grupoId');
                            context.go('/login?redirect=$dest');
                          },
                          style: FilledButton.styleFrom(
                              minimumSize: const Size(double.infinity, 52)),
                          child: const Text('Iniciar sesión'),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton(
                          onPressed: () {
                            final dest = Uri.encodeComponent('/join/$grupoId');
                            context.go('/register?redirect=$dest');
                          },
                          style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 52)),
                          child: const Text('Crear cuenta'),
                        ),
                      ] else ...[
                        _JoinButton(
                          grupoId: grupoId,
                          isPublico: isPublico,
                          grupoNombre: grupo.nombre,
                        ),
                      ],
                    ],
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

// ── Join button widget ────────────────────────────────────────────────────────

class _JoinButton extends ConsumerWidget {
  final String grupoId;
  final bool isPublico;
  final String grupoNombre;

  const _JoinButton({
    required this.grupoId,
    required this.isPublico,
    required this.grupoNombre,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(unirseGrupoProvider);

    return Column(
      children: [
        if (isPublico)
          FilledButton.icon(
            onPressed: state.isLoading ? null : () => _unirse(context, ref, grupoNombre),
            icon: state.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.group_add_outlined),
            label: const Text('Unirse al grupo'),
            style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 52)),
          )
        else
          OutlinedButton.icon(
            onPressed: state.isLoading ? null : () => _solicitar(context, ref),
            icon: state.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send_outlined),
            label: const Text('Solicitar unirse'),
            style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52)),
          ),
        const SizedBox(height: 10),
        Text(
          isPublico
              ? 'Acceso inmediato sin aprobación'
              : 'El administrador deberá aprobar tu solicitud',
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Future<void> _unirse(BuildContext context, WidgetRef ref, String nombre) async {
    try {
      await ref.read(unirseGrupoProvider.notifier).unirse(grupoId);
      if (context.mounted) {
        // Show confirmation before navigating
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text('¡Te uniste a $nombre!')),
            ]),
            backgroundColor: Colors.green.shade600,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        context.go('/home');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _solicitar(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(unirseGrupoProvider.notifier).solicitar(grupoId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Solicitud enviada ✓ El admin la revisará pronto'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

// ── Helper widgets ────────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _StatusBanner(
      {required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text,
                  style: TextStyle(color: color, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
