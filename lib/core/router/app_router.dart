import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../presentation/auth/pages/splash_page.dart';
import '../../presentation/auth/pages/login_page.dart';
import '../../presentation/auth/pages/onboarding_page.dart';
import '../../presentation/auth/pages/register_page.dart';
import '../../presentation/auth/pages/otp_page.dart';
import '../../presentation/auth/pages/forgot_password_page.dart';
import '../../presentation/home/pages/home_shell.dart';
import '../../presentation/home/pages/agenda_page.dart';
import '../../presentation/perfil/pages/perfil_page.dart';
import '../../presentation/perfil/pages/editar_perfil_page.dart';
import '../../presentation/grupo/pages/crear_grupo_page.dart';
import '../../presentation/grupo/pages/grupo_page.dart';
import '../../presentation/grupo/pages/grupo_settings_page.dart';
import '../../presentation/grupo/pages/buscar_grupo_page.dart';
import '../../presentation/grupo/pages/crear_evento_page.dart';
import '../../presentation/grupo/pages/comentarios_page.dart';
import '../../presentation/cuota/pages/cuota_detail_page.dart';
import '../../presentation/cuota/pages/cuotas_tab.dart';
import '../../presentation/cuota/pages/crear_cuota_page.dart';
import '../../presentation/cuota/pages/pago_manual_page.dart';
import '../../presentation/campana/pages/campana_detail_page.dart';
import '../../presentation/campana/pages/campanas_tab.dart';
import '../../presentation/gasto/pages/gastos_tab.dart';
import '../../presentation/gasto/pages/crear_gasto_page.dart';
import '../../presentation/gasto/pages/grupo_gasto_detail_page.dart';
import '../../data/models/gasto_model.dart';
import '../../presentation/home/pages/notificaciones_page.dart';
import '../../presentation/recurso/pages/recursos_tab.dart';
import '../../presentation/recurso/pages/archivo_preview_page.dart';
import '../../presentation/tarea/pages/tareas_tab.dart';
import '../../presentation/tarea/pages/crear_tarea_page.dart';
import '../../presentation/grupo/widgets/noticias_tab.dart';
import '../../presentation/admin/pages/admin_panel_page.dart';
import '../../presentation/mod/pages/moderador_panel_page.dart';
import '../../presentation/delegado/pages/delegado_panel_page.dart';
import '../../presentation/tesorero/pages/tesorero_panel_page.dart';
import '../../presentation/faq/pages/faq_page.dart';
import '../../presentation/grupo/pages/join_group_page.dart';
import '../../presentation/grupo/pages/miembros_page.dart';
import '../../presentation/busqueda/pages/busqueda_global_page.dart';
import '../../presentation/shell/responsive_shell.dart';
import '../../providers/auth_provider.dart';

// ── Auth notifier ─────────────────────────────────────────────────────────────

class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier(Ref ref) {
    ref.listen(authStateProvider, (_, __) => notifyListeners());
  }
}

// ── Scaffold wrapper for existing tab widgets ─────────────────────────────────

class _TabPage extends StatelessWidget {
  final String title;
  final Widget child;
  const _TabPage({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: child,
    );
  }
}

// ── Router ────────────────────────────────────────────────────────────────────

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = _AuthNotifier(ref);
  ref.onDispose(authNotifier.dispose);

  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final isAuth = ref.read(authStateProvider).valueOrNull != null;
      final loc = state.matchedLocation;
      if (loc.startsWith('/join/')) return null;
      final onAuthScreen =
          ['/splash', '/onboarding', '/login', '/register', '/otp', '/forgot-password']
              .contains(loc);
      if (isAuth && onAuthScreen && loc != '/splash') {
        // After login, honour a ?redirect param (e.g. /login?redirect=/join/abc)
        final redirectTo = state.uri.queryParameters['redirect'];
        return redirectTo ?? '/home';
      }
      if (!isAuth && !onAuthScreen) return '/login';
      return null;
    },
    routes: [
      // ── Auth (outside shell)
      GoRoute(path: '/splash', builder: (_, __) => const SplashPage()),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingPage()),
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterPage()),
      GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordPage()),
      GoRoute(
        path: '/otp',
        builder: (_, state) =>
            OtpPage(extra: state.extra as Map<String, dynamic>),
      ),
      GoRoute(
        path: '/join/:groupId',
        builder: (_, state) =>
            JoinGroupPage(grupoId: state.pathParameters['groupId']!),
      ),

      // ── Authenticated shell (desktop sidebar + topbar on ≥900px)
      ShellRoute(
        builder: (context, state, child) =>
            ResponsiveShell(child: child),
        routes: [
          // ── Home (shell with bottom nav + 5 tabs)
          GoRoute(
            path: '/home',
            builder: (_, state) {
              final tab = int.tryParse(
                      state.uri.queryParameters['tab'] ?? '') ??
                  0;
              return HomeShell(initialTab: tab);
            },
          ),
          GoRoute(
              path: '/notificaciones',
              builder: (_, __) => const NotificacionesPage()),
          GoRoute(
              path: '/profile',
              builder: (_, __) => const PerfilPage()),
          GoRoute(
              path: '/profile/edit',
              builder: (_, __) => const EditarPerfilPage()),
          GoRoute(
              path: '/search',
              builder: (_, __) => const BuscarGrupoPage()),
          GoRoute(
              path: '/busqueda',
              builder: (_, __) => const BusquedaGlobalPage()),
          GoRoute(
              path: '/create-group',
              builder: (_, __) => const CrearGrupoPage()),
          GoRoute(
              path: '/faq', builder: (_, __) => const FaqPage()),

          // ── Grupo hub — curtain entry (slides up from bottom, 500ms)
          GoRoute(
            path: '/group/:groupId',
            pageBuilder: (_, state) => CustomTransitionPage(
              key: state.pageKey,
              child: GrupoPage(grupoId: state.pathParameters['groupId']!),
              transitionDuration: const Duration(milliseconds: 500),
              reverseTransitionDuration: const Duration(milliseconds: 380),
              transitionsBuilder: (_, animation, __, child) {
                final slide = animation.drive(
                  Tween(begin: const Offset(0, 1), end: Offset.zero).chain(
                    CurveTween(curve: const Cubic(0.2, 0.85, 0.25, 1)),
                  ),
                );
                return SlideTransition(position: slide, child: child);
              },
            ),
          ),
          GoRoute(
            path: '/group/:groupId/settings',
            builder: (_, state) =>
                GrupoSettingsPage(grupoId: state.pathParameters['groupId']!),
          ),

          // ── Miembros
          GoRoute(
            path: '/group/:groupId/miembros',
            builder: (_, state) =>
                MiembrosPage(grupoId: state.pathParameters['groupId']!),
          ),

          // ── Noticias + comentarios — slide in from right
          GoRoute(
            path: '/group/:groupId/noticias',
            pageBuilder: (_, state) => CustomTransitionPage(
              key: state.pageKey,
              child: _TabPage(
                title: 'Novedades',
                child: NoticiasTab(grupoId: state.pathParameters['groupId']!),
              ),
              transitionDuration: const Duration(milliseconds: 360),
              reverseTransitionDuration: const Duration(milliseconds: 280),
              transitionsBuilder: (_, animation, __, child) {
                final slide = animation.drive(
                  Tween(begin: const Offset(1, 0), end: Offset.zero).chain(
                    CurveTween(curve: const Cubic(0.2, 0.85, 0.25, 1)),
                  ),
                );
                return SlideTransition(position: slide, child: child);
              },
            ),
          ),
          GoRoute(
            path: '/group/:groupId/noticias/:noticiaId/comentarios',
            builder: (_, state) => ComentariosPage(
              grupoId: state.pathParameters['groupId']!,
              noticiaId: state.pathParameters['noticiaId']!,
              noticiaTitle:
                  state.uri.queryParameters['titulo'] ?? 'Noticia',
            ),
          ),

          // ── Agenda del grupo (tab in group hub — uses global AgendaPage)
          GoRoute(
            path: '/group/:groupId/agenda',
            pageBuilder: (_, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const _TabPage(
                title: 'Agenda',
                child: AgendaPage(),
              ),
              transitionDuration: const Duration(milliseconds: 360),
              reverseTransitionDuration: const Duration(milliseconds: 280),
              transitionsBuilder: (_, animation, __, child) {
                final slide = animation.drive(
                  Tween(begin: const Offset(1, 0), end: Offset.zero).chain(
                    CurveTween(curve: const Cubic(0.2, 0.85, 0.25, 1)),
                  ),
                );
                return SlideTransition(position: slide, child: child);
              },
            ),
          ),

          // ── Cuotas
          GoRoute(
            path: '/group/:groupId/cuotas',
            builder: (_, state) => _TabPage(
              title: 'Cuotas',
              child: CuotasTab(
                  grupoId: state.pathParameters['groupId']!),
            ),
          ),
          GoRoute(
            path: '/group/:groupId/cuotas/crear',
            builder: (_, state) =>
                CrearCuotaPage(grupoId: state.pathParameters['groupId']!),
          ),

          // ── Gastos
          GoRoute(
            path: '/group/:groupId/gastos',
            builder: (_, state) =>
                GastosTab(grupoId: state.pathParameters['groupId']!),
          ),
          GoRoute(
            path: '/group/:groupId/gastos/crear',
            builder: (_, state) {
              final extra = state.extra as Map<String, dynamic>?;
              return CrearGastoPage(
                grupoId: state.pathParameters['groupId']!,
                grupoGastoId: extra?['grupoGastoId'] as String?,
                grupoGastoNombre: extra?['grupoGastoNombre'] as String?,
                gastoExistente: extra?['gastoExistente'] as GastoModel?,
              );
            },
          ),
          GoRoute(
            path: '/group/:groupId/gastos/g/:grupoGastoId',
            builder: (_, state) {
              final raw = state.pathParameters['grupoGastoId']!;
              return GrupoGastoDetailPage(
                grupoId: state.pathParameters['groupId']!,
                grupoGastoId: raw == 'general' ? null : raw,
              );
            },
          ),

          // ── Tareas
          GoRoute(
            path: '/group/:groupId/tareas',
            builder: (_, state) =>
                TareasTab(grupoId: state.pathParameters['groupId']!),
          ),
          GoRoute(
            path: '/group/:groupId/tareas/crear',
            builder: (_, state) =>
                CrearTareaPage(grupoId: state.pathParameters['groupId']!),
          ),

          // ── Recursos + archivo preview
          GoRoute(
            path: '/group/:groupId/recursos',
            builder: (_, state) => _TabPage(
              title: 'Recursos',
              child: RecursosTab(
                  grupoId: state.pathParameters['groupId']!),
            ),
          ),
          GoRoute(
            path: '/group/:groupId/recurso/:recursoId',
            builder: (_, state) => ArchivoPreviewPage(
              grupoId: state.pathParameters['groupId']!,
              recursoId: state.pathParameters['recursoId']!,
            ),
          ),

          // ── Campañas
          GoRoute(
            path: '/group/:groupId/campanas',
            builder: (_, state) => _TabPage(
              title: 'Campañas',
              child: CampanasTab(
                  grupoId: state.pathParameters['groupId']!),
            ),
          ),

          // ── Eventos
          GoRoute(
            path: '/group/:groupId/evento/crear',
            builder: (_, state) =>
                CrearEventoPage(grupoId: state.pathParameters['groupId']!),
          ),

          // ── Cuota detail & payment
          GoRoute(
            path: '/group/:groupId/cuota/:cuotaId',
            builder: (_, state) => CuotaDetailPage(
              grupoId: state.pathParameters['groupId']!,
              cuotaId: state.pathParameters['cuotaId']!,
            ),
          ),
          GoRoute(
            path: '/group/:groupId/cuota/:cuotaId/pay/manual',
            builder: (_, state) => PagoManualPage(
              grupoId: state.pathParameters['groupId']!,
              cuotaId: state.pathParameters['cuotaId']!,
            ),
          ),
          // ── Campaña detail
          GoRoute(
            path: '/group/:groupId/campana/:campanaId',
            builder: (_, state) => CampanaDetailPage(
              grupoId: state.pathParameters['groupId']!,
              campanaId: state.pathParameters['campanaId']!,
            ),
          ),

          // ── Role panels
          GoRoute(
            path: '/group/:groupId/admin',
            builder: (_, state) =>
                AdminPanelPage(grupoId: state.pathParameters['groupId']!),
          ),
          GoRoute(
            path: '/group/:groupId/moderador',
            builder: (_, state) =>
                ModeradorPanelPage(grupoId: state.pathParameters['groupId']!),
          ),
          GoRoute(
            path: '/group/:groupId/tesorero',
            builder: (_, state) =>
                TesoreroPanelPage(grupoId: state.pathParameters['groupId']!),
          ),
          GoRoute(
            path: '/group/:groupId/delegado',
            builder: (_, state) =>
                DelegadoPanelPage(grupoId: state.pathParameters['groupId']!),
          ),
        ],
      ),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});
