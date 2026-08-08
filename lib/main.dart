import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting('es_AR', null);

  // En release, el ErrorWidget por defecto pinta un recuadro gris sin texto:
  // una pantalla rota es indistinguible de una vacía. Mostramos el error real
  // para poder diagnosticar desde el dispositivo del usuario.
  ErrorWidget.builder = (details) => _ErrorPane(details: details);

  // Initialize FCM / local notifications
  await NotificationService.instance.initialize();

  runApp(const ProviderScope(child: MyApp()));
}

/// Reemplaza el recuadro gris de Flutter por el detalle del error.
class _ErrorPane extends StatelessWidget {
  final FlutterErrorDetails details;
  const _ErrorPane({required this.details});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppTheme.danger, size: 36),
            const SizedBox(height: 10),
            const Text(
              'Se rompió esta sección',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.text),
            ),
            const SizedBox(height: 10),
            SelectableText(
              details.exceptionAsString(),
              style: const TextStyle(
                  fontSize: 12, height: 1.4, color: AppTheme.text),
            ),
          ],
        ),
      ),
    );
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Tacheros',
      theme: AppTheme.light,
      themeMode: ThemeMode.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      locale: const Locale('es', 'AR'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'AR'),
        Locale('en', 'US'),
      ],
    );
  }
}
