import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import 'ob_shared.dart';

class OBJoinOrCreate extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onJoin;
  final VoidCallback onCreate;
  final VoidCallback onSkip;

  const OBJoinOrCreate({
    super.key,
    required this.onBack,
    required this.onJoin,
    required this.onCreate,
    required this.onSkip,
  });

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
              OBBreadcrumb(step: 4, onBack: onBack),
              const SizedBox(height: 28),
              Text(
                '¿Tenés un grupo\no creás uno?',
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.txt(context),
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Podés unirte a uno existente o empezar el tuyo.',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  color: AppTheme.txtMuted(context),
                ),
              ),
              const Spacer(),
              _ChoiceCard(
                label: 'Unirme a un grupo',
                subtitle: 'Buscá por nombre o código de acceso',
                icon: Icons.group_add_rounded,
                primary: true,
                onTap: onJoin,
              ),
              const SizedBox(height: 14),
              _ChoiceCard(
                label: 'Crear mi grupo',
                subtitle: 'Empezá uno desde cero, es gratis',
                icon: Icons.add_circle_outline_rounded,
                primary: false,
                onTap: onCreate,
              ),
              const SizedBox(height: 24),
              Center(
                child: GestureDetector(
                  onTap: onSkip,
                  child: Text(
                    'Explorar la app primero',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      color: AppTheme.txtMuted(context),
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool primary;
  final VoidCallback onTap;

  const _ChoiceCard({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: primary ? AppTheme.primarySoft : AppTheme.surf(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: primary ? AppTheme.primary : AppTheme.brd(context),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: primary ? AppTheme.primary : AppTheme.surfAlt(context),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                size: 24,
                color: primary ? Colors.white : AppTheme.textMuted,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: primary ? AppTheme.primaryInk : AppTheme.txt(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: primary ? AppTheme.primaryInk.withValues(alpha: 0.7) : AppTheme.txtMuted(context),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: primary ? AppTheme.primary : AppTheme.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
