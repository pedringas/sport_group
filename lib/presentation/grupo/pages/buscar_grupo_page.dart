import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/sg_widgets.dart';
import '../../../data/models/grupo_model.dart';
import '../../../data/models/enums.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/grupo_provider.dart';

enum _BuscarFiltro { cercaTuyo, populares, recientes, porCodigo }

class BuscarGrupoPage extends ConsumerStatefulWidget {
  const BuscarGrupoPage({super.key});

  @override
  ConsumerState<BuscarGrupoPage> createState() => _BuscarGrupoPageState();
}

class _BuscarGrupoPageState extends ConsumerState<BuscarGrupoPage> {
  final _searchCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  final _focus = FocusNode();

  List<GrupoModel> _results = [];
  bool _searching = false;
  _BuscarFiltro? _filtro;

  // URL navigation
  bool _navigating = false;
  String? _urlError;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _urlCtrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  // â”€â”€ Search by name â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _searching = true);
    final repo = ref.read(grupoRepositoryProvider);
    final results = await repo.searchGrupos(q.trim());
    if (mounted) setState(() { _results = results; _searching = false; });
  }

  Future<void> _unirse(GrupoModel grupo) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    final userData = await ref.read(authRepositoryProvider).getUser(user.uid);
    final repo = ref.read(grupoRepositoryProvider);

    if (grupo.tipo == TipoGrupo.publico) {
      await repo.joinGrupo(
          grupo.id, user.uid, userData?.nombreCompleto ?? '', userData?.avatarUrl);
      if (mounted) context.push('/group/${grupo.id}');
    } else {
      await repo.requestJoinGrupo(
          grupo.id, user.uid, userData?.nombreCompleto ?? '', userData?.avatarUrl);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Solicitud enviada. Esperá la aprobación del administrador.')),
        );
      }
    }
  }

  // â”€â”€ Navigate via URL / ID â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _buscarPorCodigo() async {
    final codigo = _urlCtrl.text.trim().toUpperCase();
    if (codigo.isEmpty) {
      setState(() => _urlError = 'Ingresá el código de invitación.');
      return;
    }
    setState(() { _navigating = true; _urlError = null; });
    final repo = ref.read(grupoRepositoryProvider);
    final grupo = await repo.searchGrupoByCodigo(codigo);
    if (!mounted) return;
    setState(() => _navigating = false);
    if (grupo == null) {
      setState(() => _urlError = 'Código inválido. Verificá que esté bien escrito.');
      return;
    }
    context.push('/join/${grupo.id}');
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      setState(() {
        _urlCtrl.text = data!.text!;
        _urlError = null;
      });
    }
  }

  bool get _showCode =>
      _filtro == _BuscarFiltro.porCodigo;

  @override
  Widget build(BuildContext context) {
    final hasQuery = _searchCtrl.text.isNotEmpty;

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
          'Buscar grupos',
          style: GoogleFonts.bricolageGrotesque(
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: AppTheme.text,
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // â”€â”€ Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded,
                        size: 20, color: AppTheme.textMuted),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        focusNode: _focus,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          hintText: 'Nombre, deporte, barrio...',
                        ),
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w500),
                        onChanged: _search,
                      ),
                    ),
                    if (hasQuery)
                      GestureDetector(
                        onTap: () {
                          _searchCtrl.clear();
                          setState(() => _results = []);
                        },
                        child: const Icon(Icons.close_rounded,
                            size: 18, color: AppTheme.textMuted),
                      ),
                  ],
                ),
              ),
            ),

            // â”€â”€ Filter chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: _BuscarFiltro.values.map((f) {
                  final cfg = switch (f) {
                    _BuscarFiltro.cercaTuyo => (
                      icon: Icons.location_on_rounded,
                      label: 'Cerca tuyo'
                    ),
                    _BuscarFiltro.populares => (
                      icon: Icons.trending_up_rounded,
                      label: 'Populares'
                    ),
                    _BuscarFiltro.recientes => (
                      icon: Icons.schedule_rounded,
                      label: 'Recientes'
                    ),
                    _BuscarFiltro.porCodigo => (
                      icon: Icons.qr_code_2_rounded,
                      label: 'Por código'
                    ),
                  };
                  final sel = _filtro == f;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => setState(
                          () => _filtro = sel ? null : f),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: sel ? AppTheme.primary : AppTheme.surface,
                          borderRadius: BorderRadius.circular(999),
                          border:
                              Border.all(color: sel ? AppTheme.primary : AppTheme.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(cfg.icon,
                                size: 13,
                                color: sel ? Colors.white : AppTheme.textMuted),
                            const SizedBox(width: 5),
                            Text(
                              cfg.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: sel ? Colors.white : AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            // â”€â”€ Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                children: [
                  // Code section
                  if (_showCode) ...[
                    _CodeSection(
                      ctrl: _urlCtrl,
                      navigating: _navigating,
                      error: _urlError,
                      onNavigate: _buscarPorCodigo,
                      onPaste: _pasteFromClipboard,
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Loading
                  if (_searching)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    )

                  // Search results
                  else if (hasQuery && _results.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: SGEyebrow('${_results.length} GRUPOS ENCONTRADOS'),
                    ),
                    ..._results.map((g) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _GrupoCard(
                            grupo: g,
                            onTap: () => context.push('/join/${g.id}'),
                            onUnirse: () => _unirse(g),
                          ),
                        )),
                  ]

                  // No results
                  else if (hasQuery && _results.isEmpty) ...[
                    const SizedBox(height: 60),
                    Center(
                      child: Column(
                        children: [
                          const Icon(Icons.search_off_rounded,
                              size: 48, color: AppTheme.textMuted),
                          const SizedBox(height: 12),
                          Text(
                            'Sin resultados para "${_searchCtrl.text}"',
                            style: const TextStyle(
                                fontSize: 14, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ]

                  // Empty (no query, no special filter)
                  else if (!_showCode) ...[
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 8),
                      child: SGEyebrow('SUGERIDOS PARA VOS'),
                    ),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceAlt,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(Icons.groups_rounded,
                                  size: 36, color: AppTheme.textMuted),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Buscá un grupo',
                              style: GoogleFonts.bricolageGrotesque(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.text,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Escribí el nombre del grupo,\ndeporte o barrio',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textMuted,
                                  height: 1.5),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // QR invite box
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () =>
                          setState(() => _filtro = _BuscarFiltro.porCodigo),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.primarySoft,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
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
                              child: const Icon(Icons.qr_code_2_rounded,
                                  size: 28, color: Colors.white),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '¿Te invitaron por código?',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: AppTheme.primaryInk,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Pegá el link o ID que te compartieron',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.primaryInk.withValues(alpha: 0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded,
                                size: 14, color: AppTheme.primaryInk),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// â”€â”€ Grupo card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _GrupoCard extends StatelessWidget {
  final GrupoModel grupo;
  final VoidCallback onTap;
  final VoidCallback onUnirse;

  const _GrupoCard({
    required this.grupo,
    required this.onTap,
    required this.onUnirse,
  });

  @override
  Widget build(BuildContext context) {
    final isPrivado = grupo.tipo == TipoGrupo.privado;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            SGAvatar(
              name: grupo.nombre,
              imageUrl: grupo.logoUrl,
              size: 48,
              background: AppTheme.primary,
              foreground: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    grupo.nombre,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppTheme.text,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        isPrivado ? Icons.lock_outline_rounded : Icons.public_rounded,
                        size: 11,
                        color: isPrivado ? AppTheme.accent : AppTheme.good,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${isPrivado ? 'Privado' : 'Público'} · ${grupo.miembrosCount} miembros',
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SGPillButton(
              label: isPrivado ? 'Solicitar' : 'Pedir entrar',
              size: SGSize.sm,
              tone: SGTone.soft,
              onPressed: onUnirse,
            ),
          ],
        ),
      ),
    );
  }
}

// â”€â”€ Code / URL section â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _CodeSection extends StatelessWidget {
  final TextEditingController ctrl;
  final bool navigating;
  final String? error;
  final VoidCallback onNavigate;
  final VoidCallback onPaste;

  const _CodeSection({
    required this.ctrl,
    required this.navigating,
    this.error,
    required this.onNavigate,
    required this.onPaste,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.qr_code_2_rounded,
                  size: 22, color: AppTheme.primary),
              const SizedBox(width: 10),
              Text(
                'Unirse con código',
                style: GoogleFonts.bricolageGrotesque(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppTheme.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Ingresá el código que te compartió un miembro del grupo.',
            style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: ctrl,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: 'Ej: ABC1234X',
              prefixIcon:
                  const Icon(Icons.tag_rounded, color: AppTheme.textMuted),
              errorText: error,
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (ctrl.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () => ctrl.clear(),
                    ),
                  IconButton(
                    icon: const Icon(Icons.content_paste_rounded, size: 18),
                    onPressed: onPaste,
                    tooltip: 'Pegar del portapapeles',
                  ),
                ],
              ),
            ),
            onSubmitted: (_) => onNavigate(),
          ),
          const SizedBox(height: 14),
          SGPillButton(
            label: navigating ? 'Buscando…' : 'Buscar grupo',
            icon: Icons.arrow_forward_rounded,
            expand: true,
            onPressed: navigating ? null : onNavigate,
          ),
        ],
      ),
    );
  }
}
