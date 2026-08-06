import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import 'ob_shared.dart';

class _SlideData {
  final IconData icon;
  final Color color;
  final Color soft;
  final String title;
  final String body;
  const _SlideData(this.icon, this.color, this.soft, this.title, this.body);
}

const _kSlides = [
  _SlideData(
    Icons.sports_soccer,
    AppTheme.primary,
    AppTheme.primarySoft,
    'Organizá los partidos\ncon un toque',
    'Cronograma, convocatoria y confirmaciones en un solo lugar.',
  ),
  _SlideData(
    Icons.account_balance_wallet,
    AppTheme.accent,
    AppTheme.accentSoft,
    'La caja del grupo,\nsiempre en orden',
    'Cuotas, gastos y campañas sin planillas ni confusiones.',
  ),
  _SlideData(
    Icons.groups,
    AppTheme.good,
    AppTheme.goodSoft,
    'Tu equipo conectado\ntodo el año',
    'Noticias, roles y comunicación centralizada para todo el club.',
  ),
];

class OBCarousel extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onAdvance;
  const OBCarousel({super.key, required this.onBack, required this.onAdvance});

  @override
  State<OBCarousel> createState() => _OBCarouselState();
}

class _OBCarouselState extends State<OBCarousel> {
  int _idx = 0;

  void _next() {
    if (_idx < 2) {
      setState(() => _idx++);
    } else {
      widget.onAdvance();
    }
  }

  @override
  Widget build(BuildContext context) {
    final slide = _kSlides[_idx];
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              OBBreadcrumb(
                step: 1,
                onBack: widget.onBack,
                trailing: GestureDetector(
                  onTap: widget.onAdvance,
                  child: Text(
                    'Omitir',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      color: AppTheme.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              // Illustration
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _Illustration(
                  key: ValueKey(_idx),
                  slide: slide,
                ),
              ),
              const SizedBox(height: 32),
              // Title
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  slide.title,
                  key: ValueKey('title$_idx'),
                  style: GoogleFonts.bricolageGrotesque(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.txt(context),
                    height: 1.15,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  slide.body,
                  key: ValueKey('body$_idx'),
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    color: AppTheme.txtMuted(context),
                    height: 1.5,
                  ),
                ),
              ),
              const Spacer(),
              // Dots
              Row(
                children: List.generate(3, (i) => _Dot(active: i == _idx)),
              ),
              const SizedBox(height: 20),
              OBBtn(
                _idx < 2 ? 'Continuar' : 'Crear mi cuenta',
                onTap: _next,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _Illustration extends StatelessWidget {
  final _SlideData slide;
  const _Illustration({super.key, required this.slide});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 216,
      decoration: BoxDecoration(
        color: slide.soft,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Stack(
        children: [
          // Watermark
          Positioned(
            bottom: -20,
            right: -20,
            child: Opacity(
              opacity: 0.1,
              child: Icon(slide.icon, size: 160, color: slide.color),
            ),
          ),
          // Center square
          Center(
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: slide.color,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(slide.icon, size: 44, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final bool active;
  const _Dot({required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      width: active ? 22 : 6,
      height: 6,
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        color: active ? AppTheme.primary : AppTheme.border,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}
