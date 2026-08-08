import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/enums.dart';
import '../../../providers/grupo_provider.dart';
import '../../../providers/noticia_provider.dart';

// ── Filter categories ─────────────────────────────────────────────────────────

enum _Filtro { todo, eventos, noticias, personas, archivos }

// ── Result model (with navigation) ───────────────────────────────────────────

class _SearchResult {
  final _Filtro tipo;
  final String titulo;
  final String subtitulo;
  final IconData icono;
  final String? grupoId;

  const _SearchResult({
    required this.tipo,
    required this.titulo,
    required this.subtitulo,
    required this.icono,
    this.grupoId,
  });

  void navigate(BuildContext context) {
    switch (tipo) {
      case _Filtro.eventos:
      case _Filtro.noticias:
        context.push('/novedades');
      case _Filtro.personas:
        context.push('/miembros');
      case _Filtro.archivos:
        context.push('/recursos');
      case _Filtro.todo:
        context.go('/home');
    }
  }
}

// ── Page ──────────────────────────────────────────────────────────────────────

class BusquedaGlobalPage extends ConsumerStatefulWidget {
  const BusquedaGlobalPage({super.key});

  @override
  ConsumerState<BusquedaGlobalPage> createState() =>
      _BusquedaGlobalPageState();
}

class _BusquedaGlobalPageState extends ConsumerState<BusquedaGlobalPage> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  String _query = '';
  _Filtro _filtro = _Filtro.todo;
  final List<String> _recents = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  // ── Build real results from providers ────────────────────────────────────

  List<_SearchResult> _buildResults() {
    final q = _query.toLowerCase().trim();
    if (q.isEmpty) return [];

    final results = <_SearchResult>[];

    // ── Noticias & Eventos
    final noticias = ref.watch(noticiasProvider(kGrupoId)).valueOrNull ?? [];
    for (final n in noticias) {
      if (n.caducada) continue;
      final matches = n.titulo.toLowerCase().contains(q) ||
          n.contenido.toLowerCase().contains(q) ||
          n.autorNombre.toLowerCase().contains(q);
      if (!matches) continue;

      results.add(_SearchResult(
        tipo: n.tieneListado ? _Filtro.eventos : _Filtro.noticias,
        titulo: n.titulo,
        subtitulo: n.autorNombre,
        icono: n.tieneListado
            ? Icons.event_rounded
            : Icons.newspaper_rounded,
        grupoId: kGrupoId,
      ));
    }

    // ── Personas (miembros)
    final miembros = ref.watch(miembrosProvider(kGrupoId)).valueOrNull ?? [];
    for (final m in miembros) {
      if (!m.nombreCompleto.toLowerCase().contains(q)) continue;
      final rolLabel = switch (m.rol) {
        RolMiembro.administrador => 'Admin',
        RolMiembro.moderador => 'Moderador',
        RolMiembro.tesorero => 'Tesorero',
        RolMiembro.delegado => 'Delegado',
        RolMiembro.miembro => 'Miembro',
      };
      results.add(_SearchResult(
        tipo: _Filtro.personas,
        titulo: m.nombreCompleto,
        subtitulo: rolLabel,
        icono: Icons.person_rounded,
        grupoId: kGrupoId,
      ));
    }

    // ── Archivos (recursos) — módulo en pausa, excluido de la búsqueda.

    // Deduplicate personas by nombre+grupo (might appear in multiple role streams)
    final seen = <String>{};
    return results.where((r) {
      final key = '${r.tipo.name}|${r.titulo}|${r.grupoId}';
      return seen.add(key);
    }).toList();
  }

  List<_SearchResult> get _filtered {
    final all = _buildResults();
    if (_filtro == _Filtro.todo) return all;
    return all.where((r) => r.tipo == _filtro).toList();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final hasQuery = _query.isNotEmpty;
    final results = _filtered;
    final allResults = _buildResults();

    final isDesktop = MediaQuery.sizeOf(context).width >= AppTheme.kResponsiveBreakpoint;
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Search bar row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: AppTheme.primary, width: 2),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search_rounded,
                              size: 20, color: AppTheme.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _ctrl,
                              focusNode: _focus,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                                hintText: 'Buscar en Tacheros…',
                              ),
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500),
                              onChanged: (v) =>
                                  setState(() => _query = v),
                              onSubmitted: (v) {
                                final t = v.trim();
                                if (t.isNotEmpty &&
                                    !_recents.contains(t)) {
                                  setState(
                                      () => _recents.insert(0, t));
                                }
                              },
                            ),
                          ),
                          if (hasQuery)
                            GestureDetector(
                              onTap: () {
                                _ctrl.clear();
                                setState(() => _query = '');
                              },
                              child: const Icon(Icons.close_rounded,
                                  size: 18, color: AppTheme.textMuted),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (!isDesktop) ...[
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── Filter chips
            if (hasQuery)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 4),
                child: Row(
                  // "Archivos" (recursos) en pausa — se excluye del filtro.
                  children: _Filtro.values
                      .where((f) => f != _Filtro.archivos)
                      .map((f) {
                    final labels = {
                      _Filtro.todo: 'Todo',
                      _Filtro.eventos: 'Eventos',
                      _Filtro.noticias: 'Noticias',
                      _Filtro.personas: 'Personas',
                      _Filtro.archivos: 'Archivos',
                    };
                    final counts = {
                      _Filtro.todo: allResults.length,
                      _Filtro.eventos:
                          allResults.where((r) => r.tipo == _Filtro.eventos).length,
                      _Filtro.noticias:
                          allResults.where((r) => r.tipo == _Filtro.noticias).length,
                      _Filtro.personas:
                          allResults.where((r) => r.tipo == _Filtro.personas).length,
                      _Filtro.archivos:
                          allResults.where((r) => r.tipo == _Filtro.archivos).length,
                    };
                    final sel = f == _filtro;
                    final count = counts[f] ?? 0;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: GestureDetector(
                        onTap: () => setState(() => _filtro = f),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: sel
                                ? AppTheme.primary
                                : AppTheme.surface,
                            borderRadius: BorderRadius.circular(999),
                            border: sel
                                ? null
                                : Border.all(color: AppTheme.border),
                          ),
                          child: Text(
                            count > 0
                                ? '${labels[f]} · $count'
                                : labels[f]!,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: sel ? Colors.white : AppTheme.text,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

            // ── Results or recent searches
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 60),
                children: [
                  if (!hasQuery) ...[
                    if (_recents.isNotEmpty) ...[
                      const _Eyebrow('Búsquedas recientes'),
                      const SizedBox(height: 4),
                      ..._recents.asMap().entries.map((e) =>
                          GestureDetector(
                            onTap: () {
                              _ctrl.text = e.value;
                              setState(() => _query = e.value);
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 2),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                borderRadius:
                                    BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.history_rounded,
                                      size: 18,
                                      color: AppTheme.textMuted),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(e.value,
                                        style: const TextStyle(
                                            fontSize: 14)),
                                  ),
                                  GestureDetector(
                                    onTap: () => setState(() =>
                                        _recents.removeAt(e.key)),
                                    child: const Icon(
                                        Icons.close_rounded,
                                        size: 16,
                                        color: AppTheme.textMuted),
                                  ),
                                ],
                              ),
                            ),
                          )),
                    ] else
                      const Padding(
                        padding:
                            EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          children: [
                            Icon(Icons.search_rounded,
                                size: 48, color: AppTheme.border),
                            SizedBox(height: 12),
                            Text('Escribí para buscar',
                                style: TextStyle(
                                    fontSize: 14,
                                    color: AppTheme.textMuted)),
                            SizedBox(height: 4),
                            Text(
                                'Noticias, personas, archivos y eventos\nde todos tus grupos',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textMuted)),
                          ],
                        ),
                      ),
                  ] else if (results.isEmpty) ...[
                    const SizedBox(height: 60),
                    Center(
                      child: Column(
                        children: [
                          const Icon(Icons.search_off_rounded,
                              size: 48, color: AppTheme.textMuted),
                          const SizedBox(height: 12),
                          Text('Sin resultados para "$_query"',
                              style: const TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.textMuted)),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Top match
                    const _Eyebrow('Mejor coincidencia'),
                    const SizedBox(height: 8),
                    _TopMatch(result: results.first, query: _query),
                    const SizedBox(height: 20),

                    // Eventos
                    ..._section(
                      context,
                      label: 'Eventos',
                      tipo: _Filtro.eventos,
                      results: results,
                      iconBg: AppTheme.primarySoft,
                      iconColor: AppTheme.primaryInk,
                    ),

                    // Noticias
                    ..._section(
                      context,
                      label: 'Noticias',
                      tipo: _Filtro.noticias,
                      results: results,
                      iconBg: AppTheme.accentSoft,
                      iconColor: AppTheme.accent,
                    ),

                    // Personas
                    ..._section(
                      context,
                      label: 'Personas',
                      tipo: _Filtro.personas,
                      results: results,
                      iconBg: AppTheme.surfaceAlt,
                      iconColor: AppTheme.textMuted,
                    ),

                    // Archivos
                    ..._section(
                      context,
                      label: 'Archivos',
                      tipo: _Filtro.archivos,
                      results: results,
                      iconBg: AppTheme.surfaceAlt,
                      iconColor: AppTheme.textMuted,
                    ),
                  ],
                ],
              ),
            ),
          ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _section(
    BuildContext context, {
    required String label,
    required _Filtro tipo,
    required List<_SearchResult> results,
    required Color iconBg,
    required Color iconColor,
  }) {
    final items = results.where((r) => r.tipo == tipo).toList();
    if (items.isEmpty) return [];
    return [
      _Eyebrow(label),
      const SizedBox(height: 8),
      _ResultSection(
        results: items,
        iconBg: iconBg,
        iconColor: iconColor,
      ),
      const SizedBox(height: 20),
    ];
  }
}

// ── Eyebrow label ─────────────────────────────────────────────────────────────

class _Eyebrow extends StatelessWidget {
  final String text;
  const _Eyebrow(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2, left: 2),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: AppTheme.textMuted,
        ),
      ),
    );
  }
}

// ── Top match card ────────────────────────────────────────────────────────────

class _TopMatch extends StatelessWidget {
  final _SearchResult result;
  final String query;
  const _TopMatch({required this.result, required this.query});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => result.navigate(context),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.primarySoft,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.primary),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child:
                  Icon(result.icono, size: 24, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.titulo,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppTheme.primaryInk,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    result.subtitulo,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.primaryInk),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: AppTheme.primaryInk),
          ],
        ),
      ),
    );
  }
}

// ── Result section ────────────────────────────────────────────────────────────

class _ResultSection extends StatelessWidget {
  final List<_SearchResult> results;
  final Color iconBg;
  final Color iconColor;
  const _ResultSection({
    required this.results,
    required this.iconBg,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: results.asMap().entries.map((e) {
          final r = e.value;
          return Column(
            children: [
              if (e.key > 0)
                const Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: AppTheme.border),
              InkWell(
                onTap: () => r.navigate(context),
                borderRadius: BorderRadius.circular(e.key == 0
                    ? 16
                    : e.key == results.length - 1
                        ? 16
                        : 0),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: iconBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child:
                            Icon(r.icono, size: 20, color: iconColor),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.titulo,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Text(r.subtitulo,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textMuted),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          size: 18, color: AppTheme.textMuted),
                    ],
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
