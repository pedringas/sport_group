import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';

// â”€â”€ Slide data â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _Slide {
  final String tag;
  final String title;
  final String desc;
  final Color accent;
  final Color soft;
  const _Slide({
    required this.tag,
    required this.title,
    required this.desc,
    required this.accent,
    required this.soft,
  });
}

const _slides = [
  _Slide(
    tag: 'TU COMUNIDAD',
    title: 'Tu equipo,\ntu club, tu barra.',
    desc:
        'Todo lo que pasa en tu grupo en un solo lugar: sin chats interminables ni planillas.',
    accent: AppTheme.primary,
    soft: AppTheme.primarySoft,
  ),
  _Slide(
    tag: 'SIN VUELTAS',
    title: 'Pagá la cuota\nen 2 toques.',
    desc:
        'Hacés la transferencia, subís el comprobante, y listo. El tesorero lo valida en segundos: todo registrado, sin perseguir a nadie.',
    accent: AppTheme.good,
    soft: AppTheme.goodSoft,
  ),
  _Slide(
    tag: 'CADA UNO EN SU LUGAR',
    title: 'Roles claros,\nresponsabilidades claras.',
    desc:
        'Delegados, tesoreros, moderadores. Cada uno con su panel y sus permisos. Funciona porque está pensado.',
    accent: AppTheme.accent,
    soft: AppTheme.accentSoft,
  ),
];

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Main page
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  int _step = 0;
  bool _finishing = false;

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_seen', true);
    if (mounted) context.go('/login');
  }

  void _next() {
    if (_finishing) return;
    if (_step == _slides.length - 1) {
      _finish();
      return;
    }
    setState(() => _step++);
  }

  void _skip() => _finish();

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_step];

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            // Centered card on desktop, full-width on mobile
            constraints: const BoxConstraints(maxWidth: 520),
            child: Stack(
              children: [
                // â”€â”€ Scrollable content
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // SG logo
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                'SG',
                                style: GoogleFonts.bricolageGrotesque(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          // Skip
                          GestureDetector(
                            onTap: _skip,
                            child: Text(
                              'Saltar',
                              style: GoogleFonts.dmSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Visual area
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 350),
                        height: 300,
                        decoration: BoxDecoration(
                          color: slide.soft,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: Center(
                          child: _buildViz(_step, slide.accent),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Text section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            slide.tag,
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                              color: AppTheme.primary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            slide.title,
                            style: GoogleFonts.bricolageGrotesque(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.text,
                              letterSpacing: -0.5,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            slide.desc,
                            style: GoogleFonts.dmSans(
                              fontSize: 15,
                              height: 1.55,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Spacer pushes footer down
                    const Expanded(child: SizedBox()),

                    // Footer (dots + button)
                    const SizedBox(height: 80),
                  ],
                ),

                // â”€â”€ Fixed bottom bar
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    color: AppTheme.background,
                    padding: EdgeInsets.fromLTRB(
                      24,
                      16,
                      24,
                      MediaQuery.of(context).padding.bottom + 24,
                    ),
                    child: Row(
                      children: [
                        // Dot indicators
                        Row(
                          children: List.generate(_slides.length, (i) {
                            final active = i == _step;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOut,
                              width: active ? 24 : 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: active
                                    ? AppTheme.primary
                                    : AppTheme.border,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            );
                          }),
                        ),
                        const Spacer(),
                        // Next / Empezar button
                        _NextButton(
                          label: _step == _slides.length - 1
                              ? 'Empezar'
                              : 'Siguiente',
                          onTap: _next,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildViz(int step, Color accent) {
    return switch (step) {
      0 => _Viz1(accent: accent),
      1 => _Viz2(accent: accent),
      2 => _Viz3(accent: accent),
      _ => const SizedBox(),
    };
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Viz 1 ”” Constellation of avatars ("Comunidad")
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _Viz1 extends StatelessWidget {
  final Color accent;
  const _Viz1({required this.accent});

  @override
  Widget build(BuildContext context) {
    const avatars = [
      (x: 90.0, y: 90.0, s: 68.0, n: 'D', big: true),
      (x: 10.0, y: 28.0, s: 44.0, n: 'L', big: false),
      (x: 178.0, y: 18.0, s: 38.0, n: 'P', big: false),
      (x: 0.0, y: 130.0, s: 48.0, n: 'S', big: false),
      (x: 182.0, y: 130.0, s: 50.0, n: 'M', big: false),
      (x: 70.0, y: 180.0, s: 40.0, n: 'N', big: false),
      (x: 172.0, y: 196.0, s: 34.0, n: 'J', big: false),
    ];

    // Center of big avatar (D)
    const cx = 90.0 + 34.0; // x + radius
    const cy = 90.0 + 34.0;
    final lines = [
      (x2: 32.0, y2: 50.0),
      (x2: 197.0, y2: 37.0),
      (x2: 24.0, y2: 154.0),
      (x2: 207.0, y2: 155.0),
      (x2: 90.0, y2: 200.0),
    ];

    return SizedBox(
      width: 240,
      height: 240,
      child: Stack(
        children: [
          // Lines behind
          CustomPaint(
            size: const Size(240, 240),
            painter: _LinePainter(lines: lines, cx: cx, cy: cy, color: accent),
          ),
          // Avatars on top
          for (final a in avatars)
            Positioned(
              left: a.x,
              top: a.y,
              child: _MiniAvatar(
                name: a.n,
                size: a.s,
                bg: a.big ? accent : AppTheme.surface,
                fg: a.big ? Colors.white : AppTheme.text,
              ),
            ),
        ],
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  final List<({double x2, double y2})> lines;
  final double cx, cy;
  final Color color;
  const _LinePainter(
      {required this.lines,
      required this.cx,
      required this.cy,
      required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (final l in lines) {
      canvas.drawLine(Offset(cx, cy), Offset(l.x2, l.y2), paint);
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.cx != cx || old.cy != cy || old.color != color;
}

class _MiniAvatar extends StatelessWidget {
  final String name;
  final double size;
  final Color bg, fg;
  const _MiniAvatar(
      {required this.name,
      required this.size,
      required this.bg,
      required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Text(
          name,
          style: GoogleFonts.bricolageGrotesque(
            fontSize: size * 0.35,
            fontWeight: FontWeight.w700,
            color: fg,
          ),
        ),
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Viz 2 ”” Payment receipt card ("Pagar")
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _Viz2 extends StatelessWidget {
  final Color accent;
  const _Viz2({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -6 * math.pi / 180,
      child: Container(
        width: 200,
        height: 240,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.13),
              blurRadius: 32,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CUOTA · MAYO',
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        'Club Atlético Norte',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.text,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Amount
            Text(
              '\$ 8.500',
              style: GoogleFonts.bricolageGrotesque(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: accent,
                letterSpacing: -1,
              ),
            ),
            Text(
              'Vence el 20/05',
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 10),
            const Divider(color: AppTheme.border),
            const SizedBox(height: 10),
            // CTA
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  'Subir comprobante',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Confirmed row
            Row(
              children: [
                const Icon(Icons.check_circle_rounded, size: 13, color: AppTheme.good),
                const SizedBox(width: 5),
                Text(
                  'Confirmado al instante',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: AppTheme.good,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Viz 3 ”” Role badges stacked ("Roles")
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _Viz3 extends StatelessWidget {
  final Color accent;
  const _Viz3({required this.accent});

  @override
  Widget build(BuildContext context) {
    final roles = [
      (icon: Icons.shield_rounded, label: 'Administrador', sub: 'control total', bg: AppTheme.roleAdmin, offset: 0.0),
      (icon: Icons.assignment_rounded, label: 'Delegado', sub: 'eventos y comunicación', bg: AppTheme.roleDelegado, offset: 12.0),
      (icon: Icons.account_balance_rounded, label: 'Tesorero', sub: 'cuotas y caja', bg: AppTheme.roleTesorero, offset: 24.0),
      (icon: Icons.record_voice_over_rounded, label: 'Moderador', sub: 'comunicación y orden', bg: AppTheme.roleModerador, offset: 36.0),
    ];

    return SizedBox(
      width: 240,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: roles.map((r) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Transform.translate(
              offset: Offset(r.offset, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: r.bg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(r.icon, size: 20, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.label,
                          style: GoogleFonts.bricolageGrotesque(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppTheme.text,
                          ),
                        ),
                        Text(
                          r.sub,
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Next / Empezar pill button
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _NextButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _NextButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.primary,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.arrow_forward_rounded,
                size: 18, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
