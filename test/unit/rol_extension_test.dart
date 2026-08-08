// Los getters de RolMiembroX son de extensión: se resuelven estáticamente.
// Invocarlos sobre un receptor `dynamic` compila sin quejas pero explota en
// runtime con NoSuchMethodError — así quedó la pantalla de Cuotas en gris.
// Estos tests fijan el comportamiento esperado sobre el tipo correcto y dejan
// documentado por qué el receptor nunca debe ser `dynamic`.
import 'package:flutter_test/flutter_test.dart';
import 'package:sports_groups_app/data/models/enums.dart';

void main() {
  group('RolMiembroX.puedeGestionarCuotas', () {
    test('administrador y tesorero pueden gestionar cuotas', () {
      expect(RolMiembro.administrador.puedeGestionarCuotas, isTrue);
      expect(RolMiembro.tesorero.puedeGestionarCuotas, isTrue);
    });

    test('miembro, moderador y delegado no pueden', () {
      expect(RolMiembro.miembro.puedeGestionarCuotas, isFalse);
      expect(RolMiembro.moderador.puedeGestionarCuotas, isFalse);
      expect(RolMiembro.delegado.puedeGestionarCuotas, isFalse);
    });

    test('sobre un receptor dynamic lanza NoSuchMethodError', () {
      // Regresión: `_buildAdminCuotaRows` recibía `dynamic rol` y hacía
      // `rol?.puedeGestionarCuotas`, lo que rompía la pantalla en release.
      final dynamic rol = RolMiembro.administrador;
      expect(() => rol.puedeGestionarCuotas, throwsNoSuchMethodError);
    });
  });

  group('RolMiembroX.esAdmin', () {
    test('sólo administrador', () {
      expect(RolMiembro.administrador.esAdmin, isTrue);
      expect(RolMiembro.miembro.esAdmin, isFalse);
    });
  });
}
