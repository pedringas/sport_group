import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/config/app_config.dart';
import '../../../providers/grupo_provider.dart';
import '../../grupo/pages/miembros_page.dart';
import 'home_feed_page.dart';
import 'agenda_page.dart';
import 'caja_page.dart';
import '../../perfil/pages/perfil_page.dart';

// ── Shell ─────────────────────────────────────────────────────────────────────

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  static const _kDesktopBreakpoint = 900.0;

  static Widget _buildPage(int index) {
    switch (index) {
      case 1: return const AgendaPage();
      case 2: return const CajaPage();
      case 3: return const MiembrosPage(grupoId: kGrupoId, showBackButton: false);
      case 4: return const PerfilPage(showBackButton: false);
      default: return const HomeFeedPage();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // App de grupo único: garantiza pertenencia a Tacheros (auto-ingreso).
    ref.watch(ensureTacherosMembershipProvider);

    final tab = int.tryParse(
          GoRouterState.of(context).uri.queryParameters['tab'] ?? '') ??
        0;
    final currentIndex = tab.clamp(0, 4);
    final isDesktop = MediaQuery.sizeOf(context).width >= _kDesktopBreakpoint;

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: IndexedStack(
        index: currentIndex,
        children: List.generate(5, _buildPage),
      ),
      bottomNavigationBar: isDesktop
          ? null
          : _BottomNav(
              currentIndex: currentIndex,
              onTap: (i) => context.go('/home?tab=$i'),
            ),
    );
  }
}

// ── Bottom nav bar ────────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.currentIndex, required this.onTap});

  static const _items = [
    _NavItem(icon: Icons.home_rounded, label: 'Inicio'),
    _NavItem(icon: Icons.calendar_month_rounded, label: 'Agenda'),
    _NavItem(icon: Icons.payments_outlined, label: 'Cuotas'),
    _NavItem(icon: Icons.groups_rounded, label: 'Miembros'),
    _NavItem(icon: Icons.person_rounded, label: 'Yo'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.border, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_items.length, (i) {
              final item = _items[i];
              final selected = i == currentIndex;
              return GestureDetector(
                onTap: () => onTap(i),
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 64,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: selected
                            ? BoxDecoration(
                                color: AppTheme.primarySoft,
                                borderRadius: BorderRadius.circular(99),
                              )
                            : null,
                        child: Icon(
                          item.icon,
                          size: 22,
                          color: selected
                              ? AppTheme.primary
                              : AppTheme.textMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selected
                              ? AppTheme.primary
                              : AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}
