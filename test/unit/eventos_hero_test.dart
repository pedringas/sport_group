// Selección de eventos del hero de Inicio.
//
// Regresión del bug reportado: el hero mostraba UN solo evento (el más
// cercano), así que un segundo evento del mismo día quedaba fuera y sólo
// aparecía en Novedades. El tipo de evento (partido / entrenamiento / otro) no
// debe influir en absoluto.
import 'package:flutter_test/flutter_test.dart';
import 'package:sports_groups_app/data/models/enums.dart';
import 'package:sports_groups_app/data/models/noticia_model.dart';
import 'package:sports_groups_app/providers/dashboard_provider.dart';

final _ahora = DateTime(2026, 8, 15, 10, 0);

NoticiaModel _evento({
  required String id,
  DateTime? fechaEvento,
  DateTime? fechaCaducidad,
  bool tieneListado = true,
  NoticiaCategoria categoria = NoticiaCategoria.partido,
}) =>
    NoticiaModel(
      id: id,
      grupoId: 'g1',
      autorUid: 'u1',
      autorNombre: 'Admin',
      titulo: 'Evento $id',
      contenido: '',
      likes: const [],
      tieneListado: tieneListado,
      categoria: categoria,
      createdAt: DateTime(2026, 8, 1),
      fechaEvento: fechaEvento,
      fechaCaducidad: fechaCaducidad,
    );

List<String> _ids(List<NoticiaModel> ns) => ns.map((n) => n.id).toList();

void main() {
  group('seleccionarEventosHero — dos eventos el mismo día', () {
    test('entran los dos, no sólo el más cercano', () {
      final partido =
          _evento(id: 'a', fechaEvento: DateTime(2026, 8, 16, 16, 0));
      final entrenamiento = _evento(
        id: 'b',
        fechaEvento: DateTime(2026, 8, 16, 19, 0),
        categoria: NoticiaCategoria.entrenamiento,
      );

      final r = seleccionarEventosHero([partido, entrenamiento], _ahora);
      expect(_ids(r), ['a', 'b']);
    });

    test('un entrenamiento más temprano va primero que un partido', () {
      final partido =
          _evento(id: 'partido', fechaEvento: DateTime(2026, 8, 16, 20, 0));
      final entrenamiento = _evento(
        id: 'entren',
        fechaEvento: DateTime(2026, 8, 16, 9, 0),
        categoria: NoticiaCategoria.entrenamiento,
      );

      final r = seleccionarEventosHero([partido, entrenamiento], _ahora);
      expect(_ids(r), ['entren', 'partido'],
          reason: 'la categoría no debe alterar el orden, sólo la fecha');
    });

    test('a igual fecha y hora el orden es estable (por id)', () {
      final misma = DateTime(2026, 8, 16, 16, 0);
      final x = _evento(id: 'zzz', fechaEvento: misma);
      final y = _evento(id: 'aaa', fechaEvento: misma);

      expect(_ids(seleccionarEventosHero([x, y], _ahora)), ['aaa', 'zzz']);
      expect(_ids(seleccionarEventosHero([y, x], _ahora)), ['aaa', 'zzz'],
          reason: 'el orden del stream no debe cambiar el resultado');
    });
  });

  group('seleccionarEventosHero — ventana temporal', () {
    test('incluye un evento dentro de los 14 días', () {
      final r = seleccionarEventosHero(
          [_evento(id: 'a', fechaEvento: DateTime(2026, 8, 28, 12, 0))], _ahora);
      expect(_ids(r), ['a']);
    });

    test('excluye un evento posterior a la ventana', () {
      final r = seleccionarEventosHero(
          [_evento(id: 'a', fechaEvento: DateTime(2026, 9, 20, 12, 0))], _ahora);
      expect(r, isEmpty);
    });

    test('excluye un evento que ya pasó', () {
      final r = seleccionarEventosHero(
          [_evento(id: 'a', fechaEvento: DateTime(2026, 8, 15, 9, 0))], _ahora);
      expect(r, isEmpty);
    });

    test('incluye un evento de hoy más tarde', () {
      final r = seleccionarEventosHero(
          [_evento(id: 'a', fechaEvento: DateTime(2026, 8, 15, 18, 0))], _ahora);
      expect(_ids(r), ['a']);
    });
  });

  group('seleccionarEventosHero — filtros', () {
    test('excluye noticias sin lista de asistencia', () {
      final r = seleccionarEventosHero([
        _evento(
            id: 'a',
            fechaEvento: DateTime(2026, 8, 16),
            tieneListado: false),
      ], _ahora);
      expect(r, isEmpty);
    });

    test('excluye noticias caducadas', () {
      final r = seleccionarEventosHero([
        _evento(
          id: 'a',
          fechaEvento: DateTime(2026, 8, 16),
          fechaCaducidad: DateTime(2026, 8, 14),
        ),
      ], _ahora);
      expect(r, isEmpty);
    });

    test('usa fechaCaducidad cuando no hay fechaEvento', () {
      final r = seleccionarEventosHero(
          [_evento(id: 'a', fechaCaducidad: DateTime(2026, 8, 20, 12, 0))],
          _ahora);
      expect(_ids(r), ['a']);
    });

    test('excluye noticias sin ninguna fecha', () {
      final r = seleccionarEventosHero([_evento(id: 'a')], _ahora);
      expect(r, isEmpty);
    });
  });

  group('seleccionarEventosHero — tope', () {
    test('devuelve como mucho kHeroEventoMax y son los más próximos', () {
      final muchos = List.generate(
        8,
        (i) => _evento(id: 'e$i', fechaEvento: DateTime(2026, 8, 16 + i, 12, 0)),
      );
      final r = seleccionarEventosHero(muchos.reversed.toList(), _ahora);
      expect(r.length, kHeroEventoMax);
      expect(_ids(r), ['e0', 'e1', 'e2', 'e3', 'e4']);
    });
  });
}
