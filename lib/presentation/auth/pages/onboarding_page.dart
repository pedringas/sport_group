import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/config/app_config.dart';
import '../widgets/ob_welcome.dart';
import '../widgets/ob_carousel.dart';
import '../widgets/ob_register.dart';
import '../widgets/ob_profile.dart';
import '../widgets/ob_ready.dart';
import '../widgets/ob_shared.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  int _step = 0;
  int _prevStep = 0;
  Set<String> _selectedSports = {};
  final Color _grupoColor = kGrupoColores[0];

  void _goTo(int step) {
    setState(() {
      _prevStep = _step;
      _step = step;
    });
  }

  void _goBack() {
    switch (_step) {
      case 1: _goTo(0);
      case 2: _goTo(1);
      case 3: _goTo(1); // can't un-register, go to carousel
      case 4: _goTo(3);
      default: {}
    }
  }

  Future<void> _finish({required bool goToGroup}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_seen', true);
    if (!mounted) return;
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final forward = _step >= _prevStep;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      transitionBuilder: (child, anim) {
        final offset = Offset(forward ? 0.04 : -0.04, 0);
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: SlideTransition(
            position: Tween(begin: offset, end: Offset.zero).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(
        key: ValueKey(_step),
        child: _buildStep(),
      ),
    );
  }

  // App de grupo único: el ingreso a Tacheros es automático al autenticarse,
  // así que el wizard ya no pregunta por unirse ni crear un grupo.
  // Los widgets ob_join_or_create / ob_join_group / ob_create_group quedan en
  // el repo sin usar por si se reactiva el modelo multi-grupo.
  Widget _buildStep() {
    return switch (_step) {
      0 => OBWelcome(onStart: () => _goTo(1)),
      1 => OBCarousel(onBack: _goBack, onAdvance: () => _goTo(2)),
      2 => OBRegister(onBack: _goBack, onSuccess: () => _goTo(3)),
      3 => OBProfile(
          onBack: _goBack,
          selectedSports: _selectedSports,
          onAdvance: (sports) {
            setState(() => _selectedSports = sports);
            _goTo(4);
          },
        ),
      _ => OBReady(
          grupoId: kGrupoId,
          grupoNombre: kGrupoNombre,
          grupoColor: _grupoColor,
          isCreated: false,
          onFinish: _finish,
        ),
    };
  }
}
