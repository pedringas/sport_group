/// Configuración de la app de grupo único.
///
/// Esta app gestiona un solo grupo (Tacheros). Toda la navegación y las
/// pantallas operan sobre [kGrupoId]. El modelo multi-grupo sigue en el código
/// pero sus accesos están ocultos de la UI.
library;

/// ID fijo del grupo en Firestore (`grupos/tacheros`).
const String kGrupoId = 'tacheros';

/// Nombre por defecto con el que se crea el grupo la primera vez.
const String kGrupoNombre = 'Tacheros';
