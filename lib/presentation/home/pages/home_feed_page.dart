import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/sg_widgets.dart';
import '../../../data/models/enums.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../providers/feed_provider.dart';
import '../../../providers/grupo_provider.dart';
import '../../grupo/widgets/noticias_tab.dart' show showNoticiaDetail;
import '../../../providers/notificacion_provider.dart';

class HomeFeedPage extends ConsumerWidget {
  const HomeFeedPage({super.key});

  String _today() {
    const names = [
      'Lunes', 'Martes', 'Miércoles', 'Jueves',
      'Viernes', 'Sábado', 'Domingo'
    ];
    const months = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
    ];
    final n = DateTime.now();
    return '${names[n.weekday - 1]}, ${n.day} de ${months[n.month - 1]}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserAsync = ref.watch(currentUserProvider);
    final featuredEvent = ref.watch(featuredEventProvider);
    final tareasPrioritarias = ref.watch(tareasPrioritariasProvider);
    final thisWeekItems = ref.watch(thisWeekItemsProvider);
    final feedNoticias = ref.watch(feedNoticiasProvider);
    final feedDestacadas = ref.watch(feedDestacadasProvider);
    final proximosEventos = ref.watch(feedProximosEventosProvider);
    final currentUid = ref.watch(authStateProvider).valueOrNull?.uid ?? '';

    final firstName = (currentUserAsync.valueOrNull?.nombreCompleto ?? '')
        .split(' ')
        .first;

    final hasHero = featuredEvent != null || tareasPrioritarias.isNotEmpty;
    final isDesktop = MediaQuery.sizeOf(context).width >= AppTheme.kResponsiveBreakpoint;

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            // â”€â”€ Header (mobile only) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            if (!isDesktop)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 4),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.push('/profile'),
                      child: currentUserAsync.maybeWhen(
                        data: (u) => SGAvatar(
                          name: u?.nombreCompleto ?? '?',
                          imageUrl: u?.avatarUrl,
                          size: 44,
                        ),
                        orElse: () => const SGAvatar(name: '?', size: 44),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _today(),
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            firstName.isNotEmpty
                                ? 'Hola, $firstName 👋'
                                : 'Hola 👋',
                            style: GoogleFonts.bricolageGrotesque(
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                              letterSpacing: -0.3,
                              color: AppTheme.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Consumer(
                      builder: (context, ref, _) {
                        final unread = ref
                            .watch(unreadRolCountProvider)
                            .valueOrNull ?? 0;
                        return Stack(
                          children: [
                            IconButton(
                              icon: const Icon(
                                  Icons.notifications_outlined, size: 24),
                              color: AppTheme.text,
                              onPressed: () =>
                                  context.push('/notificaciones'),
                            ),
                            if (unread > 0)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: AppTheme.danger,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: AppTheme.surface,
                                        width: 1.5),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // ── Identidad del grupo (mobile) ──────────────────────────────────
            // Reemplaza al hub de grupo eliminado: en móvil no hay sidebar que
            // muestre a qué grupo pertenece lo que estás viendo.
            if (!isDesktop)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: _GrupoStrip(),
                ),
              ),

            // â”€â”€ “Hoy te toca” hero / carrusel â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            if (hasHero) ...[
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: _SectionDivider(
                    label: 'Hoy te toca',
                    color: AppTheme.primaryInk,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: _HeroCarousel(
                    event: featuredEvent,
                    tarea: tareasPrioritarias.isNotEmpty
                        ? tareasPrioritarias.first
                        : null,
                  ),
                ),
              ),
            ],

            // â”€â”€ "Esta semana" â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            if (thisWeekItems.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
                  child: Row(
                    children: [
                      const Expanded(
                        child: _SectionDivider(
                          label: 'Esta semana',
                          color: AppTheme.textMuted,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${thisWeekItems.length}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                sliver: SliverList.separated(
                  itemCount: thisWeekItems.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) =>
                      _PendingRow(item: thisWeekItems[i]),
                ),
              ),
            ],

            // â”€â”€ Próximos eventos confirmados â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            if (proximosEventos.isNotEmpty) ...[
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 28, 16, 0),
                  child: _SectionDivider(
                    label: 'Mis próximos eventos',
                    color: Color(0xFFD97706),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: _ProximosCarousel(eventos: proximosEventos),
                ),
              ),
            ],

            // â”€â”€ Destacadas (fijadas de grupos favoritos) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            if (feedDestacadas.isNotEmpty) ...[
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 28, 16, 0),
                  child: _SectionDivider(
                    label: 'Destacadas',
                    color: AppTheme.primaryInk,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 100,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    itemCount: feedDestacadas.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, i) => _DestacadaChip(
                      item: feedDestacadas[i],
                    ),
                  ),
                ),
              ),
            ],

            // â”€â”€ “Noticias” feed â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 28, 16, 0),
                child: SGEyebrow('Noticias'),
              ),
            ),

            if (feedNoticias.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 24, 16, 40),
                  child: _EmptyNoticias(),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, AppTheme.kBottomNavPadding),
                sliver: SliverList.separated(
                  itemCount: feedNoticias.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _NoticiaFeedCard(
                    item: feedNoticias[i],
                    currentUid: currentUid,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Identidad del grupo ───────────────────────────────────────────────────────

class _GrupoStrip extends ConsumerWidget {
  const _GrupoStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grupo = ref.watch(grupoActualProvider).valueOrNull;
    final rol = ref.watch(miRolProvider);
    final gc = ref.watch(colorGrupoProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          SGAvatar(
            name: grupo?.nombre ?? kGrupoNombre,
            imageUrl: grupo?.logoUrl,
            size: 30,
            background: gc,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              grupo?.nombre ?? kGrupoNombre,
              style: GoogleFonts.bricolageGrotesque(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                letterSpacing: -0.2,
                color: AppTheme.text,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (rol != null && rol != RolMiembro.miembro)
            SGChip(
              label: rol == RolMiembro.administrador ? 'Admin' : rol.name,
              tone: SGChipTone.primary,
            ),
        ],
      ),
    );
  }
}

// â”€â”€ Hero carousel â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _HeroCarousel extends StatefulWidget {
  final EventoItem? event;
  final TareaItem? tarea;

  const _HeroCarousel({this.event, this.tarea});

  @override
  State<_HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<_HeroCarousel> {
  late final PageController _ctrl;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = PageController();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      if (widget.event != null) _EventHeroCard(item: widget.event!),
      if (widget.tarea != null) _TareaHeroCard(item: widget.tarea!),
    ];

    if (cards.isEmpty) return const SizedBox.shrink();

    // Single card ”” no carousel needed
    if (cards.length == 1) return cards.first;

    // Two cards ”” wrap in PageView with dot indicator
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 260, // fixed height for hero cards
          child: PageView(
            controller: _ctrl,
            onPageChanged: (i) => setState(() => _page = i),
            children: cards,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(cards.length, (i) {
            final active = i == _page;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: active ? AppTheme.primary : AppTheme.border,
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ── Próximos eventos carousel ─────────────────────────────────────────────────

class _ProximosCarousel extends StatefulWidget {
  final List<EventoItem> eventos;
  const _ProximosCarousel({required this.eventos});

  @override
  State<_ProximosCarousel> createState() => _ProximosCarouselState();
}

class _ProximosCarouselState extends State<_ProximosCarousel> {
  late final PageController _ctrl;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = PageController();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eventos = widget.eventos;
    if (eventos.isEmpty) return const SizedBox.shrink();
    if (eventos.length == 1) {
      return _EventoConfirmadoCard(item: eventos.first);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 188,
          child: PageView.builder(
            controller: _ctrl,
            itemCount: eventos.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => Padding(
              padding: EdgeInsets.only(
                  right: i < eventos.length - 1 ? 8.0 : 0.0),
              child: _EventoConfirmadoCard(item: eventos[i]),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(eventos.length, (i) {
            final active = i == _page;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: active
                    ? const Color(0xFFD97706)
                    : AppTheme.border,
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _EventoConfirmadoCard extends StatelessWidget {
  final EventoItem item;
  const _EventoConfirmadoCard({required this.item});

  static const _months = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
  ];

  String _daysLabel(DateTime? fecha) {
    if (fecha == null) return '';
    final diff = fecha.difference(DateTime.now()).inDays;
    if (diff == 0) return '¡Hoy!';
    if (diff == 1) return 'Mañana';
    if (diff < 0) return 'Finalizado';
    return 'En $diff días';
  }

  @override
  Widget build(BuildContext context) {
    final noticia = item.noticia;
    // Prefer fechaEvento (actual event date); fall back to fechaCaducidad
    final fecha = noticia.fechaEvento ?? noticia.fechaCaducidad;

    const cardColor = Color(0xFFD97706); // amber-600
    const cardColorSoft = Color(0xFFFEF3C7); // amber-50

    return GestureDetector(
      onTap: () => showNoticiaDetail(context, noticia, kGrupoId),
      child: Container(
        height: 188,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cardColorSoft,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
              color: cardColor.withValues(alpha: 0.25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Date column ───────────────────────────────────
            if (fecha != null)
              Container(
                width: 56,
                margin: const EdgeInsets.only(right: 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${fecha.day}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              height: 1,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _months[fecha.month - 1].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _daysLabel(fecha),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: cardColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            // ── Content ───────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    noticia.categoria.label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: cardColor.withValues(alpha: 0.8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  // Title
                  Expanded(
                    child: Text(
                      noticia.titulo,
                      style: GoogleFonts.bricolageGrotesque(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        letterSpacing: -0.2,
                        color: const Color(0xFF78350F),
                        height: 1.2,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Confirmed badge
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: cardColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                              color: cardColor.withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_rounded,
                                size: 12, color: cardColor),
                            SizedBox(width: 4),
                            Text(
                              'Confirmé asistencia',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: cardColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.arrow_forward_ios_rounded,
                          size: 12,
                          color: cardColor.withValues(alpha: 0.5)),
                    ],
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

// ── Section divider ───────────────────────────────────────────────────────────

class _SectionDivider extends StatelessWidget {
  final String label;
  final Color color;

  const _SectionDivider({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: color,
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: Divider(color: AppTheme.border, height: 1, thickness: 1),
        ),
      ],
    );
  }
}

// â”€â”€ Destacada chip â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _DestacadaChip extends StatelessWidget {
  final FeedNoticiaItem item;
  const _DestacadaChip({required this.item});

  @override
  Widget build(BuildContext context) {
    final noticia = item.noticia;

    return GestureDetector(
      onTap: () => showNoticiaDetail(context, noticia, kGrupoId),
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Autor + pin badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    noticia.autorNombre,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.push_pin_rounded,
                    size: 12, color: AppTheme.primary),
              ],
            ),
            const SizedBox(height: 6),
            // Title
            Text(
              noticia.titulo,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// â”€â”€ Event hero card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _EventHeroCard extends StatelessWidget {
  final EventoItem item;
  const _EventHeroCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final noticia = item.noticia;

    return GestureDetector(
      onTap: () => showNoticiaDetail(context, noticia, kGrupoId),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          // Negro de marca: sobre el amarillo el texto blanco no se lee.
          color: AppTheme.text,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppTheme.text.withValues(alpha: 0.28),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Decorative circles
            Positioned(
              right: -40,
              top: -40,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned(
              right: 30,
              bottom: -30,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            // Content
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Autor + categoría
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        noticia.autorNombre,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        noticia.categoria.label.toUpperCase(),
                        style: const TextStyle(
                          color: AppTheme.onPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Title
                Text(
                  noticia.titulo,
                  style: GoogleFonts.bricolageGrotesque(
                    fontWeight: FontWeight.w700,
                    fontSize: 22,
                    color: Colors.white,
                    letterSpacing: -0.3,
                    height: 1.15,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                if (noticia.contenido.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    noticia.contenido,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 18),
                // RSVP buttons ”” abren el detail modal con RSVP inline
                Row(
                  children: [
                    Expanded(
                      child: _RsvpButton(
                        icon: Icons.check_rounded,
                        label: 'Voy',
                        onTap: () =>
                            showNoticiaDetail(context, noticia, kGrupoId),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _RsvpButton(
                        icon: Icons.help_outline_rounded,
                        label: 'Tal vez',
                        onTap: () =>
                            showNoticiaDetail(context, noticia, kGrupoId),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _RsvpButton(
                        icon: Icons.close_rounded,
                        label: 'No voy',
                        onTap: () =>
                            showNoticiaDetail(context, noticia, kGrupoId),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RsvpButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _RsvpButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: Colors.white),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// â”€â”€ Tarea hero card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _TareaHeroCard extends StatelessWidget {
  final TareaItem item;
  const _TareaHeroCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final tarea = item.tarea;

    String? fechaLabel;
    if (tarea.fechaVencimiento != null) {
      final diff = tarea.fechaVencimiento!.difference(DateTime.now());
      if (diff.inDays == 0) {
        fechaLabel = 'Vence hoy';
      } else if (diff.inDays == 1) {
        fechaLabel = 'Vence mañana';
      } else if (diff.inDays < 0) {
        fechaLabel = 'Vencida hace ${-diff.inDays}d';
      } else {
        fechaLabel = 'En ${diff.inDays} días';
      }
    }

    final cardColor =
        tarea.vencida ? AppTheme.danger : AppTheme.text;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cardColor, cardColor.withValues(alpha: 0.82)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: cardColor.withValues(alpha: 0.38),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Tarea',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (fechaLabel != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    fechaLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            tarea.titulo,
            style: GoogleFonts.bricolageGrotesque(
              fontWeight: FontWeight.w700,
              fontSize: 22,
              color: Colors.white,
              letterSpacing: -0.3,
              height: 1.15,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(tarea.estado.emoji,
                        style: const TextStyle(fontSize: 11)),
                    const SizedBox(width: 4),
                    Text(
                      tarea.estado.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () =>
                    context.push('/tareas'),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    'Ver tarea →',
                    style: TextStyle(
                      color: cardColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// â”€â”€ Pending row ("Esta semana") â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _PendingRow extends StatelessWidget {
  final DashboardItem item;
  const _PendingRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final (
      Color iconBg,
      Color iconColor,
      IconData icon,
      String title,
      String subtitle,
      String cta,
      Color ctaBg,
      Color ctaText,
      VoidCallback onTap,
    ) = _resolve(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 22, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: ctaBg,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                cta,
                style: TextStyle(
                  color: ctaText,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static final _moneyFmt =
      NumberFormat.currency(locale: 'es_AR', symbol: '\$', decimalDigits: 0);

  (Color, Color, IconData, String, String, String, Color, Color, VoidCallback)
      _resolve(BuildContext context) {
    if (item is CuotaItem) {
      final c = item as CuotaItem;
      final diff = c.cuota.vencimiento.difference(DateTime.now()).inDays;
      final venceLabel = diff <= 0
          ? 'Vencida'
          : diff == 1
              ? 'Vence mañana'
              : 'Vence en $diff días';
      return (
        AppTheme.dangerSoft,
        const Color(0xFF8B2214),
        Icons.payments_outlined,
        c.cuota.titulo,
        '${_moneyFmt.format(c.cuota.monto)} · $venceLabel',
        'Pagar',
        AppTheme.danger,
        Colors.white,
        () => context.push('/cuotas'),
      );
    }

    if (item is TareaItem) {
      final t = item as TareaItem;
      return (
        AppTheme.accentSoft,
        AppTheme.accentInk,
        Icons.task_alt_rounded,
        t.tarea.titulo,
        'Tarea pendiente',
        'Ver',
        AppTheme.primarySoft,
        AppTheme.primaryInk,
        () => context.push('/tareas'),
      );
    }

    // CampanaItem
    final c = item as CampanaItem;
    final pct = (c.campana.porcentaje * 100).round();
    return (
      AppTheme.goodSoft,
      AppTheme.goodInk,
      Icons.savings_outlined,
      c.campana.titulo,
      '$pct% completado',
      'Aportar',
      AppTheme.goodSoft,
      AppTheme.goodInk,
      () => context.push('/campanas'),
    );
  }
}

// â”€â”€ Empty noticias â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _EmptyNoticias extends StatelessWidget {
  const _EmptyNoticias();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Icon(Icons.newspaper_outlined, size: 56, color: AppTheme.textMuted),
        SizedBox(height: 12),
        Text(
          'No hay noticias aún',
          style: TextStyle(
              color: AppTheme.textMuted, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 4),
        Text(
          'Las novedades de $kGrupoNombre aparecerán acá',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// â”€â”€ Noticia feed card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _NoticiaFeedCard extends ConsumerWidget {
  final FeedNoticiaItem item;
  final String currentUid;
  const _NoticiaFeedCard({required this.item, required this.currentUid});

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes}min';
    if (diff.inHours < 24) return 'hace ${diff.inHours}h';
    if (diff.inDays < 7) return 'hace ${diff.inDays}d';
    return DateFormat('dd/MM/yy').format(dt);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noticia = item.noticia;

    return GestureDetector(
      onTap: () => showNoticiaDetail(context, noticia, kGrupoId),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (noticia.imagenUrl != null)
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(18)),
                child: CachedNetworkImage(
                  imageUrl: noticia.imagenUrl!,
                  width: double.infinity,
                  height: 160,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SGAvatar(
                        name: noticia.autorNombre.isEmpty
                            ? '?'
                            : noticia.autorNombre,
                        size: 28,
                        background: AppTheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              noticia.autorNombre,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _timeAgo(noticia.createdAt),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SGChip(
                        label: noticia.categoria.label,
                        icon: null,
                        tone: SGChipTone.neutral,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    noticia.titulo,
                    style: GoogleFonts.bricolageGrotesque(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      letterSpacing: -0.2,
                      color: AppTheme.text,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (noticia.contenido.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      noticia.contenido,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textMuted,
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.favorite_border_rounded,
                          size: 16, color: AppTheme.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        '${noticia.likesCount}',
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textMuted),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.chat_bubble_outline_rounded,
                          size: 15, color: AppTheme.textMuted),
                      const SizedBox(width: 4),
                      const Text(
                        'Comentar',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.textMuted),
                      ),
                      const Spacer(),
                      if (noticia.fijada)
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.push_pin_rounded,
                                size: 13, color: AppTheme.primary),
                            SizedBox(width: 3),
                            Text(
                              'Fijada',
                              style: TextStyle(
                                  fontSize: 11, color: AppTheme.primary),
                            ),
                          ],
                        ),
                    ],
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
