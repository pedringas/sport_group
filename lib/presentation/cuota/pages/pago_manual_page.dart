import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/sg_widgets.dart';
import '../../../providers/cuota_provider.dart';
import '../../../providers/grupo_provider.dart';
import '../../../providers/auth_provider.dart';

class PagoManualPage extends ConsumerStatefulWidget {
  final String grupoId;
  final String cuotaId;
  const PagoManualPage({
    super.key,
    required this.grupoId,
    required this.cuotaId,
  });

  @override
  ConsumerState<PagoManualPage> createState() => _PagoManualPageState();
}

class _PagoManualPageState extends ConsumerState<PagoManualPage> {
  Uint8List? _comprobanteBytes;
  String? _fileName;
  int? _fileSizeKb;
  bool _loading = false;

  final _bancoCtrl = TextEditingController();
  final _opCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();

  @override
  void dispose() {
    _bancoCtrl.dispose();
    _opCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickComprobante({required ImageSource source}) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _comprobanteBytes = bytes;
        _fileName = picked.name;
        _fileSizeKb = (bytes.lengthInBytes / 1024).round();
      });
    }
  }

  Future<void> _enviar() async {
    if (_comprobanteBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Seleccioná un comprobante')));
      return;
    }
    setState(() => _loading = true);

    try {
      final user = ref.read(authStateProvider).valueOrNull!;
      final userData = await ref.read(currentUserProvider.future);
      final cuota = await ref
          .read(cuotaRepositoryProvider)
          .getCuota(widget.grupoId, widget.cuotaId);

      final pagoId = await ref.read(cuotaRepositoryProvider).initPagoManual(
            grupoId: widget.grupoId,
            cuotaId: widget.cuotaId,
            usuarioUid: user.uid,
            usuarioNombre: userData?.nombreCompleto ?? '',
            monto: cuota?.monto ?? 0,
          );

      // Upload comprobante — triggers Cloud Function OCR
      await ref.read(cuotaRepositoryProvider).uploadComprobante(
            pagoId: pagoId,
            grupoId: widget.grupoId,
            bytes: _comprobanteBytes!,
            bancoOrigen: _bancoCtrl.text.trim().isNotEmpty
                ? _bancoCtrl.text.trim()
                : null,
            nroOperacion: _opCtrl.text.trim().isNotEmpty
                ? _opCtrl.text.trim()
                : null,
            mensajeAlTesorero: _msgCtrl.text.trim().isNotEmpty
                ? _msgCtrl.text.trim()
                : null,
          );

      if (mounted) {
        // Push a clean confirmation screen instead of just a snackbar.
        await _showConfirmationSheet();
        if (mounted) context.go('/group/${widget.grupoId}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppTheme.danger,
        ));
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _showConfirmationSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: AppTheme.bg(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetCtx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 120, height: 120,
                decoration: const BoxDecoration(
                  color: AppTheme.goodSoft,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Container(
                    width: 80, height: 80,
                    decoration: const BoxDecoration(
                      color: AppTheme.good,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded,
                        color: Colors.white, size: 48),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '¡Comprobante\nenviado!',
                textAlign: TextAlign.center,
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                  letterSpacing: -0.5,
                  color: AppTheme.text,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'El administrador lo va a revisar y te llega\nuna notificación cuando lo confirme.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textMuted, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 28),
              SGPillButton(
                icon: Icons.home_rounded,
                label: 'Volver al inicio',
                expand: true,
                onPressed: () => Navigator.of(sheetCtx).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gc = ref.watch(grupoColorProvider(widget.grupoId));
    final hasFile = _comprobanteBytes != null;

    final isDesktop = MediaQuery.sizeOf(context).width >= AppTheme.kResponsiveBreakpoint;
    return Scaffold(
      appBar: isDesktop ? null : AppBar(
        title: const Text('Subir comprobante'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 140),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // â”€â”€ Cuota summary
            SGCard(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  SGIconTile(
                    icon: Icons.payments_rounded,
                    background: gc.withValues(alpha: 0.12),
                    iconColor: gc,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Cuota seleccionada',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppTheme.text,
                            )),
                        Text('Adjuntá tu comprobante de transferencia',
                            style: TextStyle(
                                color: AppTheme.textMuted, fontSize: 11)),
                      ],
                    ),
                  ),
                  const Icon(Icons.check_circle, color: AppTheme.good),
                ],
              ),
            ),

            // â”€â”€ Upload zone
            const SGEyebrow('Captura / foto del comprobante'),
            _UploadZone(
              bytes: _comprobanteBytes,
              fileName: _fileName,
              fileSizeKb: _fileSizeKb,
              gc: gc,
              onPick: () => _pickComprobante(source: ImageSource.gallery),
              onClear: () => setState(() {
                _comprobanteBytes = null;
                _fileName = null;
                _fileSizeKb = null;
              }),
            ),

            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _AltAction(
                    icon: Icons.photo_camera_outlined,
                    label: 'Tomar foto',
                    gc: gc,
                    onTap: () => _pickComprobante(source: ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _AltAction(
                    icon: Icons.photo_library_outlined,
                    label: 'Elegir foto',
                    gc: gc,
                    onTap: () => _pickComprobante(source: ImageSource.gallery),
                  ),
                ),
              ],
            ),

            // â”€â”€ Datos opcionales
            const SGEyebrow('Datos opcionales'),
            SGCard(
              padding: const EdgeInsets.all(4),
              child: Column(
                children: [
                  _FormRow(
                    label: 'Banco origen',
                    controller: _bancoCtrl,
                    hint: 'p. ej. Banco Galicia',
                  ),
                  const Divider(height: 1),
                  _FormRow(
                    label: 'NÂº de operación',
                    controller: _opCtrl,
                    hint: 'opcional',
                    monospace: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                  const Divider(height: 1),
                  _FormRow(
                    label: 'Mensaje al administrador',
                    controller: _msgCtrl,
                    hint: 'Hola, pagué la cuota de mayo...',
                    maxLines: 3,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline_rounded, size: 14, color: AppTheme.textMuted),
                SizedBox(width: 4),
                Text(
                  'Solo el administrador ve tu comprobante.',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),

      // Sticky CTA
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: const BoxDecoration(
            color: AppTheme.background,
            border: Border(top: BorderSide(color: AppTheme.border)),
          ),
          child: SGPillButton(
            icon: _loading ? null : Icons.send_rounded,
            label: _loading ? 'Enviando...' : 'Enviar comprobante',
            expand: true,
            size: SGSize.lg,
            onPressed: (_loading || !hasFile) ? null : _enviar,
          ),
        ),
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _UploadZone extends StatelessWidget {
  final Uint8List? bytes;
  final String? fileName;
  final int? fileSizeKb;
  final Color gc;
  final VoidCallback onPick;
  final VoidCallback onClear;

  const _UploadZone({
    required this.bytes,
    required this.fileName,
    required this.fileSizeKb,
    required this.gc,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    if (bytes != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: gc.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                bytes!,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              fileName ?? 'comprobante.jpg',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: gc,
                fontSize: 13,
              ),
            ),
            if (fileSizeKb != null)
              Text(
                '${fileSizeKb!.toString()} KB · Listo para enviar',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
              ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SGPillButton(
                  label: 'Cambiar',
                  tone: SGTone.outline,
                  size: SGSize.sm,
                  onPressed: onPick,
                ),
                const SizedBox(width: 8),
                SGPillButton(
                  label: 'Eliminar',
                  tone: SGTone.outline,
                  size: SGSize.sm,
                  onPressed: onClear,
                ),
              ],
            ),
          ],
        ),
      );
    }
    return GestureDetector(
      onTap: onPick,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: gc.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: gc,
              width: 2,
              strokeAlign: BorderSide.strokeAlignInside),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined,
                size: 36, color: gc),
            const SizedBox(height: 10),
            Text(
              'Tocá para subir tu comprobante',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: gc,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'JPG o PNG · hasta 8 MB',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _AltAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color gc;
  final VoidCallback onTap;
  const _AltAction({required this.icon, required this.label, required this.gc, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              Icon(icon, color: gc),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormRow extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController controller;
  final bool monospace;
  final int maxLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  const _FormRow({
    required this.label,
    required this.controller,
    this.hint,
    this.monospace = false,
    this.maxLines = 1,
    this.keyboardType,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppTheme.textMuted,
              letterSpacing: 0.6,
            ),
          ),
          TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            style: TextStyle(
              fontFamily: monospace ? 'monospace' : null,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
              isDense: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: const EdgeInsets.symmetric(vertical: 6),
            ),
          ),
        ],
      ),
    );
  }
}
