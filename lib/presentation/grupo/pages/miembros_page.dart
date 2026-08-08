import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/sg_widgets.dart';
import '../../../data/models/miembro_model.dart';
import '../../../data/models/enums.dart';
import '../../../providers/grupo_provider.dart';

class MiembrosPage extends ConsumerStatefulWidget {
  final String grupoId;

  /// `false` cuando la página actúa como pestaña del shell (no hay a dónde volver).
  final bool showBackButton;

  const MiembrosPage({
    super.key,
    required this.grupoId,
    this.showBackButton = true,
  });

  @override
  ConsumerState<MiembrosPage> createState() => _MiembrosPageState();
}

class _MiembrosPageState extends ConsumerState<MiembrosPage> {
  // null = Todos
  RolMiembro? _filtro;

  @override
  Widget build(BuildContext context) {
    final gc = ref.watch(grupoColorProvider(widget.grupoId));
    final miembrosAsync = ref.watch(miembrosProvider(widget.grupoId));

    final isDesktop = MediaQuery.sizeOf(context).width >= AppTheme.kResponsiveBreakpoint;
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: isDesktop ? null : AppBar(
        backgroundColor: AppTheme.surf(context),
        elevation: 0,
        leading: widget.showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => context.pop(),
              )
            : null,
        automaticallyImplyLeading: widget.showBackButton,
        title: Text(
          'Miembros',
          style: GoogleFonts.bricolageGrotesque(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: -0.3,
            color: AppTheme.text,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.border),
        ),
      ),
      body: miembrosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const SGErrorState(message: 'Error al cargar los miembros'),
        data: (todos) {
          // Counts per rol
          final countAdmin =
              todos.where((m) => m.rol.esAdmin).length;
          final countMiembro =
              todos.where((m) => m.rol == RolMiembro.miembro).length;

          // Apply filter
          final miembros = _filtro == null
              ? todos
              : todos.where((m) => m.rol == _filtro).toList();

          // Staff = non-miembro roles
          final staff = miembros
              .where((m) => m.rol != RolMiembro.miembro)
              .toList();
          final regulares = miembros
              .where((m) => m.rol == RolMiembro.miembro)
              .toList();

          return CustomScrollView(
            slivers: [
              // â”€â”€ Count + filter chips â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '${todos.length} ',
                              style: const TextStyle(
                                color: AppTheme.text,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            TextSpan(
                              text:
                                  '${todos.length == 1 ? "miembro" : "miembros"} en el grupo',
                              style: const TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 48,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        children: [
                          _FilterChip(
                            label: 'Todos',
                            selected: _filtro == null,
                            gc: gc,
                            onTap: () =>
                                setState(() => _filtro = null),
                          ),
                          if (countAdmin > 0)
                            _FilterChip(
                              icon: Icons.shield_rounded,
                              label: 'Admin · $countAdmin',
                              tone: SGChipTone.primary,
                              selected:
                                  _filtro == RolMiembro.administrador,
                              gc: gc,
                              onTap: () => setState(
                                  () => _filtro = RolMiembro.administrador),
                            ),
                          // Roles Delegado / Tesorero / Moderador en pausa —
                          // se ocultan sus chips de filtro.
                          if (countMiembro > 0)
                            _FilterChip(
                              icon: Icons.person_outline_rounded,
                              label: 'Miembros · $countMiembro',
                              tone: SGChipTone.neutral,
                              selected:
                                  _filtro == RolMiembro.miembro,
                              gc: gc,
                              onTap: () => setState(
                                  () => _filtro = RolMiembro.miembro),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // â”€â”€ Staff card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              if (staff.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: SGEyebrow('STAFF · ${staff.length}'),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _MemberCard(
                    miembros: staff,
                    grupoId: widget.grupoId,
                    showRole: true,
                    gc: gc,
                  ),
                ),
              ],

              // â”€â”€ Miembros card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              if (regulares.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: SGEyebrow('MIEMBROS · ${regulares.length}'),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _MemberCard(
                    miembros: regulares,
                    grupoId: widget.grupoId,
                    showRole: false,
                    gc: gc,
                  ),
                ),
              ],

              if (miembros.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person_search_rounded,
                              size: 48, color: AppTheme.textMuted),
                          const SizedBox(height: 12),
                          Text(
                            _filtro != null
                                ? 'Sin miembros con rol '
                                    '${_filtro!.name[0].toUpperCase()}'
                                    '${_filtro!.name.substring(1)}'
                                : 'Sin miembros en este filtro',
                            style: const TextStyle(
                                color: AppTheme.textMuted, fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                          if (_filtro != null) ...[
                            const SizedBox(height: 16),
                            TextButton.icon(
                              onPressed: () =>
                                  setState(() => _filtro = null),
                              icon: const Icon(Icons.close_rounded,
                                  size: 14),
                              label: const Text('Ver todos'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          );
        },
      ),
    );
  }
}

// â”€â”€ Member card (grouped) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _MemberCard extends StatelessWidget {
  final List<MiembroModel> miembros;
  final String grupoId;
  final bool showRole;
  final Color gc;

  const _MemberCard({
    required this.miembros,
    required this.grupoId,
    required this.showRole,
    required this.gc,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      padding: const EdgeInsets.all(4),
      child: Column(
        children: List.generate(miembros.length, (i) {
          return _MemberRow(
            miembro: miembros[i],
            grupoId: grupoId,
            hasBorder: i < miembros.length - 1,
            showRole: showRole,
            gc: gc,
          );
        }),
      ),
    );
  }
}

// â”€â”€ Member row â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _MemberRow extends ConsumerWidget {
  final MiembroModel miembro;
  final String grupoId;
  final bool hasBorder;
  final bool showRole;
  final Color gc;

  const _MemberRow({
    required this.miembro,
    required this.grupoId,
    required this.hasBorder,
    required this.showRole,
    required this.gc,
  });

  Color _avatarBg(RolMiembro r) => switch (r) {
        RolMiembro.administrador => gc,
        RolMiembro.delegado => AppTheme.accent,
        RolMiembro.tesorero => AppTheme.good,
        RolMiembro.moderador => AppTheme.textMuted,
        RolMiembro.miembro => gc,
      };

  String _rolLabel(RolMiembro r) => switch (r) {
        RolMiembro.administrador => 'Admin',
        RolMiembro.moderador => 'Moderador',
        RolMiembro.tesorero => 'Tesorero',
        RolMiembro.delegado => 'Delegado',
        RolMiembro.miembro => 'Miembro',
      };

  SGChipTone _rolTone(RolMiembro r) => switch (r) {
        RolMiembro.administrador => SGChipTone.primary,
        RolMiembro.moderador => SGChipTone.neutral,
        RolMiembro.tesorero => SGChipTone.good,
        RolMiembro.delegado => SGChipTone.accent,
        RolMiembro.miembro => SGChipTone.neutral,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rol = miembro.rol;
    final myRol =
        ref.watch(miembroActualProvider(grupoId)).valueOrNull?.rol;
    final isAdmin = myRol?.esAdmin ?? false;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _showSheet(context, ref, isAdmin),
      child: Container(
        decoration: BoxDecoration(
          border: hasBorder
              ? const Border(
                  bottom: BorderSide(color: AppTheme.border, width: 1))
              : null,
        ),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
          children: [
            SGAvatar(
              name: miembro.nombreCompleto,
              imageUrl: miembro.avatarUrl,
              size: 40,
              background: _avatarBg(rol),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    miembro.nombreCompleto,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppTheme.text,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '@${miembro.nombreCompleto.toLowerCase().replaceAll(' ', '')}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (showRole && rol != RolMiembro.miembro) ...[
              const SizedBox(width: 8),
              SGChip(
                label: _rolLabel(rol),
                tone: _rolTone(rol),
              ),
            ],
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppTheme.textMuted),
          ],
        ),
      ),
    ));
  }

  void _showSheet(
      BuildContext context, WidgetRef ref, bool isAdmin) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Header
              Row(children: [
                SGAvatar(
                  name: miembro.nombreCompleto,
                  imageUrl: miembro.avatarUrl,
                  size: 48,
                  background: _avatarBg(miembro.rol),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(miembro.nombreCompleto,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16)),
                      const SizedBox(height: 2),
                      SGChip(
                        label: _rolLabel(miembro.rol),
                        tone: _rolTone(miembro.rol),
                      ),
                    ],
                  ),
                ),
              ]),
              if (isAdmin) ...[
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 8),
                // Role options
                ...rolesAsignables
                    .where((r) => r != miembro.rol)
                    .map((r) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.manage_accounts_rounded,
                              color: gc, size: 20),
                          title: Text('Cambiar a ${_rolLabel(r)}',
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600)),
                          onTap: () async {
                            Navigator.pop(context);
                            await ref
                                .read(grupoRepositoryProvider)
                                .updateRolMiembro(
                                  grupoId,
                                  miembro.uid,
                                  r,
                                  nombreMiembro: miembro.nombreCompleto,
                                );
                          },
                        )),
                if (miembro.rol != RolMiembro.administrador)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.person_remove_outlined,
                        color: AppTheme.danger, size: 20),
                    title: const Text('Quitar del grupo',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.danger)),
                    onTap: () async {
                      Navigator.pop(context);
                      await ref
                          .read(grupoRepositoryProvider)
                          .leaveGrupo(grupoId, miembro.uid);
                    },
                  ),
              ],
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }
}

// â”€â”€ Filter chip â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final SGChipTone tone;
  final bool selected;
  final VoidCallback onTap;
  final Color gc;

  const _FilterChip({
    required this.label,
    this.icon,
    this.tone = SGChipTone.primary,
    required this.selected,
    required this.onTap,
    required this.gc,
  });

  Color _bg() => switch (tone) {
        SGChipTone.primary => gc,
        SGChipTone.accent => AppTheme.accent,
        SGChipTone.good => AppTheme.good,
        SGChipTone.danger => AppTheme.danger,
        SGChipTone.neutral => AppTheme.textMuted,
      };

  @override
  Widget build(BuildContext context) {
    final bg = _bg();
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 6, bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? bg : AppTheme.surfaceAlt,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: selected ? bg : AppTheme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 13,
                  color: selected ? Colors.white : AppTheme.textMuted),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
