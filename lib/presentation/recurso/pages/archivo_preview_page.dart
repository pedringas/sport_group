import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/sg_widgets.dart';
import '../../../data/models/recurso_model.dart';
import '../../../providers/recurso_provider.dart';

class ArchivoPreviewPage extends ConsumerWidget {
  final String grupoId;
  final String recursoId;

  const ArchivoPreviewPage({
    super.key,
    required this.grupoId,
    required this.recursoId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recursosAsync = ref.watch(recursosProvider(grupoId));

    return recursosAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(child: Text('Error: $e')),
      ),
      data: (recursos) {
        final recurso = recursos.cast<RecursoModel?>().firstWhere(
              (r) => r?.id == recursoId,
              orElse: () => null,
            );

        if (recurso == null) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () => context.pop(),
              ),
            ),
            body: const Center(child: Text('Archivo no encontrado')),
          );
        }

        return _RecursoView(recurso: recurso);
      },
    );
  }
}

class _RecursoView extends StatelessWidget {
  final RecursoModel recurso;
  const _RecursoView({required this.recurso});

  Future<void> _openUrl(BuildContext context) async {
    final uri = Uri.parse(recurso.url);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
        webOnlyWindowName: '_blank',
      );
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el archivo')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al abrir: $e')),
        );
      }
    }
  }

  Future<void> _copyLink(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: recurso.url));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link copiado ✓')),
      );
    }
  }

  IconData get _fileIcon {
    if (recurso.tipo == TipoRecurso.link) return Icons.link_rounded;
    final ext = recurso.titulo.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'doc':
      case 'docx':
        return Icons.description_rounded;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart_rounded;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Color get _fileColor {
    if (recurso.tipo == TipoRecurso.link) return AppTheme.primary;
    final ext = recurso.titulo.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return const Color(0xFFDC2626);
      case 'doc':
      case 'docx':
        return const Color(0xFF2563EB);
      case 'xls':
      case 'xlsx':
        return const Color(0xFF16A34A);
      default:
        return AppTheme.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        backgroundColor: AppTheme.bg(context),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              recurso.titulo,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              recurso.tipo == TipoRecurso.link ? 'Enlace web' : 'Archivo',
              style: const TextStyle(
                  fontSize: 11, color: AppTheme.textMuted),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            onPressed: () => _openUrl(context),
            tooltip: 'Abrir / descargar',
          ),
          IconButton(
            icon: const Icon(Icons.link_rounded),
            onPressed: () => _copyLink(context),
            tooltip: 'Copiar link',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(),

            // File icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: _fileColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(_fileIcon, size: 52, color: _fileColor),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              recurso.titulo,
              style: GoogleFonts.bricolageGrotesque(
                fontWeight: FontWeight.w700,
                fontSize: 20,
                letterSpacing: -0.3,
                color: AppTheme.text,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Description
            if (recurso.descripcion != null &&
                recurso.descripcion!.isNotEmpty) ...[
              Text(
                recurso.descripcion!,
                style: const TextStyle(
                    fontSize: 14, color: AppTheme.textMuted, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
            ],

            // Author + date
            Text(
              'Subido por ${recurso.autorNombre}',
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.textMuted),
            ),

            const Spacer(),

            // Open button
            SGPillButton(
              icon: recurso.tipo == TipoRecurso.link
                  ? Icons.open_in_new_rounded
                  : Icons.download_rounded,
              label: recurso.tipo == TipoRecurso.link
                  ? 'Abrir enlace'
                  : 'Abrir archivo',
              expand: true,
              size: SGSize.lg,
              onPressed: () => _openUrl(context),
            ),
            const SizedBox(height: 12),

            // Copy link
            OutlinedButton.icon(
              onPressed: () => _copyLink(context),
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Copiar link'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
