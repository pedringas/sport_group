import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import 'ob_shared.dart';

class OBProfile extends StatefulWidget {
  final VoidCallback onBack;
  final Set<String> selectedSports;
  final void Function(Set<String> sports) onAdvance;

  const OBProfile({
    super.key,
    required this.onBack,
    required this.selectedSports,
    required this.onAdvance,
  });

  @override
  State<OBProfile> createState() => _OBProfileState();
}

class _OBProfileState extends State<OBProfile> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.selectedSports);
  }

  void _toggle(String key) {
    setState(() {
      if (_selected.contains(key)) {
        _selected.remove(key);
      } else {
        _selected.add(key);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              OBBreadcrumb(step: 3, onBack: widget.onBack),
              const SizedBox(height: 28),
              Text(
                'Tus deportes favoritos',
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.txt(context),
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Elegí los que practicás o te gustan. Podés cambiarlos después.',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  color: AppTheme.txtMuted(context),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 2.8,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: kDeportes
                      .map((d) => _SportChip(
                            deporte: d,
                            selected: _selected.contains(d.key),
                            onTap: () => _toggle(d.key),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 20),
              OBBtn(
                'Continuar',
                onTap: _selected.isEmpty ? null : () => widget.onAdvance(_selected),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _SportChip extends StatelessWidget {
  final OBDeporte deporte;
  final bool selected;
  final VoidCallback onTap;

  const _SportChip({
    required this.deporte,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primarySoft : AppTheme.surf(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.brd(context),
            width: 2,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Icon(
              deporte.icon,
              size: 22,
              color: selected ? AppTheme.primary : AppTheme.textMuted,
            ),
            const SizedBox(width: 10),
            Text(
              deporte.label,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? AppTheme.primaryInk : AppTheme.txt(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
