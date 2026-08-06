import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import 'ob_shared.dart';

const _kStepLabels = ['Inicio', 'Cuenta', 'Perfil', 'Grupo'];

class OBReady extends StatelessWidget {
  final String grupoId;
  final String grupoNombre;
  final Color grupoColor;
  final bool isCreated;
  final void Function({required bool goToGroup}) onFinish;

  const OBReady({
    super.key,
    required this.grupoId,
    required this.grupoNombre,
    required this.grupoColor,
    required this.isCreated,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: Column(
        children: [
          // Coral header
          Container(
            color: AppTheme.primary,
            width: double.infinity,
            child: SafeArea(
              bottom: false,
              child: Stack(
                children: [
                  Positioned(
                    top: -40,
                    right: -60,
                    child: _circle(200, Colors.white.withValues(alpha: 0.07)),
                  ),
                  Positioned(
                    bottom: 0,
                    left: -40,
                    child: _circle(140, Colors.white.withValues(alpha: 0.06)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 24, 28, 48),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Completion breadcrumb (all steps done, no back)
                        Row(
                          children: [
                            for (int i = 0; i < _kStepLabels.length; i++) ...[
                              Text(
                                _kStepLabels[i],
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              if (i < _kStepLabels.length - 1)
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 3),
                                  child: Icon(
                                    Icons.chevron_right_rounded,
                                    size: 13,
                                    color: Colors.white70,
                                  ),
                                ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: const LinearProgressIndicator(
                            value: 1.0,
                            backgroundColor: Colors.white24,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            minHeight: 2.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text('🎉', style: TextStyle(fontSize: 44)),
                        const SizedBox(height: 16),
                        Text(
                          isCreated ? '¡Grupo creado!' : '¡Bienvenido al grupo!',
                          style: GoogleFonts.bricolageGrotesque(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        RichText(
                          text: TextSpan(
                            style: GoogleFonts.dmSans(
                              fontSize: 16,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                            children: [
                              const TextSpan(text: 'Ya sos parte de '),
                              TextSpan(
                                text: grupoNombre,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Floating group card
          Transform.translate(
            offset: const Offset(0, -24),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _GroupCard(
                grupoNombre: grupoNombre,
                grupoColor: grupoColor,
                isCreated: isCreated,
              ),
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                OBBtn(
                  'Ver mi grupo',
                  onTap: () => onFinish(goToGroup: true),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () => onFinish(goToGroup: false),
                  child: Text(
                    'Agregar otro grupo',
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      color: AppTheme.textMuted,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _circle(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );
}

class _GroupCard extends StatelessWidget {
  final String grupoNombre;
  final Color grupoColor;
  final bool isCreated;

  const _GroupCard({
    required this.grupoNombre,
    required this.grupoColor,
    required this.isCreated,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surf(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: grupoColor.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: grupoColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.groups, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    grupoNombre,
                    style: GoogleFonts.bricolageGrotesque(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.txt(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.goodSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Nuevo',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.goodInk,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Stats grid
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const _Stat(
                  icon: Icons.people_outline_rounded,
                  value: '1',
                  label: 'Miembros',
                ),
                const _Stat(
                  icon: Icons.event_outlined,
                  value: '0',
                  label: 'Eventos',
                ),
                _Stat(
                  icon: Icons.check_circle_outline_rounded,
                  value: isCreated ? 'Admin' : 'Miembro',
                  label: 'Tu rol',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _Stat({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 22, color: AppTheme.primary),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.txt(context),
            ),
          ),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 10,
              color: AppTheme.txtMuted(context),
            ),
          ),
        ],
      ),
    );
  }
}
