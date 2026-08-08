import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/sg_widgets.dart';
import '../../../data/models/noticia_model.dart';
import '../../../data/models/enums.dart';
import '../../../providers/noticia_provider.dart';
import '../../../providers/grupo_provider.dart';
import '../../../providers/auth_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helper — abre el modal de detalle desde cualquier contexto.
// Si el usuario es admin/moderador y elige "Editar", muestra el sheet de edición.
Future<void> showNoticiaDetail(
  BuildContext context,
  NoticiaModel noticia,
  String grupoId,
) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // Keyboard handling is done inside NoticiaDetailModal via viewInsets
    builder: (ctx) => NoticiaDetailModal(noticia: noticia, grupoId: grupoId),
  );
  if (action == 'edit' && context.mounted) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          NoticiaEditSheet(grupoId: grupoId, editing: noticia),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Feed de noticias del grupo — Activas / Pasadas tabs
class NoticiasTab extends ConsumerWidget {
  final String grupoId;
  const NoticiasTab({super.key, required this.grupoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noticiasAsync = ref.watch(noticiasProvider(grupoId));
    final miembroAsync = ref.watch(miembroActualProvider(grupoId));
    final uid = ref.watch(authStateProvider).valueOrNull?.uid ?? '';
    final puedePublicar =
        miembroAsync.valueOrNull?.rol.puedePublicarNoticias ?? false;
    final puedeModerar = miembroAsync.valueOrNull?.rol.esAdmin == true ||
        miembroAsync.valueOrNull?.rol == RolMiembro.moderador;

    final noticias = noticiasAsync.valueOrNull ?? [];
    final activas = noticias.where((n) => !n.caducada).toList();
    final pasadas = noticias.where((n) => n.caducada).toList();
    final hasPasadas = pasadas.isNotEmpty;

    return DefaultTabController(
      length: hasPasadas ? 2 : 1,
      child: Scaffold(
        appBar: hasPasadas
            ? const PreferredSize(
                preferredSize: Size.fromHeight(48),
                child: Material(
                  color: AppTheme.surface,
                  child: TabBar(
                    tabs: [
                      Tab(text: 'Activas'),
                      Tab(text: 'Pasadas'),
                    ],
                    labelColor: AppTheme.primary,
                    unselectedLabelColor: AppTheme.textMuted,
                    indicatorColor: AppTheme.primary,
                    dividerColor: AppTheme.border,
                  ),
                ),
              )
            : null,
        body: noticiasAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) {
            final isPermissionDenied = e.toString().contains('permission-denied');
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isPermissionDenied
                        ? Icons.lock_outline_rounded
                        : Icons.error_outline_rounded,
                    size: 48,
                    color: AppTheme.textMuted,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isPermissionDenied
                        ? 'Sin acceso a este grupo'
                        : 'No se pudo cargar',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            );
          },
          data: (_) {
            if (!hasPasadas) {
              // No expired noticias — single list, no tabs
              return _NoticiasList(
                noticias: activas,
                uid: uid,
                grupoId: grupoId,
                puedeModerar: puedeModerar,
                emptyMessage: 'Todavía no hay noticias',
              );
            }
            return TabBarView(
              children: [
                _NoticiasList(
                  noticias: activas,
                  uid: uid,
                  grupoId: grupoId,
                  puedeModerar: puedeModerar,
                  emptyMessage: 'Sin noticias activas',
                ),
                _NoticiasList(
                  noticias: pasadas,
                  uid: uid,
                  grupoId: grupoId,
                  puedeModerar: puedeModerar,
                  emptyMessage: 'Sin noticias pasadas',
                  dimmed: true,
                ),
              ],
            );
          },
        ),
        floatingActionButton: puedePublicar
            ? FloatingActionButton(
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (_) => NoticiaEditSheet(grupoId: grupoId),
                ),
                child: const Icon(Icons.add_rounded),
              )
            : null,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable list widget used by both tabs
class _NoticiasList extends StatelessWidget {
  final List<NoticiaModel> noticias;
  final String uid, grupoId;
  final bool puedeModerar;
  final String emptyMessage;
  final bool dimmed;

  const _NoticiasList({
    required this.noticias,
    required this.uid,
    required this.grupoId,
    required this.puedeModerar,
    required this.emptyMessage,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    if (noticias.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.newspaper_outlined,
                  size: 56, color: AppTheme.textMuted),
              const SizedBox(height: 12),
              Text(emptyMessage,
                  style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
    }
    return Opacity(
      opacity: dimmed ? 0.65 : 1.0,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, AppTheme.kBottomNavPadding),
        itemCount: noticias.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _NoticiaCard(
          noticia: noticias[i],
          uid: uid,
          grupoId: grupoId,
          puedeModerar: puedeModerar,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tarjeta de noticia en el feed del grupo
class _NoticiaCard extends ConsumerWidget {
  final NoticiaModel noticia;
  final String uid, grupoId;
  final bool puedeModerar;

  const _NoticiaCard({
    required this.noticia,
    required this.uid,
    required this.grupoId,
    required this.puedeModerar,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liked = noticia.likedBy(uid);
    return GestureDetector(
      onTap: () => showNoticiaDetail(context, noticia, grupoId),
      child: SGCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (noticia.fijada)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: const BoxDecoration(
                  color: AppTheme.accentSoft,
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20)),
                ),
                child: Row(children: [
                  const Icon(Icons.push_pin,
                      size: 14, color: AppTheme.accentInk),
                  const SizedBox(width: 6),
                  Text('FIJADA',
                      style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accentInk,
                          letterSpacing: 0.8)),
                ]),
              ),
            if (noticia.imagenUrl != null)
              ClipRRect(
                borderRadius: noticia.fijada
                    ? BorderRadius.zero
                    : const BorderRadius.vertical(top: Radius.circular(20)),
                child: CachedNetworkImage(
                  imageUrl: noticia.imagenUrl!,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(noticia.titulo,
                          style: GoogleFonts.bricolageGrotesque(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              letterSpacing: -0.2)),
                    ),
                    if (noticia.tieneListado) ...[
                      const SizedBox(width: 6),
                      const SGChip(
                          icon: Icons.checklist_rounded,
                          label: 'Asistencia',
                          tone: SGChipTone.primary),
                    ],
                  ]),
                  const SizedBox(height: 6),
                  Text(
                    noticia.contenido,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, height: 1.45),
                  ),
                  if (noticia.mencionados.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      children: noticia.mencionados
                          .take(3)
                          .map((m) => _MentionChip(nombre: m.nombre))
                          .toList()
                        ..addAll(noticia.mencionados.length > 3
                            ? [
                                _MentionChip(
                                    nombre:
                                        '+${noticia.mencionados.length - 3}')
                              ]
                            : []),
                    ),
                  ],
                  if (noticia.tieneListado) ...[
                    const SizedBox(height: 12),
                    _RsvpInline(
                        grupoId: grupoId, noticia: noticia, uid: uid),
                  ],
                  const SizedBox(height: 10),
                  Row(children: [
                    SGAvatar(name: noticia.autorNombre, size: 22),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(noticia.autorNombre,
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textMuted)),
                    ),
                    Text(DateFormat('dd/MM').format(noticia.createdAt),
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textMuted)),
                    const SizedBox(width: 14),
                    // Likes
                    GestureDetector(
                      onTap: () => ref
                          .read(crearNoticiaProvider.notifier)
                          .toggleLike(grupoId, noticia.id),
                      child: Row(children: [
                        Icon(
                            liked ? Icons.favorite : Icons.favorite_border,
                            color:
                                liked ? AppTheme.danger : AppTheme.textMuted,
                            size: 18),
                        const SizedBox(width: 4),
                        Text('${noticia.likesCount}',
                            style: TextStyle(
                                fontSize: 12,
                                color:
                                    liked ? AppTheme.danger : AppTheme.text,
                                fontWeight: FontWeight.w600)),
                      ]),
                    ),
                    const SizedBox(width: 14),
                    // Comentarios (icono sin live count para no generar un stream por card)
                    const Icon(Icons.chat_bubble_outline_rounded,
                        size: 16, color: AppTheme.textMuted),
                    const SizedBox(width: 4),
                    const Text('Comentar',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.textMuted)),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chip compacto para menciones
class _MentionChip extends StatelessWidget {
  final String nombre;
  const _MentionChip({required this.nombre});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.accentSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('@$nombre',
          style: const TextStyle(
              fontSize: 11,
              color: AppTheme.accentInk,
              fontWeight: FontWeight.w600)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Modal de detalle + comentarios (público — reutilizable desde home feed)
class NoticiaDetailModal extends ConsumerStatefulWidget {
  final NoticiaModel noticia;
  final String grupoId;

  const NoticiaDetailModal({
    super.key,
    required this.noticia,
    required this.grupoId,
  });

  @override
  ConsumerState<NoticiaDetailModal> createState() =>
      _NoticiaDetailModalState();
}

class _NoticiaDetailModalState extends ConsumerState<NoticiaDetailModal> {
  bool _deleting = false;
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar publicación'),
        content: const Text(
            '¿Estás seguro? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await ref
          .read(crearNoticiaProvider.notifier)
          .eliminar(widget.grupoId, widget.noticia.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.noticia;
    final uid =
        ref.watch(authStateProvider).valueOrNull?.uid ?? '';
    final liked = n.likedBy(uid);
    final miembroAsync =
        ref.watch(miembroActualProvider(widget.grupoId));
    final puedeModerar =
        miembroAsync.valueOrNull?.rol.esAdmin == true ||
            miembroAsync.valueOrNull?.rol == RolMiembro.moderador;

    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.textMuted.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Contenido scrollable
          Flexible(
            child: SingleChildScrollView(
              controller: _scrollCtrl,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Imagen
                  if (n.imagenUrl != null)
                    CachedNetworkImage(
                      imageUrl: n.imagenUrl!,
                      width: double.infinity,
                      height: 220,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  // Banner fijada
                  if (n.fijada)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      color: AppTheme.accentSoft,
                      child: Row(children: [
                        const Icon(Icons.push_pin,
                            size: 14, color: AppTheme.accentInk),
                        const SizedBox(width: 6),
                        Text('FIJADA',
                            style: GoogleFonts.dmSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.accentInk,
                                letterSpacing: 0.8)),
                      ]),
                    ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Categoría
                        SGChip(
                          label:
                              '${n.categoria.emoji} ${n.categoria.label}',
                          tone: SGChipTone.neutral,
                        ),
                        const SizedBox(height: 10),
                        // Título
                        Text(n.titulo,
                            style: GoogleFonts.bricolageGrotesque(
                                fontWeight: FontWeight.w800,
                                fontSize: 22,
                                letterSpacing: -0.4)),
                        const SizedBox(height: 8),
                        // Autor + fecha
                        Row(children: [
                          SGAvatar(name: n.autorNombre, size: 24),
                          const SizedBox(width: 8),
                          Text(n.autorNombre,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textMuted,
                                  fontWeight: FontWeight.w500)),
                          const Spacer(),
                          Text(
                            DateFormat('dd MMM yyyy').format(n.createdAt),
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.textMuted),
                          ),
                        ]),
                        // Mencionados
                        if (n.mencionados.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Text('Etiquetados',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textMuted)),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: n.mencionados
                                .map((m) => _MentionChip(nombre: m.nombre))
                                .toList(),
                          ),
                        ],
                        const SizedBox(height: 16),
                        // Contenido completo
                        Text(n.contenido,
                            style: const TextStyle(
                                fontSize: 15, height: 1.55)),
                        const SizedBox(height: 18),
                        // Likes
                        GestureDetector(
                          onTap: () => ref
                              .read(crearNoticiaProvider.notifier)
                              .toggleLike(widget.grupoId, n.id),
                          child: Row(children: [
                            Icon(
                                liked
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: liked
                                    ? AppTheme.danger
                                    : AppTheme.textMuted,
                                size: 22),
                            const SizedBox(width: 6),
                            Text('${n.likesCount} me gusta',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: liked
                                        ? AppTheme.danger
                                        : AppTheme.text)),
                          ]),
                        ),
                        // RSVP
                        if (n.tieneListado) ...[
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 4),
                          const Text('Asistencia',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 10),
                          _RsvpInline(
                              grupoId: widget.grupoId,
                              noticia: n,
                              uid: uid),
                          const SizedBox(height: 14),
                          _AsistenciaList(
                              grupoId: widget.grupoId, noticiaId: n.id),
                        ],
                        // Acciones admin
                        if (puedeModerar) ...[
                          const SizedBox(height: 20),
                          const Divider(),
                          const SizedBox(height: 12),
                          Row(children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  ref
                                      .read(crearNoticiaProvider.notifier)
                                      .toggleFijada(
                                          widget.grupoId, n.id, !n.fijada);
                                  Navigator.pop(context);
                                },
                                icon: Icon(n.fijada
                                    ? Icons.push_pin_outlined
                                    : Icons.push_pin),
                                label: Text(
                                    n.fijada ? 'Desfijar' : 'Fijar'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    Navigator.pop(context, 'edit'),
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('Editar'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.danger,
                                  side: const BorderSide(
                                      color: AppTheme.danger),
                                ),
                                onPressed:
                                    _deleting ? null : _confirmDelete,
                                icon: _deleting
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child:
                                            CircularProgressIndicator(
                                                strokeWidth: 2))
                                    : const Icon(Icons.delete_outline),
                                label: const Text('Eliminar'),
                              ),
                            ),
                          ]),
                        ],

                        // Sección de comentarios
                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 8),
                        _ComentariosSection(
                          grupoId: widget.grupoId,
                          noticiaId: n.id,
                          currentUid: uid,
                          puedeModerar: puedeModerar,
                          scrollCtrl: _scrollCtrl,
                        ),
                        // Espacio extra para que el último comentario no quede
                        // tapado por el input bar
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Input de comentario (fijo al fondo)
          _CommentInputBar(
            grupoId: widget.grupoId,
            noticiaId: n.id,
            onSent: () {
              // Scroll al final cuando se envía un comentario
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_scrollCtrl.hasClients) {
                  _scrollCtrl.animateTo(
                    _scrollCtrl.position.maxScrollExtent,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                }
              });
            },
          ),

          // Espacio para el teclado — empuja el input bar por encima del teclado
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: keyboardHeight,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sección de comentarios (lista)
class _ComentariosSection extends ConsumerWidget {
  final String grupoId, noticiaId, currentUid;
  final bool puedeModerar;
  final ScrollController scrollCtrl;

  const _ComentariosSection({
    required this.grupoId,
    required this.noticiaId,
    required this.currentUid,
    required this.puedeModerar,
    required this.scrollCtrl,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (grupoId: grupoId, noticiaId: noticiaId);
    final comentariosAsync = ref.watch(comentariosProvider(key));

    return comentariosAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, _) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Icon(Icons.error_outline, size: 16, color: AppTheme.danger),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              'No se pudieron cargar los comentarios. Verificá tu conexión.',
              style: TextStyle(fontSize: 12, color: AppTheme.danger),
            ),
          ),
        ]),
      ),
      data: (lista) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.chat_bubble_outline_rounded,
                  size: 16, color: AppTheme.textMuted),
              const SizedBox(width: 6),
              Text(
                lista.isEmpty
                    ? 'Sin comentarios aún'
                    : '${lista.length} comentario${lista.length == 1 ? '' : 's'}',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.text),
              ),
            ]),
            const SizedBox(height: 12),
            if (lista.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('Sé el primero en comentar.',
                    style: TextStyle(
                        fontSize: 13, color: AppTheme.textMuted)),
              )
            else
              ...lista.map((c) => _ComentarioTile(
                    comentario: c,
                    grupoId: grupoId,
                    noticiaId: noticiaId,
                    currentUid: currentUid,
                    puedeModerar: puedeModerar,
                  )),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tile individual de comentario
class _ComentarioTile extends ConsumerStatefulWidget {
  final ComentarioModel comentario;
  final String grupoId, noticiaId, currentUid;
  final bool puedeModerar;

  const _ComentarioTile({
    required this.comentario,
    required this.grupoId,
    required this.noticiaId,
    required this.currentUid,
    required this.puedeModerar,
  });

  @override
  ConsumerState<_ComentarioTile> createState() => _ComentarioTileState();
}

class _ComentarioTileState extends ConsumerState<_ComentarioTile> {
  bool _deleting = false;

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'ahora';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes}min';
    if (diff.inHours < 24) return 'hace ${diff.inHours}h';
    if (diff.inDays < 7) return 'hace ${diff.inDays}d';
    return DateFormat('dd/MM/yy').format(dt);
  }

  Future<void> _delete() async {
    setState(() => _deleting = true);
    try {
      await ref.read(crearNoticiaProvider.notifier).deleteComentario(
            widget.grupoId,
            widget.noticiaId,
            widget.comentario.id,
          );
    } catch (_) {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.comentario;
    final canDelete =
        puedeModerar || c.uid == widget.currentUid;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SGAvatar(name: c.nombre, imageUrl: c.avatarUrl, size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bubble
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(14),
                      bottomLeft: Radius.circular(14),
                      bottomRight: Radius.circular(14),
                    ),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.nombre,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text(c.texto,
                          style: const TextStyle(
                              fontSize: 14, height: 1.4)),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                // Footer: tiempo + eliminar
                Row(children: [
                  Text(_timeAgo(c.createdAt),
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textMuted)),
                  if (canDelete) ...[
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: _deleting ? null : _delete,
                      child: _deleting
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                  strokeWidth: 1.5))
                          : const Text('Eliminar',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.danger,
                                  fontWeight: FontWeight.w600)),
                    ),
                  ],
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool get puedeModerar => widget.puedeModerar;
}

// ─────────────────────────────────────────────────────────────────────────────
// Barra de input de comentario (fija al fondo del modal)
class _CommentInputBar extends ConsumerStatefulWidget {
  final String grupoId, noticiaId;
  final VoidCallback? onSent;

  const _CommentInputBar({
    required this.grupoId,
    required this.noticiaId,
    this.onSent,
  });

  @override
  ConsumerState<_CommentInputBar> createState() => _CommentInputBarState();
}

class _CommentInputBarState extends ConsumerState<_CommentInputBar> {
  final _ctrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final texto = _ctrl.text.trim();
    if (texto.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(crearNoticiaProvider.notifier).addComentario(
            grupoId: widget.grupoId,
            noticiaId: widget.noticiaId,
            texto: texto,
          );
      _ctrl.clear();
      widget.onSent?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comentario publicado'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al publicar: $e'),
            backgroundColor: AppTheme.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gc = ref.watch(grupoColorProvider(widget.grupoId));
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: Row(children: [
        SGAvatar(
            name: currentUser?.nombreCompleto ?? '?',
            imageUrl: currentUser?.avatarUrl,
            size: 32),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: _ctrl,
            minLines: 1,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Escribí un comentario…',
              hintStyle: const TextStyle(
                  fontSize: 14, color: AppTheme.textMuted),
              filled: true,
              fillColor: AppTheme.background,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none),
            ),
            onSubmitted: (_) => _send(),
          ),
        ),
        const SizedBox(width: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _sending
              ? const SizedBox(
                  key: ValueKey('loading'),
                  width: 36,
                  height: 36,
                  child: Padding(
                    padding: EdgeInsets.all(6),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ))
              : IconButton(
                  key: const ValueKey('send'),
                  icon: const Icon(Icons.send_rounded),
                  color: gc,
                  onPressed: _send,
                ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Lista de asistentes agrupada por estado
class _AsistenciaList extends ConsumerWidget {
  final String grupoId, noticiaId;
  const _AsistenciaList({required this.grupoId, required this.noticiaId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asistAsync = ref.watch(
        asistenciaProvider((grupoId: grupoId, noticiaId: noticiaId)));
    return asistAsync.when(
      loading: () => const SizedBox(
          height: 40,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
      error: (_, __) => const SizedBox.shrink(),
      data: (lista) {
        if (lista.isEmpty) {
          return const Text('Sin respuestas aún.',
              style:
                  TextStyle(fontSize: 13, color: AppTheme.textMuted));
        }
        final va = lista.where((a) => a.estado == 'va').toList();
        final talVez =
            lista.where((a) => a.estado == 'tal_vez').toList();
        final noVa = lista.where((a) => a.estado == 'no_va').toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (va.isNotEmpty)
              _AsistenciaGroup(
                  label: '✅ Van (${va.length})', miembros: va),
            if (talVez.isNotEmpty)
              _AsistenciaGroup(
                  label: '🤔 Tal vez (${talVez.length})',
                  miembros: talVez),
            if (noVa.isNotEmpty)
              _AsistenciaGroup(
                  label: '❌ No van (${noVa.length})',
                  miembros: noVa),
          ],
        );
      },
    );
  }
}

class _AsistenciaGroup extends StatelessWidget {
  final String label;
  final List<AsistenciaItem> miembros;
  const _AsistenciaGroup({required this.label, required this.miembros});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: miembros
                .map((a) => Chip(
                      avatar: SGAvatar(name: a.nombre, size: 20),
                      label: Text(a.nombre,
                          style: const TextStyle(fontSize: 12)),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RSVP tri-estado inline
class _RsvpInline extends ConsumerWidget {
  final String grupoId, uid;
  final NoticiaModel noticia;
  const _RsvpInline(
      {required this.grupoId, required this.noticia, required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gc = ref.watch(grupoColorProvider(grupoId));
    final asistAsync = ref.watch(
      asistenciaProvider((grupoId: grupoId, noticiaId: noticia.id)),
    );
    return asistAsync.when(
      loading: () => const SizedBox(
          height: 64,
          child:
              Center(child: CircularProgressIndicator(strokeWidth: 2))),
      error: (e, _) => const SizedBox.shrink(),
      data: (lista) {
        final miEstado = lista
            .where((a) => a.uid == uid)
            .map((a) => a.estado)
            .firstOrNull;
        final going = lista.where((a) => a.estado == 'va').length;
        final maybe = lista.where((a) => a.estado == 'tal_vez').length;
        final not = lista.where((a) => a.estado == 'no_va').length;
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            _RsvpSeg(
                label: 'Voy',
                sub: '$going',
                icon: Icons.check_circle,
                selected: miEstado == 'va',
                gc: gc,
                onTap: () => _setEstado(ref, miEstado, 'va')),
            _RsvpSeg(
                label: 'Tal vez',
                sub: '$maybe',
                icon: Icons.help_outline,
                selected: miEstado == 'tal_vez',
                gc: gc,
                onTap: () => _setEstado(ref, miEstado, 'tal_vez')),
            _RsvpSeg(
                label: 'No voy',
                sub: '$not',
                icon: Icons.cancel_outlined,
                selected: miEstado == 'no_va',
                gc: gc,
                onTap: () => _setEstado(ref, miEstado, 'no_va')),
          ]),
        );
      },
    );
  }

  void _setEstado(WidgetRef ref, String? actual, String nuevo) {
    final notifier = ref.read(crearNoticiaProvider.notifier);
    if (actual == nuevo) {
      notifier.removeAsistencia(grupoId, noticia.id);
    } else {
      notifier.setAsistencia(
          grupoId: grupoId, noticiaId: noticia.id, estado: nuevo);
    }
  }
}

class _RsvpSeg extends StatelessWidget {
  final String label, sub;
  final IconData icon;
  final bool selected;
  final Color gc;
  final VoidCallback onTap;
  const _RsvpSeg(
      {required this.label,
      required this.sub,
      required this.icon,
      required this.selected,
      required this.gc,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppTheme.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? const [
                    BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 6,
                        offset: Offset(0, 2)),
                  ]
                : null,
          ),
          child: Column(children: [
            Icon(icon,
                size: 20,
                color: selected ? gc : AppTheme.textMuted),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected ? AppTheme.text : AppTheme.textMuted)),
            Text(sub,
                style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheet de creación / edición de noticia (público)
class NoticiaEditSheet extends ConsumerStatefulWidget {
  final String grupoId;
  final NoticiaModel? editing;

  const NoticiaEditSheet({super.key, required this.grupoId, this.editing});

  @override
  ConsumerState<NoticiaEditSheet> createState() => _NoticiaEditSheetState();
}

class _NoticiaEditSheetState extends ConsumerState<NoticiaEditSheet> {
  late final TextEditingController _tituloCtrl;
  late final TextEditingController _contenidoCtrl;
  Uint8List? _imagenBytes;
  late bool _tieneListado;
  late NoticiaCategoria _categoria;
  bool _notificarWhatsApp = false;
  final Map<String, String> _mencionados = {};
  DateTime? _fechaCaducidad;

  DateTime? _fechaEvento;

  bool get _isEdit => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    _tituloCtrl = TextEditingController(text: e?.titulo ?? '');
    _contenidoCtrl = TextEditingController(text: e?.contenido ?? '');
    _tieneListado = e?.tieneListado ?? false;
    _categoria = e?.categoria ?? NoticiaCategoria.general;
    _fechaCaducidad = e?.fechaCaducidad;
    _fechaEvento = e?.fechaEvento;
    if (e != null) {
      for (final m in e.mencionados) {
        _mencionados[m.uid] = m.nombre;
      }
    }
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _contenidoCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() => _imagenBytes = bytes);
    }
  }

  Future<void> _guardar() async {
    final titulo = _tituloCtrl.text.trim();
    final contenido = _contenidoCtrl.text.trim();
    if (titulo.isEmpty || contenido.isEmpty) return;
    final mencList = _mencionados.entries
        .map((e) => MencionadoItem(uid: e.key, nombre: e.value))
        .toList();
    try {
      if (_isEdit) {
        await ref.read(crearNoticiaProvider.notifier).editar(
              grupoId: widget.grupoId,
              noticiaId: widget.editing!.id,
              titulo: titulo,
              contenido: contenido,
              imagenBytes: _imagenBytes,
              existingImagenUrl: widget.editing!.imagenUrl,
              tieneListado: _tieneListado,
              categoria: _categoria,
              mencionados: mencList,
              fechaCaducidad: _fechaCaducidad,
              fechaEvento: _fechaEvento,
            );
      } else {
        await ref.read(crearNoticiaProvider.notifier).crear(
              grupoId: widget.grupoId,
              titulo: titulo,
              contenido: contenido,
              imagenBytes: _imagenBytes,
              tieneListado: _tieneListado,
              categoria: _categoria,
              mencionados: mencList,
              fechaCaducidad: _fechaCaducidad,
              fechaEvento: _fechaEvento,
            );
      }
      if (!mounted) return;
      Navigator.pop(context);
      if (!_isEdit && _notificarWhatsApp) {
        const base = 'https://sports-groups-app.web.app';
        final msg = '📢 *$titulo*\n\n$contenido\n\n'
            '🔗 Ver: $base';
        await launchUrl(
            Uri.parse('https://wa.me/?text=${Uri.encodeComponent(msg)}'),
            mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(crearNoticiaProvider).isLoading;
    final miembrosAsync = ref.watch(miembrosProvider(widget.grupoId));
    final gc = ref.watch(grupoColorProvider(widget.grupoId));

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 8,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                _isEdit ? 'Editar publicación' : 'Nueva publicación',
                style: GoogleFonts.bricolageGrotesque(
                    fontWeight: FontWeight.w700, fontSize: 18),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
                controller: _tituloCtrl,
                decoration:
                    const InputDecoration(labelText: 'Título')),
            const SizedBox(height: 10),
            TextField(
                controller: _contenidoCtrl,
                decoration:
                    const InputDecoration(labelText: 'Contenido'),
                maxLines: 4),
            const SizedBox(height: 10),
            DropdownButtonFormField<NoticiaCategoria>(
              initialValue: _categoria,
              decoration:
                  const InputDecoration(labelText: 'Categoría'),
              items: NoticiaCategoria.values
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text('${c.emoji} ${c.label}'),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _categoria = v);
              },
            ),
            const SizedBox(height: 10),
            // Fecha de caducidad (opcional)
            GestureDetector(
              onTap: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _fechaCaducidad ?? now.add(const Duration(days: 7)),
                  firstDate: now,
                  lastDate: now.add(const Duration(days: 365 * 2)),
                  helpText: 'Caduca el',
                );
                if (picked != null) setState(() => _fechaCaducidad = picked);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _fechaCaducidad != null
                        ? AppTheme.primary.withValues(alpha: 0.5)
                        : AppTheme.border,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.event_outlined,
                      size: 18,
                      color: _fechaCaducidad != null
                          ? AppTheme.primary
                          : AppTheme.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _fechaCaducidad != null
                            ? 'Caduca el ${DateFormat('dd/MM/yyyy').format(_fechaCaducidad!)}'
                            : 'Fecha de caducidad (opcional)',
                        style: TextStyle(
                          fontSize: 14,
                          color: _fechaCaducidad != null
                              ? AppTheme.text
                              : AppTheme.textMuted,
                        ),
                      ),
                    ),
                    if (_fechaCaducidad != null)
                      GestureDetector(
                        onTap: () => setState(() => _fechaCaducidad = null),
                        child: const Icon(Icons.close_rounded,
                            size: 16, color: AppTheme.textMuted),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [
              TextButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.image_outlined),
                label: Text(_isEdit && widget.editing!.imagenUrl != null
                    ? 'Cambiar foto'
                    : 'Foto'),
              ),
              if (_imagenBytes != null)
                const Icon(Icons.check_circle, color: AppTheme.good),
              if (_isEdit &&
                  widget.editing!.imagenUrl != null &&
                  _imagenBytes == null) ...[
                const SizedBox(width: 4),
                const Text('(foto actual)',
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.textMuted)),
              ],
            ]),
            const SizedBox(height: 4),
            Text('Etiquetar miembros',
                style: GoogleFonts.dmSans(
                    fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            miembrosAsync.when(
              loading: () => const SizedBox(
                  height: 36,
                  child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2))),
              error: (_, __) => const SizedBox.shrink(),
              data: (miembros) => miembros.isEmpty
                  ? const SizedBox.shrink()
                  : Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: miembros.map((m) {
                        final sel = _mencionados.containsKey(m.uid);
                        return FilterChip(
                          avatar:
                              SGAvatar(name: m.nombreCompleto, size: 18),
                          label: Text(m.nombreCompleto,
                              style: const TextStyle(fontSize: 12)),
                          selected: sel,
                          selectedColor: AppTheme.accentSoft,
                          checkmarkColor: AppTheme.accentInk,
                          onSelected: (v) => setState(() {
                            if (v) {
                              _mencionados[m.uid] = m.nombreCompleto;
                            } else {
                              _mencionados.remove(m.uid);
                            }
                          }),
                        );
                      }).toList(),
                    ),
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: gc,
              secondary: const Icon(Icons.checklist_rounded,
                  color: AppTheme.accent),
              title: const Text('Lista de asistencia tri-estado',
                  style: TextStyle(fontSize: 14)),
              subtitle: const Text('Voy · Tal vez · No voy',
                  style: TextStyle(fontSize: 11)),
              value: _tieneListado,
              onChanged: (v) => setState(() {
                _tieneListado = v;
                if (!v) _fechaEvento = null;
              }),
            ),
            // Fecha del evento — solo visible cuando hay lista de asistencia
            if (_tieneListado) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _fechaEvento ?? now.add(const Duration(days: 7)),
                    firstDate: now.subtract(const Duration(days: 365)),
                    lastDate: now.add(const Duration(days: 365 * 2)),
                    helpText: 'Fecha del evento',
                  );
                  if (picked != null) setState(() => _fechaEvento = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _fechaEvento != null
                          ? AppTheme.accent.withValues(alpha: 0.6)
                          : AppTheme.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.today_outlined,
                        size: 18,
                        color: _fechaEvento != null
                            ? AppTheme.accent
                            : AppTheme.textMuted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _fechaEvento != null
                              ? 'Evento el ${DateFormat('dd/MM/yyyy').format(_fechaEvento!)}'
                              : 'Fecha del evento (opcional)',
                          style: TextStyle(
                            fontSize: 14,
                            color: _fechaEvento != null
                                ? AppTheme.text
                                : AppTheme.textMuted,
                          ),
                        ),
                      ),
                      if (_fechaEvento != null)
                        GestureDetector(
                          onTap: () => setState(() => _fechaEvento = null),
                          child: const Icon(Icons.close_rounded,
                              size: 16, color: AppTheme.textMuted),
                        ),
                    ],
                  ),
                ),
              ),
            ],
            if (!_isEdit)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: gc,
                secondary: const Icon(Icons.chat_bubble_outline,
                    color: Color(0xFF25D366)),
                title: const Text('Notificar por WhatsApp',
                    style: TextStyle(fontSize: 14)),
                value: _notificarWhatsApp,
                onChanged: (v) =>
                    setState(() => _notificarWhatsApp = v),
              ),
            const SizedBox(height: 4),
            SGPillButton(
              icon: _isEdit
                  ? Icons.save_rounded
                  : Icons.send_rounded,
              label: isLoading
                  ? (_isEdit ? 'Guardando...' : 'Publicando...')
                  : (_isEdit ? 'Guardar' : 'Publicar'),
              expand: true,
              size: SGSize.md,
              onPressed: isLoading ? null : _guardar,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
