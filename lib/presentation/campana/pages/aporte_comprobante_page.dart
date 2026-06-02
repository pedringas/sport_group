import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/sg_widgets.dart';
import '../../../data/models/enums.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/campana_provider.dart';
import '../../../providers/grupo_provider.dart';

class AporteComprobantePage extends ConsumerStatefulWidget {
  final String grupoId;
  final String campanaId;
  final String campanaTitle;
  final double monto;
  final String? mensaje;

  const AporteComprobantePage({
    super.key,
    required this.grupoId,
    required this.campanaId,
    required this.campanaTitle,
    required this.monto,
    this.mensaje,
  });

  @override
  ConsumerState<AporteComprobantePage> createState() =>
      _AporteComprobantePageState();
}

class _AporteComprobantePageState
    extends ConsumerState<AporteComprobantePage> {
  Uint8List? _bytes;
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

  Future<void> _pick(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _bytes = bytes;
        _fileName = picked.name;
        _fileSizeKb = (bytes.lengthInBytes / 1024).round();
      });
    }
  }

  Future<void> _enviar() async {
    if (_bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Seleccioná un comprobante')));
      return;
    }
    setState(() => _loading = true);

    try {
      final user = ref.read(authStateProvider).valueOrNull!;
      final perfil = await ref.read(authRepositoryProvider).getUser(user.uid);
      final nombre = perfil?.nombreCompleto ?? user.displayName ?? 'Usuario';

      // 1. Create aporte doc as 'pendiente'
      final aporteId = await ref
          .read(campanaRepositoryProvider)
          .addAportePendiente(
            grupoId: widget.grupoId,
            campanaId: widget.campanaId,
            usuarioUid: user.uid,
            usuarioNombre: nombre,
            monto: widget.monto,
            mensaje: widget.mensaje,
            metodo: 'transferencia',
          );

      // 2. Upload comprobante ”” path triggers Cloud Function OCR
      final storageRef = FirebaseStorage.instance.ref(
          'grupos/${widget.grupoId}/aportes_comprobantes/$aporteId.jpg');
      await storageRef.putData(
          _bytes!, SettableMetadata(contentType: 'image/jpeg'));
      final url = await storageRef.getDownloadURL();

      // 3. Update aporte with URL + estado: validando (OCR en proceso)
      final aporteRef = FirebaseFirestore.instance
          .collection('grupos')
          .doc(widget.grupoId)
          .collection('campanas')
          .doc(widget.campanaId)
          .collection('aportes')
          .doc(aporteId);

      final extra = <String, dynamic>{
        'comprobanteUrl': url,
        'estado': EstadoAporte.validando.name,
      };
      if (_bancoCtrl.text.trim().isNotEmpty) {
        extra['bancoOrigen'] = _bancoCtrl.text.trim();
      }
      if (_opCtrl.text.trim().isNotEmpty) {
        extra['nroOperacion'] = _opCtrl.text.trim();
      }
      await aporteRef.update(extra);

      if (mounted) {
        await _showConfirmacion();
        if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
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

  Future<void> _showConfirmacion() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: AppTheme.bg(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 120,
                height: 120,
                decoration: const BoxDecoration(
                  color: AppTheme.goodSoft,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Container(
                    width: 80,
                    height: 80,
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
                'Estamos verificando tu transferencia.\nEl tesorero recibirá una notificación\nsi necesita revisarlo manualmente.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppTheme.textMuted, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 28),
              SGPillButton(
                icon: Icons.check_rounded,
                label: 'Entendido',
                expand: true,
                onPressed: () => Navigator.of(ctx).pop(),
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
    final hasFile = _bytes != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subir comprobante'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 140),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // â”€â”€ Campaign + monto summary
            SGCard(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  SGIconTile(
                    icon: Icons.favorite_rounded,
                    background: gc.withValues(alpha: 0.12),
                    iconColor: gc,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.campanaTitle,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: AppTheme.text,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Aporte: \$${widget.monto.toStringAsFixed(0)}',
                          style: const TextStyle(
                              color: AppTheme.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.check_circle, color: AppTheme.good),
                ],
              ),
            ),

            const SizedBox(height: 16),
            const SGEyebrow('Foto del comprobante'),

            // â”€â”€ Upload zone
            _UploadZone(
              bytes: _bytes,
              fileName: _fileName,
              fileSizeKb: _fileSizeKb,
              gc: gc,
              onPick: () => _pick(ImageSource.gallery),
              onClear: () => setState(() {
                _bytes = null;
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
                    onTap: () => _pick(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _AltAction(
                    icon: Icons.photo_library_outlined,
                    label: 'Elegir foto',
                    gc: gc,
                    onTap: () => _pick(ImageSource.gallery),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const SGEyebrow('Datos opcionales'),

            SGCard(
              padding: const EdgeInsets.all(4),
              child: Column(
                children: [
                  _FormRow(
                    label: 'Banco / billetera origen',
                    controller: _bancoCtrl,
                    hint: 'p. ej. Mercado Pago, Banco Galicia',
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
                ],
              ),
            ),

            const SizedBox(height: 14),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.auto_awesome_rounded,
                    size: 14, color: AppTheme.textMuted),
                SizedBox(width: 4),
                Text(
                  'Verificación automática del comprobante',
                  style: TextStyle(
                      color: AppTheme.textMuted, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
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
            label: _loading ? 'Enviando...' : 'Enviar al tesorero',
            expand: true,
            size: SGSize.lg,
            onPressed: (_loading || !hasFile) ? null : _enviar,
          ),
        ),
      ),
    );
  }
}

// â”€â”€ Upload zone â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
              child: Image.memory(bytes!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover),
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
                '${fileSizeKb!} KB · Listo para enviar',
                style: const TextStyle(
                    color: AppTheme.textMuted, fontSize: 11),
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

// â”€â”€ Alt action button â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _AltAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color gc;
  final VoidCallback onTap;
  const _AltAction(
      {required this.icon, required this.label, required this.gc, required this.onTap});

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
                      fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// â”€â”€ Form row â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
              hintStyle: const TextStyle(
                  color: AppTheme.textMuted, fontSize: 14),
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
