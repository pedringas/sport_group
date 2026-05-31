import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/sg_widgets.dart';
import '../../../data/models/noticia_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/grupo_provider.dart';
import '../../../providers/noticia_provider.dart';

class ComentariosPage extends ConsumerStatefulWidget {
  final String grupoId;
  final String noticiaId;
  final String noticiaTitle;

  const ComentariosPage({
    super.key,
    required this.grupoId,
    required this.noticiaId,
    required this.noticiaTitle,
  });

  @override
  ConsumerState<ComentariosPage> createState() => _ComentariosPageState();
}

class _ComentariosPageState extends ConsumerState<ComentariosPage> {
  final _commentCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;

  NoticiaKey get _key =>
      (grupoId: widget.grupoId, noticiaId: widget.noticiaId);

  @override
  void dispose() {
    _commentCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(crearNoticiaProvider.notifier).addComentario(
            grupoId: widget.grupoId,
            noticiaId: widget.noticiaId,
            texto: text,
          );
      _commentCtrl.clear();
      // Scroll to bottom after sending
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _deleteComentario(String comentarioId) async {
    try {
      await ref.read(crearNoticiaProvider.notifier).deleteComentario(
            widget.grupoId,
            widget.noticiaId,
            comentarioId,
          );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final gc = ref.watch(grupoColorProvider(widget.grupoId));
    final comentariosAsync = ref.watch(comentariosProvider(_key));
    final currentUid = ref.watch(authStateProvider).valueOrNull?.uid ?? '';
    final currentUserName =
        ref.watch(currentUserProvider).valueOrNull?.nombreCompleto ?? '';

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        backgroundColor: AppTheme.bg(context),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        title: comentariosAsync.when(
          data: (list) => Text(
            '${list.length} comentario${list.length == 1 ? '' : 's'}',
            style: GoogleFonts.bricolageGrotesque(
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: AppTheme.text,
            ),
          ),
          loading: () => Text(
            'Comentarios',
            style: GoogleFonts.bricolageGrotesque(
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: AppTheme.text,
            ),
          ),
          error: (_, __) => Text(
            'Comentarios',
            style: GoogleFonts.bricolageGrotesque(
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: AppTheme.text,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // â”€â”€ Noticia preview â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.surfaceAlt,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.newspaper_rounded,
                    size: 18, color: AppTheme.textMuted),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Comentando en:',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.textMuted),
                      ),
                      Text(
                        widget.noticiaTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // â”€â”€ Comments list â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Expanded(
            child: comentariosAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          size: 40, color: AppTheme.textMuted),
                      const SizedBox(height: 12),
                      Text(
                        'No se pudieron cargar los comentarios',
                        style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () =>
                            ref.invalidate(comentariosProvider(_key)),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (comentarios) {
                if (comentarios.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceAlt,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.chat_bubble_outline_rounded,
                              size: 26, color: AppTheme.textMuted),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Sé el primero en comentar',
                          style: TextStyle(
                              fontSize: 14, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: comentarios.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final c = comentarios[i];
                    final isOwn = c.uid == currentUid;
                    return _CommentCard(
                      comentario: c,
                      gc: gc,
                      isOwn: isOwn,
                      onDelete: isOwn
                          ? () => _deleteComentario(c.id)
                          : null,
                    );
                  },
                );
              },
            ),
          ),

          // â”€â”€ Composer â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                border: Border(top: BorderSide(color: AppTheme.border)),
              ),
              child: Row(
                children: [
                  SGAvatar(
                    name: currentUserName.isEmpty ? '?' : currentUserName,
                    size: 32,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceAlt,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: TextField(
                        controller: _commentCtrl,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Sumá un comentario...',
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: const TextStyle(fontSize: 13),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        maxLines: null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sending ? null : _send,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _sending
                            ? gc.withValues(alpha: 0.4)
                            : gc,
                        shape: BoxShape.circle,
                      ),
                      child: _sending
                          ? const Padding(
                              padding: EdgeInsets.all(10),
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white),
                            )
                          : const Icon(Icons.send_rounded,
                              size: 18, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// â”€â”€ Comment card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _CommentCard extends StatelessWidget {
  final ComentarioModel comentario;
  final Color gc;
  final bool isOwn;
  final VoidCallback? onDelete;

  const _CommentCard({
    required this.comentario,
    required this.gc,
    required this.isOwn,
    this.onDelete,
  });

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays >= 1) return 'hace ${diff.inDays}d';
    if (diff.inHours >= 1) return 'hace ${diff.inHours}h';
    if (diff.inMinutes >= 1) return 'hace ${diff.inMinutes}min';
    return 'ahora';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SGAvatar(
          name: comentario.nombre,
          imageUrl: comentario.avatarUrl,
          size: 34,
          background: isOwn ? gc : AppTheme.surfaceAlt,
          foreground: isOwn ? Colors.white : AppTheme.text,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: isOwn
                      ? gc.withValues(alpha: 0.08)
                      : AppTheme.surface,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(4),
                    topRight: const Radius.circular(16),
                    bottomLeft: const Radius.circular(16),
                    bottomRight: const Radius.circular(16),
                  ),
                  border: Border.all(
                    color: isOwn
                        ? gc.withValues(alpha: 0.2)
                        : AppTheme.border,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isOwn ? 'Vos' : comentario.nombre,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: isOwn ? gc : AppTheme.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      comentario.texto,
                      style: const TextStyle(fontSize: 14, height: 1.45),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    _timeAgo(comentario.createdAt),
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textMuted),
                  ),
                  if (onDelete != null) ...[
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: onDelete,
                      child: const Text(
                        'Eliminar',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.danger,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
