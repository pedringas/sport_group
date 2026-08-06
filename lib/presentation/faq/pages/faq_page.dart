import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/sg_widgets.dart';

class FaqPage extends StatefulWidget {
  const FaqPage({super.key});

  @override
  State<FaqPage> createState() => _FaqPageState();
}

class _FaqPageState extends State<FaqPage> {
  int? _expandedIndex;

  static const _topFaqs = [
    '¿Cómo subo el comprobante de transferencia?',
    '¿Qué pasa si pago una cuota y no me la confirman?',
    '¿Cómo cambio mi rol en el grupo?',
    '¿Puedo estar en más de un grupo?',
    'Me equivoqué al subir un comprobante',
  ];

  static const _categories = [
    (icon: Icons.payments_rounded, label: 'Cuotas y pagos', count: 12),
    (icon: Icons.event_rounded, label: 'Eventos y asistencia', count: 8),
    (icon: Icons.groups_rounded, label: 'Grupos y miembros', count: 9),
    (icon: Icons.shield_rounded, label: 'Roles y permisos', count: 7),
    (icon: Icons.notifications_rounded, label: 'Notificaciones', count: 4),
    (icon: Icons.security_rounded, label: 'Privacidad y cuenta', count: 6),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        backgroundColor: AppTheme.bg(context),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Ayuda y soporte',
          style: GoogleFonts.bricolageGrotesque(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AppTheme.text,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 60),
        children: [
          // â�?��?�â�?��?� Search bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: const Row(
              children: [
                Icon(Icons.search_rounded,
                    size: 20, color: AppTheme.textMuted),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '¿En qué te ayudamos?',
                    style: TextStyle(fontSize: 15, color: AppTheme.textMuted),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // â�?��?�â�?��?� Quick links 2�?2 grid
          const Row(
            children: [
              _QuickLink(
                icon: Icons.payments_rounded,
                label: 'Pagar mi cuota',
                bg: AppTheme.primarySoft,
                fg: AppTheme.primaryInk,
                route: '/home',
              ),
              SizedBox(width: 10),
              _QuickLink(
                icon: Icons.account_balance_rounded,
                label: 'Cobrar cuotas',
                bg: AppTheme.goodSoft,
                fg: AppTheme.goodInk,
                route: '/home',
              ),
            ],
          ),

          // â�?��?�â�?��?� Lo más consultado
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 24, 4, 8),
            child: SGEyebrow('LO MÁS CONSULTADO'),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            padding: const EdgeInsets.all(4),
            child: Column(
              children: List.generate(_topFaqs.length, (i) {
                final expanded = _expandedIndex == i;
                return Column(
                  children: [
                    if (i > 0)
                      const Divider(height: 1, color: AppTheme.border),
                    InkWell(
                      onTap: () => setState(() =>
                          _expandedIndex = expanded ? null : i),
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _topFaqs[i],
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: expanded
                                      ? AppTheme.primary
                                      : AppTheme.text,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            AnimatedRotation(
                              turns: expanded ? 0.5 : 0,
                              duration: const Duration(milliseconds: 200),
                              child: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 20,
                                color: expanded
                                    ? AppTheme.primary
                                    : AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (expanded)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: Text(
                          _answerFor(_topFaqs[i]),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textMuted,
                            height: 1.5,
                          ),
                        ),
                      ),
                  ],
                );
              }),
            ),
          ),

          // â�?��?�â�?��?� Categorías
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 24, 4, 8),
            child: SGEyebrow('CATEGORÍAS'),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            padding: const EdgeInsets.all(4),
            child: Column(
              children: List.generate(_categories.length, (i) {
                final cat = _categories[i];
                return Column(
                  children: [
                    if (i > 0)
                      const Divider(height: 1, color: AppTheme.border),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceAlt,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(cat.icon,
                                size: 20, color: AppTheme.primary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              cat.label,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.text,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceAlt,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${cat.count}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),

          // â�?��?�â�?��?� Contact
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => launchUrl(
                Uri.parse('mailto:soporte@sportgroups.app')),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.accentSoft,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.accent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.support_agent_rounded,
                        size: 26, color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Escribinos por mail',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppTheme.accentInk,
                          ),
                        ),
                        Text(
                          'soporte@sportgroups.app · respondemos en 24 hs',
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                AppTheme.accentInk.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.open_in_new_rounded,
                      size: 18, color: AppTheme.accentInk),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Version
          const Center(
            child: Text(
              'SportGroups v1.0.0 · Hecho con ❤️ en Argentina',
              style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  String _answerFor(String question) {
    const answers = {
      '¿Cómo subo el comprobante de transferencia?':
          'En la sección "Cuotas" del grupo, seleccioná la cuota pendiente. Tocá "Pagar con comprobante", elegí tu imagen de la galería o sacá una foto, y enviala. El administrador la revisará en breve.',
      '¿Qué pasa si pago una cuota y no me la confirman?':
          'El administrador tiene que revisar y aprobar tu comprobante. Si pasaron más de 48 hs podés consultar en el grupo. Mientras tanto, tu pago aparece como "En revisión".',
      '¿Cómo cambio mi rol en el grupo?':
          'Solo el administrador puede cambiar roles. Podés pedirle al admin que te asigne el rol correspondiente desde la sección de Miembros.',
      '¿Puedo estar en más de un grupo?':
          'Sí, podés ser miembro de múltiples grupos simultáneamente. Cada grupo es independiente y tenés tu propio rol en cada uno.',
      'Me equivoqué al subir un comprobante':
          'Contactá al administrador de tu grupo para que rechace el comprobante. Una vez rechazado, vas a poder subir el correcto desde la cuota correspondiente.',
    };
    return answers[question] ??
        'Más información disponible pronto. Contactanos si tenés dudas urgentes.';
  }
}

// Ã¢â€â‚¬Ã¢â€â‚¬ Quick link tile Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬

class _QuickLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bg;
  final Color fg;
  final String? route;

  const _QuickLink({
    required this.icon,
    required this.label,
    required this.bg,
    required this.fg,
    this.route,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: route != null ? () => context.go(route!) : null,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 26, color: fg),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: fg,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


