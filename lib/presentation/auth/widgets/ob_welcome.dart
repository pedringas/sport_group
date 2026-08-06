import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import 'ob_shared.dart';

class OBWelcome extends StatelessWidget {
  final VoidCallback onStart;
  const OBWelcome({super.key, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: Stack(
        children: [
          // Decorative circles
          Positioned(
            top: -60,
            right: -80,
            child: _circle(260, Colors.white.withValues(alpha: 0.06)),
          ),
          Positioned(
            top: 120,
            left: -100,
            child: _circle(200, Colors.white.withValues(alpha: 0.08)),
          ),
          Positioned(
            bottom: 160,
            right: -60,
            child: _circle(180, Colors.white.withValues(alpha: 0.07)),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 56),
                  // Logo
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.32),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'SG',
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),
                  Text(
                    'Tu grupo,\ntu cancha.',
                    style: GoogleFonts.bricolageGrotesque(
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Organizá partidos, compartí gastos\ny mantenete conectado con tu equipo.',
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.8),
                      height: 1.5,
                    ),
                  ),
                  const Spacer(),
                  OBBtn(
                    'Empezar ahora',
                    light: true,
                    onTap: onStart,
                  ),
                  const SizedBox(height: 14),
                  OBOutlineBtn(
                    'Ya tengo cuenta',
                    onDark: true,
                    onTap: () => context.push('/login'),
                  ),
                  const SizedBox(height: 44),
                ],
              ),
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
