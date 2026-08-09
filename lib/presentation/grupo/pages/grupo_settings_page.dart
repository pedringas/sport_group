import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/nav_ext.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/sg_widgets.dart';
import '../../../providers/grupo_provider.dart';
import '../../../data/models/solicitud_union_model.dart';
import '../../../data/models/enums.dart';
import '../widgets/abandonar_dialog.dart';

// â”€â”€ Default group color â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
const _kDefaultGroupColor = Color(0xFFE2693F);

class GrupoSettingsPage extends ConsumerStatefulWidget {
  final String grupoId;
  const GrupoSettingsPage({super.key, required this.grupoId});

  @override
  ConsumerState<GrupoSettingsPage> createState() =>
      _GrupoSettingsPageState();
}

class _GrupoSettingsPageState extends ConsumerState<GrupoSettingsPage> {
  bool _uploadingLogo = false;
  bool _uploadingPortada = false;
  bool _aprobacionManual = true;
  bool _anunciosPush = true;
  bool _whatsappIntegration = false;

  /// Locally-selected color before the Firestore stream confirms it, giving
  /// instant visual feedback.
  String? _pendingColor;

  // â”€â”€ Logo â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _pickAndUploadLogo() async {
    if (_uploadingLogo) return;
    try {
      final picked = await ImagePicker()
          .pickImage(source: ImageSource.gallery, imageQuality: 75);
      if (picked == null) return;
      if (!mounted) return;
      setState(() => _uploadingLogo = true);
      final bytes = await picked.readAsBytes();
      final repo = ref.read(grupoRepositoryProvider);
      final url = await repo.uploadLogo(widget.grupoId, bytes);
      if (url != null) {
        await repo.updateGrupo(widget.grupoId, {'logoUrl': url});
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logo actualizado ✓')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error al subir logo: $e'),
              backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingLogo = false);
    }
  }

  // â”€â”€ Portada â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _pickAndUploadPortada() async {
    if (_uploadingPortada) return;
    try {
      final picked = await ImagePicker()
          .pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (picked == null) return;
      if (!mounted) return;
      setState(() => _uploadingPortada = true);
      final bytes = await picked.readAsBytes();
      final repo = ref.read(grupoRepositoryProvider);
      final url = await repo.uploadPortada(widget.grupoId, bytes);
      if (url != null) {
        await repo.updateGrupo(widget.grupoId, {'portadaUrl': url});
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Portada actualizada ✓')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error al subir portada: $e'),
              backgroundColor: AppTheme.danger));
      }
    } finally {
      if (mounted) setState(() => _uploadingPortada = false);
    }
  }

  // â”€â”€ Color picker â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _showColorPicker(String? current) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ColorPickerSheet(
        initial: current,
        onConfirm: (hex) {
          setState(() => _pendingColor = hex);
          ref
              .read(grupoRepositoryProvider)
              .updateGrupo(widget.grupoId, {'colorPrimario': hex});
        },
      ),
    );
  }

  // â”€â”€ Helper â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Color _resolveColor(String? fromStore) {
    final hex = _pendingColor ?? fromStore;
    if (hex == null) return _kDefaultGroupColor;
    try {
      return Color(int.parse('FF${hex.substring(1)}', radix: 16));
    } catch (_) {
      return _kDefaultGroupColor;
    }
  }

  // â”€â”€ Edit dialog â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _showEditDialog({
    required String title,
    required String initial,
    required bool multiline,
    required Future<void> Function(String) onSave,
  }) async {
    final ctrl = TextEditingController(text: initial);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          maxLines: multiline ? 4 : 1,
          autofocus: true,
          decoration: InputDecoration(
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Guardar')),
        ],
      ),
    );
    if (ok == true && mounted) {
      try {
        await onSave(ctrl.text.trim());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$title actualizado ✓')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error: $e'),
                backgroundColor: AppTheme.danger));
        }
      }
    }
    ctrl.dispose();
  }

  // â”€â”€ Tipo sheet â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _showTipoSheet(TipoGrupo current) async {
    final gc = ref.read(grupoColorProvider(widget.grupoId));
    TipoGrupo selected = current;
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surf(context),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Text('Privacidad del grupo',
                    style: GoogleFonts.bricolageGrotesque(
                        fontWeight: FontWeight.w700, fontSize: 17)),
              ),
              RadioListTile<TipoGrupo>(
                title: const Text('Público',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle:
                    const Text('Cualquiera puede ver y pedir entrar'),
                value: TipoGrupo.publico,
                groupValue: selected,
                activeColor: gc,
                onChanged: (v) => setS(() => selected = v!),
              ),
              RadioListTile<TipoGrupo>(
                title: const Text('Privado',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Solo por invitación directa'),
                value: TipoGrupo.privado,
                groupValue: selected,
                activeColor: gc,
                onChanged: (v) => setS(() => selected = v!),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await ref
                          .read(grupoRepositoryProvider)
                          .updateGrupo(
                              widget.grupoId, {'tipo': selected.name});
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Privacidad actualizada ✓')));
                      }
                    },
                    child: const Text('Guardar'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // â”€â”€ Danger zone â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _confirmarArchivar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Archivar grupo'),
        content: const Text(
            'El grupo quedará oculto para todos los miembros. Podés reactivarlo después.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archivar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref
        .read(grupoRepositoryProvider)
        .updateGrupo(widget.grupoId, {'archivado': true});
    if (mounted) context.go('/home');
  }

  Future<void> _confirmarTransferir() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Transferir propiedad'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Ingresá el UID del miembro al que querés transferirle el rol de administrador.'),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'UID del nuevo admin',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Transferir'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted || ctrl.text.trim().isEmpty) {
      ctrl.dispose();
      return;
    }
    await ref
        .read(grupoRepositoryProvider)
        .updateGrupo(widget.grupoId, {'adminUid': ctrl.text.trim()});
    ctrl.dispose();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Propiedad transferida ✓')));
      context.go('/home');
    }
  }

  Future<void> _confirmarEliminar(String nombre) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar grupo'),
        content: Text(
            '¿Eliminás "$nombre"? Esta acción es irreversible y borrará todo el contenido del grupo.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref.read(grupoRepositoryProvider).deleteGrupo(widget.grupoId);
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final gc = ref.watch(grupoColorProvider(widget.grupoId));
    final grupoAsync = ref.watch(grupoProvider(widget.grupoId));
    final solicitudesAsync =
        ref.watch(solicitudesPendientesProvider(widget.grupoId));
    final miembroAsync =
        ref.watch(miembroActualProvider(widget.grupoId));

    final grupo = grupoAsync.valueOrNull;
    final miembro = miembroAsync.valueOrNull;
    final miembros =
        ref.watch(miembrosProvider(widget.grupoId)).valueOrNull ?? [];
    int byRol(RolMiembro r) => miembros.where((m) => m.rol == r).length;
    String rolLabel(int n) => '$n persona${n == 1 ? '' : 's'}';
    final inviteLink =
        'sportsgr.app/c/${grupo?.nombre.replaceAll(' ', '-').toUpperCase() ?? widget.grupoId}';

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        backgroundColor: AppTheme.bg(context),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.popOr(),
        ),
        title: Text(
          'Configuración',
          style: GoogleFonts.bricolageGrotesque(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AppTheme.text,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 60),
        children: [
          // â”€â”€ Group hero
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _uploadingLogo ? null : _pickAndUploadLogo,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      SGAvatar(
                        name: grupo?.nombre ?? '?',
                        imageUrl: grupo?.logoUrl,
                        size: 56,
                        background: _resolveColor(grupo?.colorPrimario),
                        foreground: Colors.white,
                      ),
                      Positioned(
                        bottom: -2,
                        right: -2,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: AppTheme.text,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppTheme.background, width: 2),
                          ),
                          child: _uploadingLogo
                              ? const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white),
                                )
                              : const Icon(Icons.edit_rounded,
                                  size: 12, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        grupo?.nombre ?? '””',
                        style: GoogleFonts.bricolageGrotesque(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${grupo?.tipo.name ?? 'Grupo'} · ${grupo?.miembrosCount ?? 0} miembros',
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 6),
                      if (miembro != null)
                        SGChip(
                          label: miembro.rol.name
                                  .substring(0, 1)
                                  .toUpperCase() +
                              miembro.rol.name.substring(1),
                          tone: SGChipTone.primary,
                          filled: true,
                          icon: Icons.shield_rounded,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // â”€â”€ Identidad
          const SGEyebrow('Identidad'),
          const SizedBox(height: 8),
          _SettingsCard(
            children: [
              _SettingsRow(
                icon: Icons.title_rounded,
                label: 'Nombre',
                value: grupo?.nombre ?? '',
                onTap: () => _showEditDialog(
                  title: 'Nombre',
                  initial: grupo?.nombre ?? '',
                  multiline: false,
                  onSave: (v) => ref
                      .read(grupoRepositoryProvider)
                      .updateGrupo(widget.grupoId, {'nombre': v}),
                ),
              ),
              _SettingsRow(
                icon: Icons.public_rounded,
                label: 'Privacidad',
                value: grupo?.tipo == TipoGrupo.publico
                    ? 'Público · cualquiera puede pedir entrar'
                    : 'Privado · solo por invitación',
                onTap: () => _showTipoSheet(
                    grupo?.tipo ?? TipoGrupo.publico),
                showDivider: true,
              ),
              _SettingsRow(
                icon: Icons.notes_rounded,
                label: 'Descripción',
                value: grupo?.descripcion ?? 'Sin descripción',
                maxLines: 2,
                onTap: () => _showEditDialog(
                  title: 'Descripción',
                  initial: grupo?.descripcion ?? '',
                  multiline: true,
                  onSave: (v) => ref
                      .read(grupoRepositoryProvider)
                      .updateGrupo(widget.grupoId, {'descripcion': v}),
                ),
                showDivider: true,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // â”€â”€ Portada
          const SGEyebrow('Portada'),
          const SizedBox(height: 8),
          _SettingsCard(
            children: [
              _SettingsRow(
                icon: Icons.image_rounded,
                label: 'Imagen de portada',
                value: grupo?.portadaUrl != null
                    ? 'Configurada · tocá para cambiar'
                    : 'Sin portada · tocá para agregar',
                onTap: _uploadingPortada ? null : _pickAndUploadPortada,
                trailing: _uploadingPortada
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
              ),
            ],
          ),
          if (grupo?.portadaUrl != null) ...[
            const SizedBox(height: 8),
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: CachedNetworkImage(
                    imageUrl: grupo!.portadaUrl!,
                    height: 110,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: _uploadingPortada ? null : _pickAndUploadPortada,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit_rounded,
                              size: 13, color: Colors.white),
                          SizedBox(width: 4),
                          Text('Cambiar',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 20),

          // â”€â”€ Color del grupo
          const SGEyebrow('Color del grupo'),
          const SizedBox(height: 4),
          const Text(
            'Define el color que identifica a tu grupo en toda la app.',
            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => _showColorPicker(_pendingColor ?? grupo?.colorPrimario),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  // Live color swatch
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _resolveColor(grupo?.colorPrimario),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _resolveColor(grupo?.colorPrimario)
                              .withValues(alpha: 0.45),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Color del grupo',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                        Text(
                          (_pendingColor ?? grupo?.colorPrimario ?? '#E2693F')
                              .toUpperCase(),
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      size: 18, color: AppTheme.textMuted),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Acceso
          // El link/código de invitación y la aprobación manual de ingresos ya
          // no aplican: la app es de un solo grupo y el ingreso es automático
          // al autenticarse (ver ensureMembership en grupo_datasource.dart).

          // â”€â”€ Solicitudes pendientes
          solicitudesAsync.whenData((solic) {
            if (solic.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SGEyebrow('Solicitudes pendientes (${solic.length})'),
                const SizedBox(height: 8),
                _SettingsCard(
                  children: solic
                      .asMap()
                      .entries
                      .map((e) => _SolicitudTile(
                            solicitud: e.value,
                            grupoId: widget.grupoId,
                            showDivider: e.key < solic.length - 1,
                          ))
                      .toList(),
                ),
                const SizedBox(height: 20),
              ],
            );
          }).valueOrNull ?? const SizedBox.shrink(),

          // â”€â”€ Caja y cuotas
          const SGEyebrow('Caja y cuotas'),
          const SizedBox(height: 8),
          _SettingsCard(
            children: [
              _SettingsRow(
                icon: Icons.payments_rounded,
                label: 'Cobranza',
                value: 'Ver y gestionar cuotas del grupo',
                onTap: () =>
                    context.push('/cuotas'),
              ),
              _SettingsRow(
                icon: Icons.account_balance_wallet_rounded,
                label: 'Gastos',
                value: 'Ver gastos y caja del grupo',
                onTap: () =>
                    context.push('/gastos'),
                showDivider: true,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // â”€â”€ Roles y permisos
          const SGEyebrow('Roles y permisos'),
          const SizedBox(height: 8),
          _SettingsCard(
            children: [
              _SettingsRow(
                icon: Icons.admin_panel_settings_rounded,
                label: 'Administradores',
                value: rolLabel(byRol(RolMiembro.administrador)),
                onTap: () =>
                    context.push('/miembros'),
              ),
              // Delegados / Tesoreros / Moderadores: roles en pausa, ocultos.
              // Ver `rolesAsignables` en data/models/enums.dart.
            ],
          ),

          const SizedBox(height: 20),

          // â”€â”€ Notificaciones
          const SGEyebrow('Notificaciones del grupo'),
          const SizedBox(height: 8),
          _SettingsCard(
            children: [
              _ToggleSettingsRow(
                icon: Icons.campaign_rounded,
                iconColor: gc,
                title: 'Anuncios push',
                subtitle:
                    'Los miembros reciben push de noticias y eventos',
                value: _anunciosPush,
                onChanged: (v) {
                  setState(() => _anunciosPush = v);
                  ref.read(grupoRepositoryProvider).updateGrupo(
                    widget.grupoId,
                    {'config.anunciosPush': v},
                  );
                },
                gc: gc,
              ),
              _ToggleSettingsRow(
                icon: Icons.chat_rounded,
                iconColor: const Color(0xFF25D366),
                title: 'Integración WhatsApp',
                subtitle: 'Compartí novedades al grupo de WhatsApp',
                value: _whatsappIntegration,
                onChanged: (v) {
                  setState(() => _whatsappIntegration = v);
                  ref.read(grupoRepositoryProvider).updateGrupo(
                    widget.grupoId,
                    {'config.whatsappIntegration': v},
                  );
                },
                showDivider: true,
                gc: gc,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // â”€â”€ Danger zone
          const _DangerEyebrow(),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppTheme.danger.withValues(alpha: 0.25)),
            ),
            child: Column(
              children: [
                _SettingsRow(
                  icon: Icons.archive_rounded,
                  label: 'Archivar grupo',
                  value: 'Lo ocultás sin eliminarlo',
                  danger: true,
                  onTap: _confirmarArchivar,
                ),
                _SettingsRow(
                  icon: Icons.swap_horiz_rounded,
                  label: 'Transferir propiedad',
                  value: 'Pasar el rol de admin a otra persona',
                  danger: true,
                  showDivider: true,
                  onTap: _confirmarTransferir,
                ),
                // "Eliminar grupo" y "Abandonar grupo" quedan ocultos: en una
                // app de un solo grupo dejarían la aplicación sin contenido.
                // Abandonar es inocuo (ensureMembership vuelve a sumarte en el
                // próximo arranque) y eliminar recrearía el grupo vacío, con
                // el siguiente usuario en entrar como administrador.
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// â”€â”€ Settings card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(children: children),
    );
  }
}

// â”€â”€ Settings row â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final int maxLines;
  final bool mono;
  final bool danger;
  final bool showDivider;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.value,
    this.maxLines = 1,
    this.mono = false,
    this.danger = false,
    this.showDivider = false,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = danger ? AppTheme.danger : AppTheme.textMuted;
    final labelColor = danger ? AppTheme.danger : AppTheme.text;

    return Column(
      children: [
        if (showDivider)
          const Divider(
              height: 1,
              indent: 16,
              endIndent: 16,
              color: AppTheme.border),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Row(
              children: [
                Icon(icon, size: 20, color: iconColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: labelColor,
                          )),
                      const SizedBox(height: 1),
                      Text(
                        value,
                        maxLines: maxLines,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textMuted,
                          fontFamily: mono ? 'monospace' : null,
                        ),
                      ),
                    ],
                  ),
                ),
                trailing ??
                    Icon(Icons.chevron_right_rounded,
                        size: 18,
                        color: danger
                            ? AppTheme.danger
                            : AppTheme.textMuted),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// â”€â”€ Toggle settings row â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _ToggleSettingsRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool showDivider;
  final Color gc;

  const _ToggleSettingsRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.showDivider = false,
    required this.gc,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (showDivider)
          const Divider(
              height: 1,
              indent: 16,
              endIndent: 16,
              color: AppTheme.border),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 1),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textMuted)),
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeThumbColor: gc,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// â”€â”€ Danger eyebrow â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _DangerEyebrow extends StatelessWidget {
  const _DangerEyebrow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: Text(
        'ZONA DELICADA',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: AppTheme.danger.withValues(alpha: 0.8),
        ),
      ),
    );
  }
}

// â”€â”€ Full color picker sheet â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _ColorPickerSheet extends StatefulWidget {
  final String? initial;
  final void Function(String hex) onConfirm;

  const _ColorPickerSheet({this.initial, required this.onConfirm});

  @override
  State<_ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<_ColorPickerSheet> {
  late HSVColor _hsv;
  late TextEditingController _hexCtrl;
  bool _hexError = false;

  static const _presets = [
    '#E2693F', '#DA4A2C', '#F97316', '#EAB308',
    '#22C55E', '#059669', '#2DA67D', '#14B8A6',
    '#3B82F6', '#2563EB', '#8B5CF6', '#8868B8',
    '#EC4899', '#DB2777', '#F43F5E', '#7C3AED',
    '#D97706', '#78716C', '#374151', '#111827',
  ];

  @override
  void initState() {
    super.initState();
    Color initial = _kDefaultGroupColor;
    if (widget.initial != null) {
      try {
        initial = Color(
            int.parse('FF${widget.initial!.substring(1)}', radix: 16));
      } catch (_) {}
    }
    _hsv = HSVColor.fromColor(initial);
    _hexCtrl = TextEditingController(text: _toHex(initial));
  }

  @override
  void dispose() {
    _hexCtrl.dispose();
    super.dispose();
  }

  String _toHex(Color c) =>
      '#${c.red.toRadixString(16).padLeft(2, '0')}'
      '${c.green.toRadixString(16).padLeft(2, '0')}'
      '${c.blue.toRadixString(16).padLeft(2, '0')}'.toUpperCase();

  void _updateHsv(HSVColor hsv) {
    setState(() {
      _hsv = hsv;
      final hex = _toHex(hsv.toColor());
      _hexCtrl.value = TextEditingValue(
        text: hex,
        selection: TextSelection.collapsed(offset: hex.length),
      );
      _hexError = false;
    });
  }

  void _onHexChanged(String raw) {
    var v = raw.trim().toUpperCase();
    if (!v.startsWith('#')) v = '#$v';
    if (v.length == 7) {
      try {
        final c = Color(int.parse('FF${v.substring(1)}', radix: 16));
        setState(() {
          _hsv = HSVColor.fromColor(c);
          _hexError = false;
        });
        return;
      } catch (_) {}
    }
    setState(() => _hexError = v.length > 2);
  }

  Widget _gradSlider({
    required List<Color> colors,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Stack(
      alignment: Alignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: 22,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors),
            ),
          ),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 22,
            activeTrackColor: Colors.transparent,
            inactiveTrackColor: Colors.transparent,
            overlayColor: Colors.white24,
            thumbColor: Colors.white,
            thumbShape:
                const RoundSliderThumbShape(enabledThumbRadius: 11),
            trackShape: const RectangularSliderTrackShape(),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _hsv.toColor();
    final isLight = color.computeLuminance() > 0.45;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      minChildSize: 0.55,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Text('Color del grupo',
                style: GoogleFonts.bricolageGrotesque(
                    fontWeight: FontWeight.w700, fontSize: 18)),
            const SizedBox(height: 16),

            // â”€â”€ Live preview â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            Container(
              height: 72,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.45),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                _toHex(color),
                style: TextStyle(
                  color: isLight
                      ? Colors.black.withValues(alpha: 0.65)
                      : Colors.white.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // â”€â”€ Hue â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            Row(children: [
              const Text('TONO',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMuted,
                      letterSpacing: 0.8)),
              const Spacer(),
              Text('${_hsv.hue.round()}°',
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textMuted)),
            ]),
            const SizedBox(height: 6),
            _gradSlider(
              colors: List.generate(
                7,
                (i) => HSVColor.fromAHSV(1, i * 60.0, 1, 1).toColor(),
              ),
              value: _hsv.hue,
              min: 0,
              max: 360,
              onChanged: (v) => _updateHsv(_hsv.withHue(v)),
            ),
            const SizedBox(height: 16),

            // â”€â”€ Saturation â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            Row(children: [
              const Text('SATURACIÓN',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMuted,
                      letterSpacing: 0.8)),
              const Spacer(),
              Text('${(_hsv.saturation * 100).round()}%',
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textMuted)),
            ]),
            const SizedBox(height: 6),
            _gradSlider(
              colors: [
                HSVColor.fromAHSV(1, _hsv.hue, 0, _hsv.value).toColor(),
                HSVColor.fromAHSV(1, _hsv.hue, 1, _hsv.value).toColor(),
              ],
              value: _hsv.saturation,
              min: 0,
              max: 1,
              onChanged: (v) => _updateHsv(_hsv.withSaturation(v)),
            ),
            const SizedBox(height: 16),

            // â”€â”€ Brightness â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            Row(children: [
              const Text('BRILLO',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMuted,
                      letterSpacing: 0.8)),
              const Spacer(),
              Text('${(_hsv.value * 100).round()}%',
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textMuted)),
            ]),
            const SizedBox(height: 6),
            _gradSlider(
              colors: [
                Colors.black,
                HSVColor.fromAHSV(
                        1, _hsv.hue, _hsv.saturation, 1)
                    .toColor(),
              ],
              value: _hsv.value,
              min: 0,
              max: 1,
              onChanged: (v) => _updateHsv(_hsv.withValue(v)),
            ),
            const SizedBox(height: 16),

            // â”€â”€ Hex input â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            TextField(
              controller: _hexCtrl,
              onChanged: _onHexChanged,
              inputFormatters: [
                TextInputFormatter.withFunction((old, v) {
                  var t = v.text.toUpperCase();
                  if (!t.startsWith('#')) t = '#$t';
                  if (t.length > 7) t = t.substring(0, 7);
                  return v.copyWith(
                    text: t,
                    selection:
                        TextSelection.collapsed(offset: t.length),
                  );
                }),
              ],
              decoration: InputDecoration(
                labelText: 'Código hexadecimal',
                errorText: _hexError ? 'Formato: #RRGGBB' : null,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 20),

            // â”€â”€ Preset swatches â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            const Text('COLORES RÁPIDOS',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textMuted,
                    letterSpacing: 0.8)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _presets.map((hex) {
                final c = Color(
                    int.parse('FF${hex.substring(1)}', radix: 16));
                final sel =
                    _toHex(color).toLowerCase() == hex.toLowerCase();
                return GestureDetector(
                  onTap: () => _updateHsv(HSVColor.fromColor(c)),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: sel
                          ? Border.all(
                              color: AppTheme.text, width: 2.5)
                          : null,
                      boxShadow: sel
                          ? [
                              BoxShadow(
                                color: c.withValues(alpha: 0.5),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : null,
                    ),
                    child: sel
                        ? const Icon(Icons.check_rounded,
                            size: 17, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // â”€â”€ Confirm â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor:
                      isLight ? Colors.black87 : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  widget.onConfirm(_toHex(color));
                },
                child: const Text('Aplicar color',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// â”€â”€ Solicitud tile â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _SolicitudTile extends ConsumerWidget {
  final SolicitudUnionModel solicitud;
  final String grupoId;
  final bool showDivider;

  const _SolicitudTile({
    required this.solicitud,
    required this.grupoId,
    this.showDivider = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        if (showDivider)
          const Divider(
              height: 1,
              indent: 16,
              endIndent: 16,
              color: AppTheme.border),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(
            children: [
              SGAvatar(
                name: solicitud.usuarioNombre,
                imageUrl: solicitud.usuarioAvatar,
                size: 36,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(solicitud.usuarioNombre,
                    style:
                        const TextStyle(fontWeight: FontWeight.w600)),
              ),
              IconButton(
                icon: const Icon(Icons.check_circle_rounded,
                    color: AppTheme.good),
                onPressed: () =>
                    ref.read(grupoRepositoryProvider).responderSolicitud(
                          grupoId,
                          solicitud.usuarioUid,
                          true,
                          solicitud.usuarioNombre,
                          solicitud.usuarioAvatar,
                        ),
              ),
              IconButton(
                icon: const Icon(Icons.cancel_rounded, color: AppTheme.danger),
                onPressed: () =>
                    ref.read(grupoRepositoryProvider).responderSolicitud(
                          grupoId,
                          solicitud.usuarioUid,
                          false,
                          solicitud.usuarioNombre,
                          solicitud.usuarioAvatar,
                        ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
