import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/sg_widgets.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/noticia_model.dart';
import '../../../providers/noticia_provider.dart';
import '../../../providers/grupo_provider.dart';

class DelegadoPanelPage extends ConsumerWidget {
  final String grupoId;
  const DelegadoPanelPage({super.key, required this.grupoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gc = ref.watch(grupoColorProvider(grupoId));
    final noticiasAsync = ref.watch(noticiasProvider(grupoId));
    final noticias = noticiasAsync.valueOrNull ?? [];

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            // â”€â”€ Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => context.pop(),
                    ),
                    Expanded(
                      child: Text(
                        'Panel Delegado',
                        style: GoogleFonts.bricolageGrotesque(
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                          letterSpacing: -0.3,
                          color: AppTheme.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // â”€â”€ Quick composer card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _QuickComposerCard(
                  gc: gc,
                  onTap: () => _showCrearNoticia(context, ref),
                ),
              ),
            ),

            // â”€â”€ Stats row
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: _StatPill(
                        label: 'Publicadas',
                        value: '${noticias.length}',
                        icon: Icons.newspaper_rounded,
                        color: gc,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatPill(
                        label: 'Fijadas',
                        value:
                            '${noticias.where((n) => n.fijada).length}',
                        icon: Icons.push_pin_rounded,
                        color: AppTheme.warning,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatPill(
                        label: 'Con lista',
                        value:
                            '${noticias.where((n) => n.tieneListado).length}',
                        icon: Icons.checklist_rounded,
                        color: AppTheme.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // â”€â”€ Noticias section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Row(
                  children: [
                    const SGEyebrow('Mis noticias'),
                    const Spacer(),
                    GestureDetector(
                      onTap: () =>
                          context.push('/group/$grupoId/noticias'),
                      child: Text(
                        'Ver todas →',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: gc,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (noticiasAsync.isLoading && !noticiasAsync.hasValue)
              const SliverToBoxAdapter(
                child: Center(
                    child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                )),
              )
            else if (noticias.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: _EmptyNoticias(
                    gc: gc,
                    onTap: () => _showCrearNoticia(context, ref),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                sliver: SliverList.separated(
                  itemCount: noticias.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _NoticiaDelegadoCard(
                    noticia: noticias[i],
                    grupoId: grupoId,
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCrearNoticia(context, ref),
        icon: const Icon(Icons.edit_rounded),
        label: const Text('Publicar noticia'),
        backgroundColor: gc,
        foregroundColor: Colors.white,
      ),
    );
  }

  void _showCrearNoticia(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _CrearNoticiaSheet(grupoId: grupoId),
    );
  }
}

// â”€â”€ Quick Composer Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _QuickComposerCard extends StatelessWidget {
  final Color gc;
  final VoidCallback onTap;
  const _QuickComposerCard({required this.gc, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: gc.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.edit_note_rounded,
                  size: 22, color: gc),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '¿Qué querés comunicar?',
                    style: GoogleFonts.bricolageGrotesque(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppTheme.text,
                    ),
                  ),
                  const Text(
                    'Publicá una noticia, aviso o convocatoria',
                    style:
                        TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: gc,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.add_rounded,
                  size: 18, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

// â”€â”€ Stat Pill â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatPill({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.bricolageGrotesque(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: AppTheme.text,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }
}

// â”€â”€ Empty Noticias â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _EmptyNoticias extends StatelessWidget {
  final Color gc;
  final VoidCallback onTap;
  const _EmptyNoticias({required this.gc, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: gc.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.newspaper_rounded,
                size: 28, color: gc),
          ),
          const SizedBox(height: 14),
          Text(
            'Todavía no publicaste nada',
            style: GoogleFonts.bricolageGrotesque(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AppTheme.text,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Usá el botón + para crear tu primera noticia',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 18),
          SGPillButton(
            label: 'Publicar noticia',
            icon: Icons.add_rounded,
            onPressed: onTap,
          ),
        ],
      ),
    );
  }
}

// â”€â”€ Noticia Delegado Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _NoticiaDelegadoCard extends ConsumerWidget {
  final NoticiaModel noticia;
  final String grupoId;
  const _NoticiaDelegadoCard({required this.noticia, required this.grupoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SGCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Category emoji in circle
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(noticia.categoria.emoji,
                    style: const TextStyle(fontSize: 16)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  noticia.titulo,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (noticia.fijada)
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(Icons.push_pin_rounded,
                      size: 14, color: AppTheme.warning),
                ),
              // Pin toggle
              GestureDetector(
                onTap: () => ref
                    .read(crearNoticiaProvider.notifier)
                    .toggleFijada(grupoId, noticia.id, !noticia.fijada),
                child: Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Icon(
                    noticia.fijada
                        ? Icons.push_pin
                        : Icons.push_pin_outlined,
                    size: 16,
                    color: noticia.fijada
                        ? AppTheme.warning
                        : AppTheme.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            noticia.contenido,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SGChip(
                icon: Icons.calendar_today_outlined,
                label:
                    '${noticia.createdAt.day}/${noticia.createdAt.month}/${noticia.createdAt.year}',
              ),
              if (noticia.tieneListado) ...[
                const SizedBox(width: 6),
                const SGChip(
                  icon: Icons.checklist_rounded,
                  label: 'Lista de asistencia',
                  tone: SGChipTone.accent,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// â”€â”€ Crear Noticia Sheet â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _CrearNoticiaSheet extends ConsumerStatefulWidget {
  final String grupoId;
  const _CrearNoticiaSheet({required this.grupoId});

  @override
  ConsumerState<_CrearNoticiaSheet> createState() =>
      _CrearNoticiaSheetState();
}

class _CrearNoticiaSheetState extends ConsumerState<_CrearNoticiaSheet> {
  final _tituloCtrl = TextEditingController();
  final _contenidoCtrl = TextEditingController();
  bool _tieneListado = false;
  NoticiaCategoria _categoria = NoticiaCategoria.general;

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _contenidoCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_tituloCtrl.text.isEmpty || _contenidoCtrl.text.isEmpty) return;
    try {
      await ref.read(crearNoticiaProvider.notifier).crear(
            grupoId: widget.grupoId,
            titulo: _tituloCtrl.text.trim(),
            contenido: _contenidoCtrl.text.trim(),
            tieneListado: _tieneListado,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gc = ref.watch(grupoColorProvider(widget.grupoId));
    final isLoading = ref.watch(crearNoticiaProvider).isLoading;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 20,
        right: 20,
        top: 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Center(
            child: Text(
              'Nueva noticia',
              style: GoogleFonts.bricolageGrotesque(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: AppTheme.text,
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _tituloCtrl,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Título',
              prefixIcon: Icon(Icons.title_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contenidoCtrl,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Contenido',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.article_outlined),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<NoticiaCategoria>(
            value: _categoria,
            decoration: const InputDecoration(labelText: 'Categoría'),
            items: NoticiaCategoria.values
                .map((c) => DropdownMenuItem(
                      value: c,
                      child: Text('${c.emoji} ${c.label}'),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _categoria = v ?? _categoria),
          ),
          const SizedBox(height: 4),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title:
                const Text('Lista de asistencia', style: TextStyle(fontSize: 14)),
            subtitle: const Text('Los miembros responden Voy / No voy',
                style: TextStyle(fontSize: 12)),
            value: _tieneListado,
            activeThumbColor: gc,
            onChanged: (v) => setState(() => _tieneListado = v),
          ),
          const SizedBox(height: 8),
          SGPillButton(
            label: 'Publicar noticia',
            icon: Icons.send_rounded,
            expand: true,
            onPressed: isLoading ? null : _guardar,
          ),
        ],
      ),
    );
  }
}
