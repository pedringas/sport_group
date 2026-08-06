import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/sg_widgets.dart';
import '../../../data/models/recurso_model.dart';
import '../../../data/models/enums.dart';
import '../../../providers/recurso_provider.dart';
import '../../../providers/grupo_provider.dart';

class RecursosTab extends ConsumerWidget {
  final String grupoId;
  const RecursosTab({super.key, required this.grupoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recursosAsync = ref.watch(recursosProvider(grupoId));
    final miembroAsync = ref.watch(miembroActualProvider(grupoId));
    final gc = ref.watch(grupoColorProvider(grupoId));
    final puedeGestionar =
        miembroAsync.valueOrNull?.rol.esAdmin == true ||
            miembroAsync.valueOrNull?.rol == RolMiembro.moderador ||
            miembroAsync.valueOrNull?.rol == RolMiembro.delegado;

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: SafeArea(
        bottom: false,
        child: recursosAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (e, _) => const SGErrorState(message: 'Error al cargar los recursos'),
          data: (recursos) {
            final links = recursos
                .where((r) => r.tipo == TipoRecurso.link)
                .toList();
            final archivos = recursos
                .where((r) => r.tipo == TipoRecurso.archivo)
                .toList();

            return CustomScrollView(
              slivers: [
                // â”€â”€ Header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                SliverToBoxAdapter(
                  child: _Header(
                    totalArchivos: recursos.length,
                    puedeGestionar: puedeGestionar,
                    gc: gc,
                    onAdd: () => _showAgregarRecurso(context, ref),
                  ),
                ),

                if (recursos.isEmpty)
                  SliverFillRemaining(
                    child: _EmptyRecursos(
                      puedeGestionar: puedeGestionar,
                      onAdd: () => _showAgregarRecurso(context, ref),
                    ),
                  )
                else ...[
                  // â”€â”€ Links (fijados style) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  if (links.isNotEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
                        child: SGEyebrow('ENLACES'),
                      ),
                    ),
                  if (links.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverGrid.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1.35,
                        children: links
                            .map((r) => _LinkTile(recurso: r, gc: gc))
                            .toList(),
                      ),
                    ),

                  // â”€â”€ Archivos (recent style) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  if (archivos.isNotEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
                        child: SGEyebrow('ARCHIVOS'),
                      ),
                    ),
                  if (archivos.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      sliver: SliverList.separated(
                        itemCount: archivos.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (_, i) =>
                            _ArchivoRow(recurso: archivos[i]),
                      ),
                    ),

                  // Bottom padding if only links
                  if (archivos.isEmpty)
                    const SliverToBoxAdapter(
                        child: SizedBox(height: 32)),
                ],
              ],
            );
          },
        ),
      ),
      floatingActionButton: puedeGestionar
          ? FloatingActionButton(
              onPressed: () => _showAgregarRecurso(context, ref),
              backgroundColor: gc,
              foregroundColor: gc.computeLuminance() > 0.3 ? Colors.black87 : Colors.white,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  void _showAgregarRecurso(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AgregarRecursoSheet(grupoId: grupoId),
    );
  }
}

// â”€â”€ Header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _Header extends StatelessWidget {
  final int totalArchivos;
  final bool puedeGestionar;
  final Color gc;
  final VoidCallback onAdd;
  const _Header({
    required this.totalArchivos,
    required this.puedeGestionar,
    required this.gc,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Recursos',
              style: GoogleFonts.bricolageGrotesque(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppTheme.text,
              ),
            ),
          ),
          if (totalArchivos > 0)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.surfaceAlt,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$totalArchivos ${totalArchivos == 1 ? "recurso" : "recursos"}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMuted,
                ),
              ),
            ),
          if (puedeGestionar) ...[
            const SizedBox(width: 4),
            IconButton(
              onPressed: onAdd,
              icon: const Icon(Icons.upload_outlined),
              color: gc,
              tooltip: 'Agregar recurso',
            ),
          ],
        ],
      ),
    );
  }
}

// â”€â”€ Link tile (2×2 grid style) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _LinkTile extends StatelessWidget {
  final RecursoModel recurso;
  final Color gc;
  const _LinkTile({required this.recurso, required this.gc});

  @override
  Widget build(BuildContext context) {
    // cycle icon bg between group color and accent
    final colors = [gc, AppTheme.accent];
    final bg = colors[recurso.titulo.length % 2];

    return GestureDetector(
      onTap: () => _open(context, recurso.url),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.border),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.link_rounded,
                      size: 20, color: Colors.white),
                ),
                const Spacer(),
                const Icon(Icons.open_in_new_rounded,
                    size: 14, color: AppTheme.textMuted),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              recurso.titulo,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                height: 1.3,
                color: AppTheme.text,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              recurso.descripcion ??
                  DateFormat('dd/MM/yy').format(recurso.createdAt),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
        webOnlyWindowName: '_blank',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir el enlace: $e')),
        );
      }
    }
  }
}

// â”€â”€ Archivo row (recent files style) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _ArchivoRow extends StatelessWidget {
  final RecursoModel recurso;
  const _ArchivoRow({required this.recurso});

  static Color _iconColor(String? nombre) {
    if (nombre == null) return AppTheme.accent;
    final ext = nombre.split('.').last.toLowerCase();
    if (ext == 'pdf') return AppTheme.danger;
    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) return AppTheme.good;
    if (['doc', 'docx', 'txt'].contains(ext)) return AppTheme.accent;
    if (['xls', 'xlsx', 'csv'].contains(ext)) return AppTheme.good;
    return AppTheme.accent;
  }

  static IconData _iconData(String? nombre) {
    if (nombre == null) return Icons.insert_drive_file_rounded;
    final ext = nombre.split('.').last.toLowerCase();
    if (ext == 'pdf') return Icons.picture_as_pdf_rounded;
    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) return Icons.image_rounded;
    if (['doc', 'docx', 'txt'].contains(ext)) return Icons.description_rounded;
    if (['xls', 'xlsx', 'csv'].contains(ext)) return Icons.table_chart_rounded;
    return Icons.insert_drive_file_rounded;
  }

  static Future<void> openUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    try {
      // Use platformDefault + _blank so it opens in a new browser tab on web
      // (LaunchMode.externalApplication is not supported on Flutter Web)
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
        webOnlyWindowName: '_blank',
      );
      if (!launched) throw Exception('No se pudo abrir');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir el archivo: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _iconColor(recurso.nombreArchivo);
    final icon = _iconData(recurso.nombreArchivo);
    final meta =
        '${recurso.autorNombre} · ${DateFormat('dd/MM/yy').format(recurso.createdAt)}';

    return GestureDetector(
      onTap: () => _showPreview(context),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recurso.titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppTheme.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    meta,
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            // Download / open button ”” separate from the row tap so it works
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => openUrl(context, recurso.url),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Icon(Icons.download_rounded,
                    size: 20, color: AppTheme.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPreview(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ArchivoInfoSheet(recurso: recurso),
    );
  }
}

// â”€â”€ Archivo info sheet â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _ArchivoInfoSheet extends StatelessWidget {
  final RecursoModel recurso;
  const _ArchivoInfoSheet({required this.recurso});

  static bool _esImagen(String? nombre) {
    if (nombre == null) return false;
    return ['jpg', 'jpeg', 'png', 'gif', 'webp']
        .contains(nombre.split('.').last.toLowerCase());
  }

  static Color _iconColor(String? nombre) {
    if (nombre == null) return AppTheme.accent;
    final ext = nombre.split('.').last.toLowerCase();
    if (ext == 'pdf') return AppTheme.danger;
    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) return AppTheme.good;
    if (['doc', 'docx', 'txt'].contains(ext)) return AppTheme.accent;
    if (['xls', 'xlsx', 'csv'].contains(ext)) return AppTheme.good;
    return AppTheme.accent;
  }

  static IconData _iconData(String? nombre) {
    if (nombre == null) return Icons.insert_drive_file_rounded;
    final ext = nombre.split('.').last.toLowerCase();
    if (ext == 'pdf') return Icons.picture_as_pdf_rounded;
    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) return Icons.image_rounded;
    if (['doc', 'docx', 'txt'].contains(ext)) return Icons.description_rounded;
    if (['xls', 'xlsx', 'csv'].contains(ext)) return Icons.table_chart_rounded;
    return Icons.insert_drive_file_rounded;
  }

  Future<void> _abrir(BuildContext context) =>
      _ArchivoRow.openUrl(context, recurso.url);

  void _copiarLink(BuildContext context) {
    Clipboard.setData(ClipboardData(text: recurso.url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copiado al portapapeles')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final esImagen = _esImagen(recurso.nombreArchivo);
    final color = _iconColor(recurso.nombreArchivo);
    final icon = _iconData(recurso.nombreArchivo);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // â”€â”€ Image preview (if applicable)
        if (esImagen)
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
            child: CachedNetworkImage(
              imageUrl: recurso.url,
              width: double.infinity,
              height: 220,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(
                height: 220,
                color: AppTheme.surfaceAlt,
                child: const Center(
                  child: Icon(Icons.broken_image_rounded,
                      size: 40, color: AppTheme.textMuted),
                ),
              ),
              placeholder: (_, __) => Container(
                      height: 220,
                      color: AppTheme.surfaceAlt,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
            ),
          ),

        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.borderStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // File icon + title row
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, size: 24, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          recurso.titulo,
                          style: GoogleFonts.bricolageGrotesque(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: AppTheme.text,
                            letterSpacing: -0.2,
                          ),
                        ),
                        if (recurso.nombreArchivo != null)
                          Text(
                            recurso.nombreArchivo!,
                            style: const TextStyle(
                                fontSize: 11, color: AppTheme.textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Metadata row
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _MetaItem(
                      icon: Icons.person_outline_rounded,
                      label: recurso.autorNombre,
                    ),
                    const SizedBox(width: 16),
                    _MetaItem(
                      icon: Icons.calendar_today_outlined,
                      label: DateFormat('dd/MM/yyyy').format(recurso.createdAt),
                    ),
                  ],
                ),
              ),

              if (recurso.descripcion != null &&
                  recurso.descripcion!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.notes_rounded,
                          size: 14, color: AppTheme.textMuted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          recurso.descripcion!,
                          style: const TextStyle(
                              fontSize: 13, color: AppTheme.textMuted),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Primary action — open in new tab
              FilledButton.icon(
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('Abrir archivo'),
                onPressed: () => _abrir(context),
              ),

              const SizedBox(height: 10),

              // Download action — same URL, browser handles download
              OutlinedButton.icon(
                icon: const Icon(Icons.download_rounded, size: 16),
                label: const Text('Descargar'),
                onPressed: () => _abrir(context),
              ),

              const SizedBox(height: 10),

              // Copy link
              OutlinedButton.icon(
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copiar link'),
                onPressed: () => _copiarLink(context),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// â”€â”€ Meta item helper â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _MetaItem extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppTheme.textMuted),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
        ),
      ],
    );
  }
}

// â”€â”€ Empty state â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _EmptyRecursos extends StatelessWidget {
  final bool puedeGestionar;
  final VoidCallback onAdd;
  const _EmptyRecursos(
      {required this.puedeGestionar, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.surfaceAlt,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.folder_open_rounded,
                  size: 36, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 16),
            Text(
              'Sin recursos aún',
              style: GoogleFonts.bricolageGrotesque(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.text,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              puedeGestionar
                  ? 'Sube archivos y comparte enlaces útiles\npara todos los miembros'
                  : 'Los administradores pueden subir archivos\ny compartir enlaces aquí',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13, color: AppTheme.textMuted, height: 1.5),
            ),
            if (puedeGestionar) ...[
              const SizedBox(height: 24),
              SGPillButton(
                label: 'Agregar recurso',
                icon: Icons.add_rounded,
                onPressed: onAdd,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// â”€â”€ Agregar recurso sheet â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _AgregarRecursoSheet extends ConsumerStatefulWidget {
  final String grupoId;
  const _AgregarRecursoSheet({required this.grupoId});

  @override
  ConsumerState<_AgregarRecursoSheet> createState() =>
      _AgregarRecursoSheetState();
}

class _AgregarRecursoSheetState
    extends ConsumerState<_AgregarRecursoSheet> {
  final _tituloCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  TipoRecurso _tipo = TipoRecurso.link;
  Uint8List? _archivoBytes;
  String? _archivoNombre;

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _urlCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      setState(() {
        _archivoBytes = file.bytes;
        _archivoNombre = file.name;
        if (_tituloCtrl.text.isEmpty) {
          _tituloCtrl.text = file.name;
        }
      });
    }
  }

  Future<void> _guardar() async {
    if (_tituloCtrl.text.isEmpty) return;
    try {
      if (_tipo == TipoRecurso.link) {
        if (_urlCtrl.text.isEmpty) return;
        await ref.read(crearRecursoProvider.notifier).crearLink(
              grupoId: widget.grupoId,
              titulo: _tituloCtrl.text.trim(),
              url: _urlCtrl.text.trim(),
              descripcion: _descCtrl.text.trim().isEmpty
                  ? null
                  : _descCtrl.text.trim(),
            );
      } else {
        if (_archivoBytes == null || _archivoNombre == null) return;
        await ref.read(crearRecursoProvider.notifier).crearArchivo(
              grupoId: widget.grupoId,
              titulo: _tituloCtrl.text.trim(),
              nombreArchivo: _archivoNombre!,
              bytes: _archivoBytes!,
              descripcion: _descCtrl.text.trim().isEmpty
                  ? null
                  : _descCtrl.text.trim(),
            );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(crearRecursoProvider).isLoading;
    final gc = ref.watch(grupoColorProvider(widget.grupoId));

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Text(
              'Agregar recurso',
              style: GoogleFonts.bricolageGrotesque(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.text,
              ),
            ),
            const SizedBox(height: 20),

            // Tipo pills
            Row(
              children: [
                _TypePill(
                  label: 'Enlace',
                  icon: Icons.link_rounded,
                  selected: _tipo == TipoRecurso.link,
                  gc: gc,
                  onTap: () => setState(() => _tipo = TipoRecurso.link),
                ),
                const SizedBox(width: 8),
                _TypePill(
                  label: 'Archivo',
                  icon: Icons.upload_file_rounded,
                  selected: _tipo == TipoRecurso.archivo,
                  gc: gc,
                  onTap: () =>
                      setState(() => _tipo = TipoRecurso.archivo),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // URL o file picker
            if (_tipo == TipoRecurso.link)
              TextField(
                controller: _urlCtrl,
                decoration: const InputDecoration(
                  labelText: 'URL del enlace',
                  hintText: 'https://',
                  prefixIcon: Icon(Icons.link_rounded),
                ),
                keyboardType: TextInputType.url,
              )
            else
              GestureDetector(
                onTap: _pickFile,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _archivoNombre != null
                          ? gc
                          : AppTheme.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.upload_file_rounded,
                        color: _archivoNombre != null
                            ? gc
                            : AppTheme.textMuted,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _archivoNombre ?? 'Seleccionar archivo',
                          style: TextStyle(
                            color: _archivoNombre != null
                                ? AppTheme.text
                                : AppTheme.textMuted,
                            fontWeight: _archivoNombre != null
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),

            TextField(
              controller: _tituloCtrl,
              decoration: const InputDecoration(
                labelText: 'Título',
                prefixIcon: Icon(Icons.label_outline_rounded),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: 24),

            SGPillButton(
              label: isLoading ? 'Guardando…' : 'Guardar recurso',
              icon: Icons.check_rounded,
              onPressed: isLoading ? null : _guardar,
              expand: true,
            ),
          ],
        ),
      ),
    );
  }
}

// â”€â”€ Type pill â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _TypePill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color gc;
  final VoidCallback onTap;
  const _TypePill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.gc,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? gc : AppTheme.surfaceAlt,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? gc : AppTheme.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color:
                    selected ? Colors.white : AppTheme.textMuted),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
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
