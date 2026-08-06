import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/sg_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/grupo_provider.dart';
import '../../../data/models/grupo_model.dart';
import '../../../data/models/enums.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gruposAsync = ref.watch(userGruposProvider);
    final currentUserAsync = ref.watch(currentUserProvider);

    final greeting = _greeting();

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: SafeArea(
        bottom: false,
        child: Builder(builder: (context) {
          // Show full-screen loading only on initial load (no prior data).
          if (gruposAsync.isLoading && !gruposAsync.hasValue) {
            return const Center(child: CircularProgressIndicator());
          }
          if (gruposAsync.hasError && !gruposAsync.hasValue) {
            return const SGErrorState(message: 'Error al cargar los grupos');
          }
          final grupos = gruposAsync.valueOrNull ?? [];

          return CustomScrollView(
            slivers: [
              // â”€â”€ Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.push('/profile'),
                        child: currentUserAsync.maybeWhen(
                          data: (u) => SGAvatar(
                            name: u?.nombreCompleto ?? '?',
                            imageUrl: u?.avatarUrl,
                            size: 44,
                          ),
                          orElse: () => const SGAvatar(name: '?', size: 44),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _today(),
                              style: const TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            currentUserAsync.maybeWhen(
                              data: (u) => Text(
                                'Hola, ${u?.nombreCompleto.split(' ').first ?? '👋'}',
                                style: GoogleFonts.bricolageGrotesque(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                  letterSpacing: -0.3,
                                  color: AppTheme.text,
                                ),
                              ),
                              orElse: () => Text(
                                greeting,
                                style: GoogleFonts.bricolageGrotesque(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Notification bell
                      IconButton(
                        icon: const Icon(Icons.notifications_outlined),
                        tooltip: 'Notificaciones',
                        onPressed: () => context.push('/notificaciones'),
                      ),
                      // Settings / logout via profile
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded, size: 22),
                        onSelected: (v) {
                          if (v == 'profile') context.push('/profile');
                          if (v == 'search') context.push('/search');
                          if (v == 'logout') _confirmLogout(context, ref);
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'profile',
                            child: ListTile(
                              dense: true, contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.person_outline_rounded),
                              title: Text('Mi perfil'),
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'search',
                            child: ListTile(
                              dense: true, contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.search_rounded),
                              title: Text('Buscar grupos'),
                            ),
                          ),
                          const PopupMenuDivider(),
                          const PopupMenuItem(
                            value: 'logout',
                            child: ListTile(
                              dense: true, contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.logout_rounded,
                                  color: AppTheme.danger),
                              title: Text('Cerrar sesión',
                                  style: TextStyle(color: AppTheme.danger)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              if (grupos.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(),
                )
              else ...[
                // â”€â”€ Eyebrow
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: SGEyebrow('Mis grupos'),
                  ),
                ),

                // â”€â”€ Group cards
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  sliver: SliverList.separated(
                    itemCount: grupos.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _GrupoCard(grupo: grupos[i]),
                  ),
                ),
              ],
            ],
          );
        }),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/create-group'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Crear grupo'),
      ),
    );
  }

  String _today() {
    final names = [
      'Lunes', 'Martes', 'Miércoles', 'Jueves',
      'Viernes', 'Sábado', 'Domingo',
    ];
    final months = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
    ];
    final n = DateTime.now();
    return '${names[n.weekday - 1]}, ${n.day} de ${months[n.month - 1]}';
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Buen día 👋';
    if (h < 19) return 'Buenas 👋';
    return 'Buenas noches 👋';
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Querés cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(authFlowProvider.notifier).signOut();
              if (context.mounted) context.go('/login');
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.danger,
              minimumSize: const Size(120, 44),
            ),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _GrupoCard extends StatelessWidget {
  final GrupoModel grupo;
  const _GrupoCard({required this.grupo});

  @override
  Widget build(BuildContext context) {
    final isPublic = grupo.tipo == TipoGrupo.publico;
    return SGCard(
      onTap: () => context.push('/group/${grupo.id}'),
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover photo or banner stripe
            if (grupo.portadaUrl != null)
              SizedBox(
                height: 120,
                width: double.infinity,
                child: CachedNetworkImage(
                  imageUrl: grupo.portadaUrl!,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    color: AppTheme.surfaceAlt,
                  ),
                ),
              )
            else
              Container(
                height: 56,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primarySoft,
                      AppTheme.accentSoft,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Row(
                children: [
                  SGAvatar(
                    name: grupo.nombre,
                    imageUrl: grupo.logoUrl,
                    size: 44,
                    background: AppTheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          grupo.nombre,
                          style: GoogleFonts.bricolageGrotesque(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: AppTheme.text,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          children: [
                            SGChip(
                              icon: Icons.group_outlined,
                              label: '${grupo.miembrosCount}',
                            ),
                            SGChip(
                              icon: isPublic
                                  ? Icons.public_rounded
                                  : Icons.lock_outline_rounded,
                              label: isPublic ? 'Público' : 'Privado',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: AppTheme.textMuted),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
void _showInviteCodeDialog(BuildContext context) {
  final ctrl = TextEditingController();
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Código de invitación'),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Pegá el código o link aquí',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final raw = ctrl.text.trim();
            Navigator.pop(context);
            if (raw.isEmpty) return;
            // Extract group ID from full link or use raw as ID
            String grupoId = raw;
            final uri = Uri.tryParse(raw);
            if (uri != null) {
              final segments = uri.pathSegments;
              final joinIdx = segments.indexOf('join');
              if (joinIdx >= 0 && joinIdx + 1 < segments.length) {
                grupoId = segments[joinIdx + 1];
              }
            }
            context.push('/join/$grupoId');
          },
          child: const Text('Unirme'),
        ),
      ],
    ),
  );
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 60, 32, 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              for (var i = 2; i >= 0; i--)
                Transform.translate(
                  offset: Offset(i * 8.0, i * 4.0),
                  child: Transform.rotate(
                    angle: (i - 1) * 0.08,
                    child: Container(
                      width: 140,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 24, height: 24,
                              decoration: BoxDecoration(
                                color: AppTheme.primarySoft,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(width: 80, height: 6, color: AppTheme.border),
                            const SizedBox(height: 4),
                            Container(width: 50, height: 6, color: AppTheme.border),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            'Todavía no estás\nen ningún grupo',
            textAlign: TextAlign.center,
            style: GoogleFonts.bricolageGrotesque(
              fontWeight: FontWeight.w700,
              fontSize: 22,
              height: 1.15,
              color: AppTheme.text,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Sumate a uno o creá el tuyo — es para\narrancar en menos de un minuto.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textMuted, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 28),
          SGPillButton(
            icon: Icons.add_rounded,
            label: 'Crear un grupo',
            expand: true,
            onPressed: () => context.push('/create-group'),
          ),
          const SizedBox(height: 10),
          SGPillButton(
            icon: Icons.qr_code_2_rounded,
            label: 'Tengo un código de invitación',
            tone: SGTone.soft,
            expand: true,
            onPressed: () => _showInviteCodeDialog(context),
          ),
          const SizedBox(height: 10),
          SGPillButton(
            icon: Icons.search_rounded,
            label: 'Buscar grupos cerca mío',
            tone: SGTone.outline,
            expand: true,
            onPressed: () => context.push('/search'),
          ),
        ],
      ),
    );
  }
}
