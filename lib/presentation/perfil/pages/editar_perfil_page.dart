import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/router/nav_ext.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/sg_widgets.dart';
import '../../../providers/auth_provider.dart';

class EditarPerfilPage extends ConsumerStatefulWidget {
  const EditarPerfilPage({super.key});

  @override
  ConsumerState<EditarPerfilPage> createState() => _EditarPerfilPageState();
}

class _EditarPerfilPageState extends ConsumerState<EditarPerfilPage> {
  final _nombreCtrl = TextEditingController();
  final _aliasCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _fechaNacCtrl = TextEditingController();

  bool _apareceEnBusqueda = true;
  bool _mostrarTelefono = false;
  String? _colorHex;

  static const _presetColors = [
    '2196F3', // blue
    '4CAF50', // green
    'FF5722', // deep orange
    '9C27B0', // purple
    'F44336', // red
    'FF9800', // orange
    '00BCD4', // cyan
    'E91E63', // pink
    '3F51B5', // indigo
    '009688', // teal
    '8BC34A', // light green
    '795548', // brown
  ];

  bool _saving = false;
  bool _uploadingAvatar = false;
  bool _loaded = false;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _aliasCtrl.dispose();
    _bioCtrl.dispose();
    _emailCtrl.dispose();
    _telefonoCtrl.dispose();
    _fechaNacCtrl.dispose();
    super.dispose();
  }

  void _loadUser(dynamic user) {
    if (_loaded || user == null) return;
    _loaded = true;
    _nombreCtrl.text = user.nombreCompleto;
    _aliasCtrl.text = user.alias ?? '';
    _bioCtrl.text = user.bio ?? '';
    _emailCtrl.text = user.email ?? '';
    _telefonoCtrl.text = user.telefono ?? '';
    _fechaNacCtrl.text = user.fechaNacimiento ?? '';
    _apareceEnBusqueda = user.apareceEnBusqueda ?? true;
    _mostrarTelefono = user.mostrarTelefono ?? false;
    _colorHex = user.colorHex;
  }

  Future<void> _pickAndUploadAvatar() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    setState(() => _uploadingAvatar = true);
    try {
      final Uint8List bytes = await picked.readAsBytes();
      final url =
          await ref.read(authRepositoryProvider).uploadAvatar(uid, bytes);
      if (url != null) {
        await ref
            .read(authRepositoryProvider)
            .updateUser(uid, {'avatarUrl': url});
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto de perfil actualizada ✓')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _guardar() async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null || !_loaded) return;
    setState(() => _saving = true);
    try {
      final partes = _nombreCtrl.text.trim().split(' ');
      final nombre = partes.isNotEmpty ? partes.first : '';
      final apellido =
          partes.length > 1 ? partes.skip(1).join(' ') : '';
      await ref.read(authRepositoryProvider).updateUser(uid, {
        'nombre': nombre,
        'apellido': apellido,
        'alias': _aliasCtrl.text.trim(),
        'bio': _bioCtrl.text.trim(),
        'telefono': _telefonoCtrl.text.trim(),
        'fechaNacimiento': _fechaNacCtrl.text.trim(),
        'apareceEnBusqueda': _apareceEnBusqueda,
        'mostrarTelefono': _mostrarTelefono,
        if (_colorHex != null) 'colorHex': _colorHex,
      });
      // Invalidate cached user so UI reflects the update immediately
      ref.invalidate(currentUserProvider);
      if (mounted) context.popOr();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    userAsync.whenData((u) => _loadUser(u));

    final user = userAsync.valueOrNull;

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: SafeArea(
        child: Column(
          children: [
            // â”€â”€ Top bar
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => context.popOr(),
                  ),
                  Expanded(
                    child: Text(
                      'Editar perfil',
                      style: GoogleFonts.bricolageGrotesque(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                        color: AppTheme.text,
                      ),
                    ),
                  ),
                  SGPillButton(
                    label: 'Guardar',
                    size: SGSize.sm,
                    onPressed: _saving ? null : _guardar,
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 60),
                children: [
                  // â”€â”€ Avatar editor
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          SGAvatar(
                            name: user?.nombreCompleto ?? '?',
                            imageUrl: user?.avatarUrl,
                            size: 108,
                            background: _colorHex != null
                                ? Color(int.parse(
                                    'FF$_colorHex', radix: 16))
                                : AppTheme.primary,
                            foreground: Colors.white,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _uploadingAvatar
                                  ? null
                                  : _pickAndUploadAvatar,
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppTheme.text,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: AppTheme.background, width: 3),
                                ),
                                child: _uploadingAvatar
                                    ? const Padding(
                                        padding: EdgeInsets.all(8),
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white),
                                      )
                                    : const Icon(Icons.photo_camera_rounded,
                                        size: 18, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Center(
                    child: Text(
                      'Cambiar foto',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Center(
                    child: Text(
                      'JPG o PNG · cuadrada, mínimo 200×200',
                      style: TextStyle(
                          fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // â”€â”€ Color de perfil
                  const SGEyebrow('Color de perfil'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Se usa como fondo de tu avatar cuando no tenés foto',
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.textMuted),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _presetColors.map((hex) {
                            final color =
                                Color(int.parse('FF$hex', radix: 16));
                            final selected = _colorHex == hex;
                            return GestureDetector(
                              onTap: () =>
                                  setState(() => _colorHex = hex),
                              child: AnimatedContainer(
                                duration:
                                    const Duration(milliseconds: 150),
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: selected
                                        ? AppTheme.text
                                        : Colors.transparent,
                                    width: 3,
                                  ),
                                  boxShadow: selected
                                      ? [
                                          BoxShadow(
                                            color: color.withValues(
                                                alpha: 0.5),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          )
                                        ]
                                      : null,
                                ),
                                child: selected
                                    ? const Icon(Icons.check_rounded,
                                        color: Colors.white, size: 18)
                                    : null,
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // â”€â”€ Datos públicos
                  const SGEyebrow('Datos públicos'),
                  const SizedBox(height: 8),
                  _EditSection(
                    children: [
                      _EditableRow(
                        label: 'Nombre completo',
                        controller: _nombreCtrl,
                      ),
                      _EditableRow(
                        label: 'Alias',
                        controller: _aliasCtrl,
                        hint: 'único en la app',
                        prefix: '@',
                        showDivider: true,
                      ),
                      _EditableRow(
                        label: 'Bio (opcional)',
                        controller: _bioCtrl,
                        maxLines: 3,
                        showDivider: true,
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // â”€â”€ Quién puede verte
                  const SGEyebrow('Quién puede verte'),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      children: [
                        _ToggleRow(
                          icon: Icons.visibility_rounded,
                          iconColor: AppTheme.primary,
                          title: 'Aparezco en búsquedas',
                          subtitle:
                              'Otros usuarios pueden encontrarte por nombre o alias',
                          value: _apareceEnBusqueda,
                          onChanged: (v) =>
                              setState(() => _apareceEnBusqueda = v),
                        ),
                        const Divider(
                            height: 1,
                            indent: 16,
                            endIndent: 16,
                            color: AppTheme.border),
                        _ToggleRow(
                          icon: Icons.phone_rounded,
                          iconColor: AppTheme.good,
                          title: 'Mostrar teléfono',
                          subtitle: 'Solo a miembros de mis grupos',
                          value: _mostrarTelefono,
                          onChanged: (v) =>
                              setState(() => _mostrarTelefono = v),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // â”€â”€ Datos privados
                  const SGEyebrow('Datos privados'),
                  const SizedBox(height: 8),
                  _EditSection(
                    children: [
                      _EditableRow(
                        label: 'Email',
                        controller: _emailCtrl,
                        hint: 'usado para login',
                        keyboardType: TextInputType.emailAddress,
                      ),
                      _EditableRow(
                        label: 'Teléfono',
                        controller: _telefonoCtrl,
                        keyboardType: TextInputType.phone,
                        showDivider: true,
                      ),
                      _EditableRow(
                        label: 'Fecha de nacimiento',
                        controller: _fechaNacCtrl,
                        hint: 'dd/mm/aaaa',
                        keyboardType: TextInputType.datetime,
                        showDivider: true,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // â”€â”€ Guardar bottom button
                  SGPillButton(
                    label: 'Guardar cambios',
                    icon: Icons.check_rounded,
                    expand: true,
                    onPressed: _saving ? null : _guardar,
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

// â”€â”€ Edit section container â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _EditSection extends StatelessWidget {
  final List<Widget> children;
  const _EditSection({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: children,
      ),
    );
  }
}

// â”€â”€ Editable row â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _EditableRow extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? prefix;
  final int maxLines;
  final TextInputType? keyboardType;
  final bool showDivider;

  const _EditableRow({
    required this.label,
    required this.controller,
    this.hint,
    this.prefix,
    this.maxLines = 1,
    this.keyboardType,
    this.showDivider = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showDivider)
          const Divider(height: 1, indent: 12, endIndent: 12, color: AppTheme.border),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  if (prefix != null) ...[
                    Text(prefix!,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textMuted)),
                  ],
                  Expanded(
                    child: TextField(
                      controller: controller,
                      maxLines: maxLines,
                      keyboardType: keyboardType,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        hintText: hint,
                        hintStyle: const TextStyle(
                            fontSize: 14, color: AppTheme.textMuted),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// â”€â”€ Toggle row â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
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
                        fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 1),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textMuted)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppTheme.primary,
          ),
        ],
      ),
    );
  }
}
