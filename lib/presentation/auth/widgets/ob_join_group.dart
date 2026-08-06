import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/grupo_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/grupo_provider.dart';
import 'ob_shared.dart';

class OBJoinGroup extends ConsumerStatefulWidget {
  final VoidCallback onBack;
  final void Function(String grupoId, String nombre, Color color) onJoined;

  const OBJoinGroup({
    super.key,
    required this.onBack,
    required this.onJoined,
  });

  @override
  ConsumerState<OBJoinGroup> createState() => _OBJoinGroupState();
}

class _OBJoinGroupState extends ConsumerState<OBJoinGroup>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _searchCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _codeFocus = FocusNode();

  List<GrupoModel> _results = [];
  bool _searching = false;
  bool _loading = false;
  String _codigo = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadSuggestions();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    _codeCtrl.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  Future<void> _loadSuggestions() async {
    setState(() => _searching = true);
    try {
      final results = await ref.read(grupoRepositoryProvider).searchGrupos('');
      if (mounted) setState(() => _results = results.take(8).toList());
    } catch (_) {}
    if (mounted) setState(() => _searching = false);
  }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) { _loadSuggestions(); return; }
    setState(() => _searching = true);
    try {
      final results = await ref.read(grupoRepositoryProvider).searchGrupos(q.trim());
      if (mounted) setState(() => _results = results);
    } catch (_) {}
    if (mounted) setState(() => _searching = false);
  }

  Future<void> _join(GrupoModel grupo) async {
    setState(() => _loading = true);
    try {
      final user = ref.read(authStateProvider).valueOrNull!;
      final userData = await ref.read(currentUserProvider.future);
      await ref.read(grupoRepositoryProvider).joinGrupo(
            grupo.id,
            user.uid,
            userData?.nombreCompleto ?? user.displayName ?? '',
            userData?.avatarUrl ?? user.photoURL,
          );
      if (!mounted) return;
      widget.onJoined(grupo.id, grupo.nombre, grupo.primaryColor);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo unir al grupo')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyCode() async {
    if (_codigo.length < 6) return;
    setState(() => _loading = true);
    try {
      final grupo = await ref
          .read(grupoRepositoryProvider)
          .searchGrupoByCodigo(_codigo.toUpperCase());
      if (!mounted) return;
      if (grupo == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Código inválido. Verificá e intentá de nuevo')),
        );
        setState(() => _loading = false);
        return;
      }
      await _join(grupo);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al verificar el código')),
        );
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: OBBreadcrumb(step: 4, onBack: widget.onBack),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
              child: Text(
                'Buscá tu grupo',
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.txt(context),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Segmented tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.surfAlt(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabs,
                  indicator: BoxDecoration(
                    color: AppTheme.surf(context),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: AppTheme.txt(context),
                  unselectedLabelColor: AppTheme.textMuted,
                  labelStyle: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  tabs: const [Tab(text: 'Buscar'), Tab(text: 'Código')],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _SearchTab(
                    ctrl: _searchCtrl,
                    results: _results,
                    searching: _searching,
                    loading: _loading,
                    onSearch: _search,
                    onJoin: _join,
                  ),
                  _CodeTab(
                    ctrl: _codeCtrl,
                    focusNode: _codeFocus,
                    codigo: _codigo,
                    loading: _loading,
                    onChange: (v) => setState(() => _codigo = v),
                    onVerify: _verifyCode,
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

class _SearchTab extends StatelessWidget {
  final TextEditingController ctrl;
  final List<GrupoModel> results;
  final bool searching;
  final bool loading;
  final void Function(String) onSearch;
  final Future<void> Function(GrupoModel) onJoin;

  const _SearchTab({
    required this.ctrl,
    required this.results,
    required this.searching,
    required this.loading,
    required this.onSearch,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          OBField(
            label: '',
            hint: 'Nombre del grupo o club…',
            icon: Icons.search_rounded,
            controller: ctrl,
            onChanged: onSearch,
          ),
          const SizedBox(height: 16),
          if (searching)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: ListView.separated(
                itemCount: results.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _GrupoRow(
                  grupo: results[i],
                  loading: loading,
                  onJoin: onJoin,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GrupoRow extends StatelessWidget {
  final GrupoModel grupo;
  final bool loading;
  final Future<void> Function(GrupoModel) onJoin;

  const _GrupoRow({
    required this.grupo,
    required this.loading,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    final color = grupo.primaryColor;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.brd(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.groups, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  grupo.nombre,
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.txt(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (grupo.descripcion?.isNotEmpty == true)
                  Text(
                    grupo.descripcion!,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: AppTheme.txtMuted(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: loading ? null : () => onJoin(grupo),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: AppTheme.primarySoft,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Unirme',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryInk,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeTab extends StatelessWidget {
  final TextEditingController ctrl;
  final FocusNode focusNode;
  final String codigo;
  final bool loading;
  final void Function(String) onChange;
  final VoidCallback onVerify;

  const _CodeTab({
    required this.ctrl,
    required this.focusNode,
    required this.codigo,
    required this.loading,
    required this.onChange,
    required this.onVerify,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: AppTheme.primarySoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.qr_code_2_rounded,
                size: 36, color: AppTheme.primary),
          ),
          const SizedBox(height: 20),
          Text(
            'Ingresá el código del grupo',
            style: GoogleFonts.dmSans(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 24),
          Stack(
            alignment: Alignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (i) {
                  final filled = i < codigo.length;
                  return Container(
                    width: 42,
                    height: 54,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: filled ? AppTheme.primarySoft : AppTheme.surf(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: filled ? AppTheme.primary : AppTheme.border,
                        width: filled ? 2 : 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: filled
                        ? Text(
                            codigo[i].toUpperCase(),
                            style: GoogleFonts.bricolageGrotesque(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryInk,
                            ),
                          )
                        : null,
                  );
                }),
              ),
              Opacity(
                opacity: 0,
                child: SizedBox(
                  width: 280,
                  child: TextField(
                    controller: ctrl,
                    focusNode: focusNode,
                    maxLength: 6,
                    textCapitalization: TextCapitalization.characters,
                    keyboardType: TextInputType.text,
                    decoration: const InputDecoration(counterText: ''),
                    onChanged: onChange,
                    autofocus: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          OBBtn(
            'Verificar código',
            onTap: codigo.length < 6 ? null : onVerify,
            isLoading: loading,
          ),
        ],
      ),
    );
  }
}
