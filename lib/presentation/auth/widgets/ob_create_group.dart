import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/grupo_model.dart';
import '../../../data/models/enums.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/grupo_provider.dart';
import 'ob_shared.dart';

class OBCreateGroup extends ConsumerStatefulWidget {
  final VoidCallback onBack;
  final void Function(String grupoId, String nombre, Color color) onCreated;

  const OBCreateGroup({
    super.key,
    required this.onBack,
    required this.onCreated,
  });

  @override
  ConsumerState<OBCreateGroup> createState() => _OBCreateGroupState();
}

class _OBCreateGroupState extends ConsumerState<OBCreateGroup> {
  final _nameCtrl = TextEditingController();
  String _deporte = '';
  int _colorIdx = 0;
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  bool get _canCreate =>
      _nameCtrl.text.trim().isNotEmpty && _deporte.isNotEmpty;

  Future<void> _create() async {
    if (!_canCreate) return;
    setState(() => _loading = true);
    try {
      final user = ref.read(authStateProvider).valueOrNull!;
      final userData = await ref.read(currentUserProvider.future);
      final adminNombre =
          userData?.nombreCompleto.isNotEmpty == true
              ? userData!.nombreCompleto
              : (user.displayName ?? '');
      final color = kGrupoColores[_colorIdx];
      final grupoModel = GrupoModel(
        id: '',
        nombre: _nameCtrl.text.trim(),
        descripcion: _deporte,
        tipo: TipoGrupo.publico,
        adminUid: user.uid,
        miembrosCount: 0,
        createdAt: DateTime.now(),
        codigoAcceso: '',
        colorPrimario: hexColor(color),
      );
      final grupoId = await ref.read(grupoRepositoryProvider).createGrupo(
            grupoModel,
            adminNombreCompleto: adminNombre,
            adminAvatarUrl: userData?.avatarUrl ?? user.photoURL,
          );
      if (!mounted) return;
      widget.onCreated(grupoId, _nameCtrl.text.trim(), color);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al crear el grupo: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = kGrupoColores[_colorIdx];
    final nombre = _nameCtrl.text.trim();
    final depLabel = kDeportes.where((d) => d.key == _deporte).firstOrNull?.label ?? '';

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              OBBreadcrumb(step: 4, onBack: widget.onBack),
              const SizedBox(height: 24),
              Text(
                'Creá tu grupo',
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.txt(context),
                ),
              ),
              const SizedBox(height: 24),
              // Live preview card
              _PreviewCard(
                nombre: nombre.isEmpty ? 'Nombre del grupo' : nombre,
                deporte: depLabel.isEmpty ? 'Deporte' : depLabel,
                deporteKey: _deporte,
                color: color,
              ),
              const SizedBox(height: 24),
              OBField(
                label: 'Nombre del grupo',
                hint: 'ej. Club Amigos FC',
                icon: Icons.groups_rounded,
                controller: _nameCtrl,
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              // Deporte dropdown
              _DeporteSelector(
                selected: _deporte,
                onSelect: (k) => setState(() => _deporte = k),
              ),
              const SizedBox(height: 20),
              Text(
                'Color del grupo',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.txtMuted(context),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: List.generate(kGrupoColores.length, (i) {
                  final selected = i == _colorIdx;
                  return GestureDetector(
                    onTap: () => setState(() => _colorIdx = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 38,
                      height: 38,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: kGrupoColores[i],
                        borderRadius: BorderRadius.circular(11),
                        border: selected
                            ? Border.all(
                                color: AppTheme.txt(context),
                                width: 3,
                              )
                            : null,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 32),
              OBBtn(
                'Crear grupo',
                onTap: _canCreate && !_loading ? _create : null,
                isLoading: _loading,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final String nombre;
  final String deporte;
  final String deporteKey;
  final Color color;

  const _PreviewCard({
    required this.nombre,
    required this.deporte,
    required this.deporteKey,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final icon = deporteIcon(deporteKey);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          Positioned(
            bottom: -10,
            right: -10,
            child: Opacity(
              opacity: 0.13,
              child: Icon(icon, size: 110, color: Colors.white),
            ),
          ),
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                ),
                child: Icon(icon, size: 24, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombre,
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '$deporte · 1 miembro',
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeporteSelector extends StatelessWidget {
  final String selected;
  final void Function(String key) onSelect;

  const _DeporteSelector({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showPicker(context),
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppTheme.surf(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.brd(context)),
        ),
        child: Row(
          children: [
            const Icon(Icons.sports_rounded, size: 20, color: AppTheme.textMuted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                selected.isEmpty
                    ? 'Seleccioná un deporte'
                    : kDeportes.firstWhere((d) => d.key == selected).label,
                style: GoogleFonts.dmSans(
                  fontSize: 15,
                  fontWeight: selected.isEmpty ? FontWeight.w400 : FontWeight.w500,
                  color: selected.isEmpty
                      ? AppTheme.txtMuted(context)
                      : AppTheme.txt(context),
                ),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded,
                color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: kDeportes
            .map((d) => ListTile(
                  leading: Icon(d.icon, color: AppTheme.primary),
                  title: Text(d.label),
                  selected: d.key == selected,
                  selectedTileColor: AppTheme.primarySoft,
                  onTap: () {
                    onSelect(d.key);
                    Navigator.pop(context);
                  },
                ))
            .toList(),
      ),
    );
  }
}
