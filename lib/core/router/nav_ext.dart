import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

extension SafePop on BuildContext {
  /// Vuelve a la pantalla anterior.
  ///
  /// El `pop` de go_router lanza `GoError: There is nothing to pop` cuando no
  /// hay nada que desapilar — al entrar por deep link, al recargar la página
  /// en web, o cuando la ruta se abrió con `go` en vez de `push`. Como en las
  /// pantallas de alta esa llamada vive dentro del `try` del guardado, la
  /// excepción se mostraba como si hubiera fallado el guardado.
  ///
  /// Este helper cae a [fallback] en vez de lanzar.
  void popOr([String fallback = '/home']) {
    if (canPop()) {
      pop();
    } else {
      go(fallback);
    }
  }
}
