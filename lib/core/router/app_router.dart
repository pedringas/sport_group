import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/app_config.dart';
import '../theme/app_theme.dart';
import '../../presentation/auth/pages/splash_page.dart';
import '../../presentation/auth/pages/login_page.dart';
import '../../presentation/auth/pages/onboarding_page.dart';
import '../../presentation/auth/pages/register_page.dart';
import '../../presentation/auth/pages/otp_page.dart';
import '../../presentation/auth/pages/forgot_password_page.dart';
import '../../presentation/home/pages/home_shell.dart';
import '../../presentation/perfil/pages/perfil_page.dart';
import '../../presentation/perfil/pages/editar_perfil_page.dart';
import '../../presentation/grupo/pages/grupo_settings_page.dart';
import '../../presentation/grupo/pages/crear_evento_page.dart';
import '../../presentation/grupo/pages/comentarios_page.dart';
import '../../presentation/cuota/pages/cuota_detail_page.dart';
import '../../presentation/cuota/pages/cuotas_tab.dart';
import '../../presentation/cuota/pages/crear_cuota_page.dart';
import '../../presentation/cuota/pages/crear_cuota_grupo_page.dart';
import '../../presentation/cuota/pages/cuota_grupo_detail_page.dart';
import '../../presentation/cuota/pages/suscripciones_page.dart';
import '../../presentation/cuota/pages/pago_manual_page.dart';
import '../../data/models/cuota_grupo_model.dart';
import '../../presentation/campana/pages/campana_detail_page.dart';
import '../../presentation/campana/pages/campanas_tab.dart';
import '../../presentation/gasto/pages/gastos_tab.dart';
import '../../presentation/gasto/pages/crear_gasto_page.dart';
import '../../presentation/gasto/pages/grupo_gasto_detail_page.dart';
import '../../data/models/gasto_model.dart';
import '../../data/models/cuota_model.dart';
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
    final isDesktop = MediaQuery.sizeOf(context).width >= AppTheme.kResponsiveBreakpoint;
    return Scaffold(
      appBar: isDesktop ? null : AppBar(title: Text(title)),
      body: child,
    );
  }
}

// ── Router ────────────────────────────────────────────────────────────────────
//
// App de grupo único: no existen rutas anidadas por grupo. Cada sección tiene
// una ruta plana y las páginas reciben [kGrupoId] desde el builder, conservando
// su parámetro `grupoId` original.

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = _AuthNotifier(ref);
  ref.onDispose(authNotifier.dispose);

  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final loc = state.matchedLocation;

      // Compatibilidad con enlaces del modelo multi-grupo: /group/<id>/x → /x
      if (loc.startsWith('/group/')) {
        final rest = loc.replaceFirst(RegExp(r'^/group/[^/]+'), '');
        final query = state.uri.query;
        final target = rest.isEmpty ? '/home' : rest;
        return query.isEmpty ? target : '$target?$query';
      }
      // Los enlaces de invitación ya no aplican: el ingreso al grupo es automático.
      if (loc.startsWith('/join/')) return '/home';

      final isAuth = ref.read(authStateProvider).valueOrNull != null;
      if (loc == '/onboarding') return null;
      final onAuthScreen =
          ['/splash', '/login', '/register', '/otp', '/forgot-password']
              .contains(loc);
      if (isAuth && onAuthScreen && loc != '/splash') {
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
      GoRoute(
          path: '/forgot-password',
          builder: (_, __) => const ForgotPasswordPage()),
      GoRoute(
        path: '/otp',
        builder: (_, state) =>
            OtpPage(extra: (state.extra as Map<String, dynamic>?) ?? const {}),
      ),

      // ── Authenticated shell (desktop sidebar + topbar on ≥900px)
      ShellRoute(
        builder: (context, state, child) => ResponsiveShell(child: child),
        routes: [
          // ── Shell tabs: Inicio · Agenda · Caja · Miembros · Yo
          GoRoute(path: '/home', builder: (_, __) => const HomeShell()),

          // ── Cuenta
          GoRoute(
              path: '/notificaciones',
              builder: (_, __) => const NotificacionesPage()),
          GoRoute(path: '/profile', builder: (_, __) => const PerfilPage()),
          GoRoute(
              path: '/profile/edit',
              builder: (_, __) => const EditarPerfilPage()),
          GoRoute(
              path: '/busqueda',
              builder: (_, __) => const BusquedaGlobalPage()),
          GoRoute(path: '/faq', builder: (_, __) => const FaqPage()),

          // ── Grupo
          GoRoute(
              path: '/ajustes',
              builder: (_, __) => const GrupoSettingsPage(grupoId: kGrupoId)),
          GoRoute(
              path: '/miembros',
              builder: (_, __) => const MiembrosPage(grupoId: kGrupoId)),

          // ── Novedades + comentarios — slide in from right
          GoRoute(
            path: '/novedades',
            pageBuilder: (_, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const _TabPage(
                title: 'Novedades',
                child: NoticiasTab(grupoId: kGrupoId),
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
            path: '/novedades/:noticiaId/comentarios',
            builder: (_, state) => ComentariosPage(
              grupoId: kGrupoId,
              noticiaId: state.pathParameters['noticiaId']!,
              noticiaTitle: state.uri.queryParameters['titulo'] ?? 'Noticia',
            ),
          ),
          GoRoute(
              path: '/evento/crear',
              builder: (_, __) => const CrearEventoPage(grupoId: kGrupoId)),

          // ── Cuotas
          GoRoute(
            path: '/cuotas',
            builder: (_, __) => const _TabPage(
              title: 'Cuotas',
              child: CuotasTab(grupoId: kGrupoId),
            ),
          ),
          GoRoute(
              path: '/cuotas/crear',
              builder: (_, __) => const CrearCuotaPage(grupoId: kGrupoId)),
          GoRoute(
            path: '/cuota/:cuotaId/edit',
            builder: (_, state) => CrearCuotaPage(
              grupoId: kGrupoId,
              cuotaParaEditar: state.extra as CuotaModel?,
            ),
          ),
          GoRoute(
              path: '/suscripciones',
              builder: (_, __) => const SuscripcionesPage(grupoId: kGrupoId)),
          // Rutas de "grupos de suscripción" (/cuotas/grupo/...) retiradas:
          // el módulo está en pausa porque nada convierte esos grupos en
          // cuotas reales. Sus páginas siguen en el repo.
          GoRoute(
            path: '/cuota/:cuotaId',
            builder: (_, state) => CuotaDetailPage(
              grupoId: kGrupoId,
              cuotaId: state.pathParameters['cuotaId']!,
            ),
          ),
          GoRoute(
            path: '/cuota/:cuotaId/pay/manual',
            builder: (_, state) => PagoManualPage(
              grupoId: kGrupoId,
              cuotaId: state.pathParameters['cuotaId']!,
            ),
          ),

          // ── Gastos
          GoRoute(
              path: '/gastos',
              builder: (_, __) => const GastosTab(grupoId: kGrupoId)),
          GoRoute(
            path: '/gastos/crear',
            builder: (_, state) {
              final extra = state.extra as Map<String, dynamic>?;
              return CrearGastoPage(
                grupoId: kGrupoId,
                grupoGastoId: extra?['grupoGastoId'] as String?,
                grupoGastoNombre: extra?['grupoGastoNombre'] as String?,
                gastoExistente: extra?['gastoExistente'] as GastoModel?,
              );
            },
          ),
          GoRoute(
            path: '/gastos/g/:grupoGastoId',
            builder: (_, state) => GrupoGastoDetailPage(
              grupoId: kGrupoId,
              grupoGastoId: state.pathParameters['grupoGastoId']!,
            ),
          ),

          // ── Panel de administración
          GoRoute(
              path: '/admin',
              builder: (_, __) => const AdminPanelPage(grupoId: kGrupoId)),

          // ── Módulos y roles en pausa: rutas vivas, sin accesos desde la UI.
          GoRoute(
              path: '/moderador',
              builder: (_, __) => const ModeradorPanelPage(grupoId: kGrupoId)),
          GoRoute(
              path: '/tesorero',
              builder: (_, __) => const TesoreroPanelPage(grupoId: kGrupoId)),
          GoRoute(
              path: '/delegado',
              builder: (_, __) => const DelegadoPanelPage(grupoId: kGrupoId)),
          GoRoute(
              path: '/tareas',
              builder: (_, __) => const TareasTab(grupoId: kGrupoId)),
          GoRoute(
              path: '/tareas/crear',
              builder: (_, __) => const CrearTareaPage(grupoId: kGrupoId)),
          GoRoute(
            path: '/recursos',
            builder: (_, __) => const _TabPage(
              title: 'Recursos',
              child: RecursosTab(grupoId: kGrupoId),
            ),
          ),
          GoRoute(
            path: '/recurso/:recursoId',
            builder: (_, state) => ArchivoPreviewPage(
              grupoId: kGrupoId,
              recursoId: state.pathParameters['recursoId']!,
            ),
          ),
          GoRoute(
            path: '/campanas',
            builder: (_, __) => const _TabPage(
              title: 'Campañas',
              child: CampanasTab(grupoId: kGrupoId),
            ),
          ),
          GoRoute(
            path: '/campana/:campanaId',
            builder: (_, state) => CampanaDetailPage(
              grupoId: kGrupoId,
              campanaId: state.pathParameters['campanaId']!,
            ),
          ),
        ],
      ),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});
