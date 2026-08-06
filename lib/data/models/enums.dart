enum TipoGrupo { publico, privado }

enum RolMiembro { administrador, moderador, tesorero, delegado, miembro }

/// Roles habilitados en la versión "básica" actual de la app.
/// Los roles en pausa (moderador, tesorero, delegado) siguen existiendo en el
/// modelo pero se ocultan de los selectores de rol. Para reactivarlos, volver a
/// usar `RolMiembro.values` en los pickers o agregarlos a esta lista.
const List<RolMiembro> rolesAsignables = [
  RolMiembro.administrador,
  RolMiembro.miembro,
];

extension RolMiembroX on RolMiembro {
  bool get puedeGestionarMiembros =>
      this == RolMiembro.administrador || this == RolMiembro.moderador;
  bool get puedeGestionarCuotas =>
      this == RolMiembro.administrador || this == RolMiembro.tesorero;
  bool get puedePublicarNoticias => this != RolMiembro.miembro;
  bool get esAdmin => this == RolMiembro.administrador;
  bool get puedeGestionarCampanas =>
      this == RolMiembro.administrador || this == RolMiembro.tesorero;
}

enum EstadoMiembro { activo, pendiente, bloqueado }

enum EstadoPago { pendiente, validando, aprobado, revision }
enum MetodoPago { transferencia, efectivo }

enum EstadoSolicitud { pendiente, aprobado, rechazado }

// ── Cuotas recurrentes ────────────────────────────────────────────────────────

enum FrecuenciaCuota { semanal, quincenal, mensual, bimestral, trimestral, anual }

extension FrecuenciaCuotaX on FrecuenciaCuota {
  String get label => switch (this) {
        FrecuenciaCuota.semanal => 'Semanal',
        FrecuenciaCuota.quincenal => 'Quincenal',
        FrecuenciaCuota.mensual => 'Mensual',
        FrecuenciaCuota.bimestral => 'Bimestral',
        FrecuenciaCuota.trimestral => 'Trimestral',
        FrecuenciaCuota.anual => 'Anual',
      };

  /// Days between payments
  int get dias => switch (this) {
        FrecuenciaCuota.semanal => 7,
        FrecuenciaCuota.quincenal => 15,
        FrecuenciaCuota.mensual => 30,
        FrecuenciaCuota.bimestral => 60,
        FrecuenciaCuota.trimestral => 90,
        FrecuenciaCuota.anual => 365,
      };
}

// ── Campañas (crowdfunding) ───────────────────────────────────────────────────

enum EstadoCampana { activa, completada, cancelada }

extension EstadoCampanaX on EstadoCampana {
  String get label => switch (this) {
        EstadoCampana.activa => 'Activa',
        EstadoCampana.completada => 'Completada',
        EstadoCampana.cancelada => 'Cancelada',
      };
}

enum EstadoAporte { pendiente, validando, aprobado, rechazado }

// ── Tareas ────────────────────────────────────────────────────────────────────

enum TareaEstado { pendiente, en_curso, completada, cancelada }

extension TareaEstadoX on TareaEstado {
  String get label => switch (this) {
        TareaEstado.pendiente => 'Pendiente',
        TareaEstado.en_curso => 'En curso',
        TareaEstado.completada => 'Completada',
        TareaEstado.cancelada => 'Cancelada',
      };
  String get emoji => switch (this) {
        TareaEstado.pendiente => '🔴',
        TareaEstado.en_curso => '🟡',
        TareaEstado.completada => '🟢',
        TareaEstado.cancelada => '⚫',
      };
}

// ── Noticias categorías ───────────────────────────────────────────────────────

enum NoticiaCategoria { general, entrenamiento, partido, evento, aviso }

extension NoticiaCategoriaX on NoticiaCategoria {
  String get label => switch (this) {
        NoticiaCategoria.general => 'General',
        NoticiaCategoria.entrenamiento => 'Entrenamiento',
        NoticiaCategoria.partido => 'Partido',
        NoticiaCategoria.evento => 'Evento',
        NoticiaCategoria.aviso => 'Aviso',
      };
  String get emoji => switch (this) {
        NoticiaCategoria.general => '📰',
        NoticiaCategoria.entrenamiento => '🏃',
        NoticiaCategoria.partido => '⚽',
        NoticiaCategoria.evento => '🎉',
        NoticiaCategoria.aviso => '📢',
      };
}

// ── Grupos de gastos ──────────────────────────────────────────────────────────

enum EstadoGrupoGasto { abierto, cerrado }

extension RolMiembroExtra on RolMiembro {
  bool get puedeGestionarTareas =>
      this != RolMiembro.miembro; // all staff roles
  bool get puedeCerrarGrupoGasto =>
      this == RolMiembro.administrador ||
      this == RolMiembro.tesorero ||
      this == RolMiembro.moderador;

  /// Can edit or delete any gasto (regardless of who created it).
  bool get puedeEditarGasto =>
      this == RolMiembro.administrador || this == RolMiembro.tesorero;
}
