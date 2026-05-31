import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import 'home_feed_page.dart';
import 'grupos_list_page.dart';
import 'agenda_page.dart';
import 'caja_page.dart';
import '../../perfil/pages/perfil_page.dart';

// â”€â”€ Bottom nav index â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

enum _Tab { inicio, grupos, agenda, caja, yo }

// â”€â”€ Shell â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class HomeShell extends ConsumerStatefulWidget {
  /// Optional initial tab index passed via query param.
  final int initialTab;
  const HomeShell({super.key, this.initialTab = 0});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  late int _currentIndex;

  static const _tabs = [
    _Tab.inicio,
    _Tab.grupos,
    _Tab.agenda,
    _Tab.caja,
    _Tab.yo,
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab.clamp(0, _tabs.length - 1);
  }

  Widget _buildPage(int index) {
    switch (_tabs[index]) {
      case _Tab.inicio:
        return const HomeFeedPage();
      case _Tab.grupos:
        return const GruposListPage();
      case _Tab.agenda:
        return const AgendaPage();
      case _Tab.caja:
        return const CajaPage();
      case _Tab.yo:
        return const PerfilPage(showBackButton: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: IndexedStack(
        index: _currentIndex,
        children: List.generate(_tabs.length, _buildPage),
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

// â”€â”€ Bottom nav bar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.currentIndex, required this.onTap});

  static const _items = [
    _NavItem(icon: Icons.home_rounded, label: 'Inicio'),
    _NavItem(icon: Icons.groups_rounded, label: 'Grupos'),
    _NavItem(icon: Icons.calendar_month_rounded, label: 'Agenda'),
    _NavItem(icon: Icons.account_balance_wallet_outlined, label: 'Caja'),
    _NavItem(icon: Icons.person_rounded, label: 'Yo'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
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
