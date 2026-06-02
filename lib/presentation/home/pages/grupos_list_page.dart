import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/sg_widgets.dart';
import '../../../data/models/grupo_model.dart';
import '../../../data/models/enums.dart';
import '../../../providers/grupo_provider.dart';
import '../../../providers/auth_provider.dart';

class GruposListPage extends ConsumerWidget {
  const GruposListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gruposAsync = ref.watch(userGruposProvider);
    final favoritosIds = ref.watch(gruposFavoritosProvider).valueOrNull ?? {};

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: SafeArea(
        bottom: false,
        child: Builder(builder: (context) {
          if (gruposAsync.isLoading && !gruposAsync.hasValue) {
            return const Center(child: CircularProgressIndicator());
          }
          final grupos = gruposAsync.valueOrNull ?? [];

          return CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Mis grupos',
                          style: GoogleFonts.bricolageGrotesque(
                            fontWeight: FontWeight.w700,
                            fontSize: 24,
                            letterSpacing: -0.4,
                            color: AppTheme.text,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.search_rounded),
                        tooltip: 'Buscar grupos',
                        onPressed: () => context.push('/search'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.link_rounded),
                        tooltip: 'Unirme con link',
                        onPressed: () =>
                            _showJoinWithLinkSheet(context),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_rounded),
                        tooltip: 'Crear grupo',
                        onPressed: () => context.push('/create-group'),
                      ),
                    ],
                  ),
                ),
              ),

              if (grupos.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyGrupos(),
                )
              else ...[
                // Favourites section
                if (favoritosIds.isNotEmpty) ...[
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
                      child: SGEyebrow('Favoritos'),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                    sliver: SliverList.separated(
                      itemCount: grupos
                          .where((g) => favoritosIds.contains(g.id))
                          .length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final favGrupos = grupos
                            .where((g) => favoritosIds.contains(g.id))
                            .toList();
                        return _GrupoCard(
                          grupo: favGrupos[i],
                          esFavorito: true,
                          ref: ref,
                        );
                      },
                    ),
                  ),
                ],

                // All groups
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
                    child: SGEyebrow('Todos'),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  sliver: SliverList.separated(
                    itemCount: grupos.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _GrupoCard(
                      grupo: grupos[i],
                      esFavorito: favoritosIds.contains(grupos[i].id),
                      ref: ref,
                    ),
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

  void _showJoinWithLinkSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _JoinWithLinkSheet(
        onNavigate: (groupId) {
          Navigator.pop(context);
          context.push('/join/$groupId');
        },
      ),
    );
  }
}

// â”€â”€ Group card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _GrupoCard extends StatelessWidget {
  final GrupoModel grupo;
  final bool esFavorito;
  final WidgetRef ref;
  const _GrupoCard({
    required this.grupo,
    required this.esFavorito,
    required this.ref,
  });

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
            if (grupo.portadaUrl != null)
              SizedBox(
                height: 100,
                width: double.infinity,
                child: CachedNetworkImage(
                  imageUrl: grupo.portadaUrl!,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) =>
                      Container(color: AppTheme.surfaceAlt),
                ),
              )
            else
              Container(
                height: 48,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.primarySoft, AppTheme.accentSoft],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Row(
                children: [
                  SGAvatar(
                    name: grupo.nombre,
                    imageUrl: grupo.logoUrl,
                    size: 40,
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
                            fontSize: 15,
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
                  // Star (favourite) toggle
                  GestureDetector(
                    onTap: () async {
                      final uid =
                          ref.read(authStateProvider).valueOrNull?.uid;
                      if (uid == null) return;
                      await ref
                          .read(grupoRepositoryProvider)
                          .setFavorito(grupo.id, uid, !esFavorito);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        esFavorito
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: esFavorito
                            ? AppTheme.primary
                            : AppTheme.textMuted,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// â”€â”€ Join-with-link bottom sheet â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _JoinWithLinkSheet extends StatefulWidget {
  final void Function(String groupId) onNavigate;
  const _JoinWithLinkSheet({required this.onNavigate});

  @override
  State<_JoinWithLinkSheet> createState() => _JoinWithLinkSheetState();
}

class _JoinWithLinkSheetState extends State<_JoinWithLinkSheet> {
  final _ctrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Accepts either a full URL like https://sports-groups-app.web.app/join/ABC123
  /// or a raw group ID like ABC123.
  String? _parseGroupId(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;
    // Try URL
    try {
      final uri = Uri.parse(trimmed);
      final segments = uri.pathSegments;
      final joinIdx = segments.indexOf('join');
      if (joinIdx != -1 && joinIdx + 1 < segments.length) {
        return segments[joinIdx + 1];
      }
    } catch (_) {}
    // Raw ID: no spaces, reasonable length
    if (!trimmed.contains(' ') && trimmed.length >= 6) {
      return trimmed;
    }
    return null;
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _ctrl.text = data!.text!;
      setState(() => _error = null);
    }
  }

  void _join() {
    final groupId = _parseGroupId(_ctrl.text);
    if (groupId == null) {
      setState(() => _error = 'Pegá un link válido o un ID de grupo.');
      return;
    }
    widget.onNavigate(groupId);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text('Unirme con link',
              style: GoogleFonts.bricolageGrotesque(
                fontWeight: FontWeight.w700,
                fontSize: 20,
                letterSpacing: -0.3,
              )),
          const SizedBox(height: 4),
          const Text(
            'Pegá el link o ID que te compartieron.',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
          ),
          const SizedBox(height: 20),
          // Input row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'https://sports-groups-app.web.app/join/…',
                    errorText: _error,
                    prefixIcon:
                        const Icon(Icons.link_rounded, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                  onChanged: (_) => setState(() => _error = null),
                  onSubmitted: (_) => _join(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                icon: const Icon(Icons.content_paste_rounded),
                tooltip: 'Pegar del portapapeles',
                onPressed: _paste,
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _join,
              icon: const Icon(Icons.login_rounded, size: 18),
              label: const Text('Ir al grupo'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// â”€â”€ Empty state â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _EmptyGrupos extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 60, 32, 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.groups_rounded, size: 72, color: AppTheme.border),
          const SizedBox(height: 20),
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
          const SizedBox(height: 8),
          const Text(
            'Sumate a uno o creá el tuyo.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppTheme.textMuted, fontSize: 14),
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
            icon: Icons.search_rounded,
            label: 'Buscar grupos',
            tone: SGTone.outline,
            expand: true,
            onPressed: () => context.push('/search'),
          ),
        ],
      ),
    );
  }
}
