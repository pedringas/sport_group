import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/sg_widgets.dart';
import '../../../data/models/enums.dart';
import '../../../providers/grupo_provider.dart';

// â”€â”€ Sport categories â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

const _deportes = [
  (label: 'Fútbol', icon: 'âš½'),
  (label: 'Básquet', icon: '🏐€'),
  (label: 'Vóley', icon: '🏐'),
  (label: 'Running', icon: '🏐ƒ'),
  (label: 'Tenis', icon: '🎾'),
  (label: 'Ciclismo', icon: '🚴'),
  (label: 'Trekking', icon: '🥾'),
  (label: 'Natación', icon: '🏐Š'),
  (label: 'Paddle', icon: '🏐“'),
  (label: 'Otro', icon: '🏐…'),
];

// â”€â”€ Page â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class CrearGrupoPage extends ConsumerStatefulWidget {
  const CrearGrupoPage({super.key});

  @override
  ConsumerState<CrearGrupoPage> createState() => _CrearGrupoPageState();
}

class _CrearGrupoPageState extends ConsumerState<CrearGrupoPage> {
  int _step = 1; // 1 | 2 | 3

  // Step 1
  final _nombreCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  Uint8List? _portadaBytes;
  Uint8List? _logoBytes;

  // Step 2
  final Set<String> _deportesSelected = {};

  // Step 3
  TipoGrupo _tipo = TipoGrupo.publico;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPortada() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() => _portadaBytes = bytes);
    }
  }

  Future<void> _pickLogo() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() => _logoBytes = bytes);
    }
  }

  bool get _step1Valid => _nombreCtrl.text.trim().isNotEmpty;

  Future<void> _crear() async {
    try {
      final grupoId = await ref.read(crearGrupoProvider.notifier).crearGrupo(
            nombre: _nombreCtrl.text.trim(),
            descripcion: _descCtrl.text.trim().isEmpty
                ? null
                : _descCtrl.text.trim(),
            tipo: _tipo,
            logoBytes: _logoBytes,
            portadaBytes: _portadaBytes,
          );
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(crearGrupoProvider).isLoading;

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: SafeArea(
        child: Column(
          children: [
            // â”€â”€ Top bar + progress
            _TopBar(
              step: _step,
              onBack: _step == 1 ? () => context.pop() : () => setState(() => _step--),
            ),

            // â”€â”€ Content (scrollable)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: _stepContent(key: ValueKey(_step)),
                  ),
                ),
              ),
            ),

            // â”€â”€ Bottom actions
            _BottomBar(
              step: _step,
              isLoading: isLoading,
              canContinue: _step == 1 ? _step1Valid : true,
              onNext: () {
                if (_step < 3) {
                  if (_step == 1 && !_step1Valid) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Ingresá el nombre del grupo'),
                    ));
                    return;
                  }
                  setState(() => _step++);
                } else {
                  _crear();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepContent({required ValueKey key}) {
    switch (_step) {
      case 1:
        return _Step1(
          key: key,
          nombreCtrl: _nombreCtrl,
          descCtrl: _descCtrl,
          portadaBytes: _portadaBytes,
          logoBytes: _logoBytes,
          onPickPortada: _pickPortada,
          onPickLogo: _pickLogo,
          onNombreChanged: (_) => setState(() {}),
        );
      case 2:
        return _Step2(
          key: key,
          selected: _deportesSelected,
          onToggle: (d) => setState(() {
            if (_deportesSelected.contains(d)) {
              _deportesSelected.remove(d);
            } else {
              _deportesSelected.add(d);
            }
          }),
        );
      case 3:
        return _Step3(
          key: key,
          tipo: _tipo,
          onChanged: (t) => setState(() => _tipo = t),
        );
      default:
        return const SizedBox();
    }
  }
}

// â”€â”€ Top bar with progress bar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _TopBar extends StatelessWidget {
  final int step;
  final VoidCallback onBack;
  const _TopBar({required this.step, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Close / back row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: onBack,
              ),
              Expanded(
                child: Text(
                  'Crear grupo',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.bricolageGrotesque(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    letterSpacing: -0.2,
                    color: AppTheme.text,
                  ),
                ),
              ),
              // Eyebrow right ”” step label
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text(
                  'PASO $step DE 3',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: AppTheme.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Progress bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: step / 3,
              backgroundColor: AppTheme.border,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
              minHeight: 4,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Divider(height: 1, color: AppTheme.border),
      ],
    );
  }
}

// â”€â”€ Bottom bar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _BottomBar extends StatelessWidget {
  final int step;
  final bool isLoading;
  final bool canContinue;
  final VoidCallback onNext;
  const _BottomBar({
    required this.step,
    required this.isLoading,
    required this.canContinue,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          if (step > 1) ...[
            Expanded(
              child: SGPillButton(
                label: 'Atrás',
                tone: SGTone.outline,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: 2,
            child: SGPillButton(
              label: step == 3 ? 'Crear grupo' : 'Siguiente',
              icon: step == 3
                  ? (isLoading ? null : Icons.check_rounded)
                  : Icons.arrow_forward_rounded,
              onPressed: (isLoading || !canContinue) ? null : onNext,
            ),
          ),
        ],
      ),
    );
  }
}

// â”€â”€ Step 1: Nombre + cover photo â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _Step1 extends StatelessWidget {
  final TextEditingController nombreCtrl;
  final TextEditingController descCtrl;
  final Uint8List? portadaBytes;
  final Uint8List? logoBytes;
  final VoidCallback onPickPortada;
  final VoidCallback onPickLogo;
  final ValueChanged<String> onNombreChanged;

  const _Step1({
    super.key,
    required this.nombreCtrl,
    required this.descCtrl,
    required this.portadaBytes,
    required this.logoBytes,
    required this.onPickPortada,
    required this.onPickLogo,
    required this.onNombreChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),

        // â”€â”€ Cover photo
        GestureDetector(
          onTap: onPickPortada,
          child: Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: portadaBytes != null ? null : AppTheme.primarySoft,
              borderRadius: BorderRadius.circular(16),
              image: portadaBytes != null
                  ? DecorationImage(
                      image: MemoryImage(portadaBytes!),
                      fit: BoxFit.cover,
                    )
                  : null,
              border: Border.all(
                color: AppTheme.primary,
                width: 1.5,
                // Dashed border via dash painter below, shown only when empty
              ),
            ),
            child: portadaBytes == null
                ? const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined,
                          size: 32, color: AppTheme.primaryInk),
                      SizedBox(height: 6),
                      Text(
                        'Foto de portada (opcional)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.primaryInk,
                        ),
                      ),
                    ],
                  )
                : Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Cambiar',
                            style: TextStyle(
                                color: Colors.white, fontSize: 12)),
                      ),
                    ),
                  ),
          ),
        ),

        const SizedBox(height: 20),

        // â”€â”€ Nombre
        const Text(
          'Nombre del grupo *',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textMuted,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border),
          ),
          child: TextField(
            controller: nombreCtrl,
            onChanged: onNombreChanged,
            textCapitalization: TextCapitalization.words,
            style: GoogleFonts.bricolageGrotesque(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: AppTheme.text,
            ),
            decoration: const InputDecoration(
              hintText: 'ej. Los Cracks del Parque',
              hintStyle: TextStyle(
                color: AppTheme.textMuted,
                fontWeight: FontWeight.w400,
                fontSize: 15,
              ),
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // â”€â”€ Descripción (opcional)
        const Text(
          'Descripción (opcional)',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textMuted,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border),
          ),
          child: TextField(
            controller: descCtrl,
            maxLines: 3,
            style: const TextStyle(fontSize: 15, color: AppTheme.text),
            decoration: const InputDecoration(
              hintText: 'Contá de qué se trata el grupo...',
              hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 14),
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),

        const SizedBox(height: 20),

        // â”€â”€ Logo (optional)
        Row(
          children: [
            GestureDetector(
              onTap: onPickLogo,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: AppTheme.primarySoft,
                    backgroundImage:
                        logoBytes != null ? MemoryImage(logoBytes!) : null,
                    child: logoBytes == null
                        ? const Icon(Icons.add_a_photo_outlined,
                            size: 22, color: AppTheme.primaryInk)
                        : null,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 22, height: 22,
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.surface, width: 2),
                      ),
                      child: const Icon(Icons.edit, size: 12, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Logo del grupo',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  SizedBox(height: 2),
                  Text('Opcional · se muestra en tu feed',
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.textMuted)),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),
      ],
    );
  }
}

// â”€â”€ Step 2: Deporte â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _Step2 extends StatelessWidget {
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  const _Step2({super.key, required this.selected, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          '¿Qué deporte practican?',
          style: GoogleFonts.bricolageGrotesque(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            letterSpacing: -0.3,
            color: AppTheme.text,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Elegí uno o más. Podés cambiar esto después.',
          style: TextStyle(fontSize: 14, color: AppTheme.textMuted, height: 1.4),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _deportes.map((d) {
            final isSelected = selected.contains(d.label);
            return GestureDetector(
              onTap: () => onToggle(d.label),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primary : AppTheme.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isSelected ? AppTheme.primary : AppTheme.border,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(d.icon, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(
                      d.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : AppTheme.text,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        if (selected.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Podés saltear este paso si no aplica.',
              style: TextStyle(
                  fontSize: 12, color: AppTheme.textMuted,
                  fontStyle: FontStyle.italic),
            ),
          ),
      ],
    );
  }
}

// â”€â”€ Step 3: Privacidad â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _Step3 extends StatelessWidget {
  final TipoGrupo tipo;
  final ValueChanged<TipoGrupo> onChanged;
  const _Step3({super.key, required this.tipo, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          '¿Quién puede unirse?',
          style: GoogleFonts.bricolageGrotesque(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            letterSpacing: -0.3,
            color: AppTheme.text,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Definí si el grupo es abierto o requiere aprobación.',
          style: TextStyle(fontSize: 14, color: AppTheme.textMuted, height: 1.4),
        ),
        const SizedBox(height: 20),

        // 2-column grid of privacy cards
        Row(
          children: [
            Expanded(
              child: _PrivacyCard(
                icon: Icons.public_rounded,
                title: 'Público',
                subtitle: 'Cualquiera puede unirse libremente',
                selected: tipo == TipoGrupo.publico,
                onTap: () => onChanged(TipoGrupo.publico),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PrivacyCard(
                icon: Icons.lock_outline_rounded,
                title: 'Privado',
                subtitle: 'Los miembros deben ser aprobados',
                selected: tipo == TipoGrupo.privado,
                onTap: () => onChanged(TipoGrupo.privado),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Summary
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.primarySoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  size: 18, color: AppTheme.primaryInk),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tipo == TipoGrupo.publico
                      ? 'El grupo aparece en búsquedas y cualquiera puede unirse sin aprobación.'
                      : 'El grupo no aparece en búsquedas. Vos aprobás cada solicitud de ingreso.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.primaryInk,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PrivacyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _PrivacyCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primarySoft : AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: selected ? AppTheme.primary : AppTheme.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 20,
                      color: selected ? Colors.white : AppTheme.textMuted),
                ),
                if (selected)
                  Container(
                    width: 20, height: 20,
                    decoration: const BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.check_rounded,
                        size: 12, color: Colors.white),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: selected ? AppTheme.primaryInk : AppTheme.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: selected ? AppTheme.primaryInk : AppTheme.textMuted,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
