import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/ob_welcome.dart';
import '../widgets/ob_carousel.dart';
import '../widgets/ob_register.dart';
import '../widgets/ob_profile.dart';
import '../widgets/ob_join_or_create.dart';
import '../widgets/ob_join_group.dart';
import '../widgets/ob_create_group.dart';
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
  String _path = 'join'; // 'join' | 'create'
  Set<String> _selectedSports = {};
  String _grupoId = '';
  String _grupoNombre = '';
  Color _grupoColor = kGrupoColores[0];

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
      case 5: _goTo(4);
      default: {}
    }
  }

  void _onGroupDone(String grupoId, String nombre, Color color) {
    setState(() {
      _grupoId = grupoId;
      _grupoNombre = nombre;
      _grupoColor = color;
    });
    _goTo(6);
  }

  Future<void> _skipOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_seen', true);
    if (!mounted) return;
    context.go('/home');
  }

  Future<void> _finish({required bool goToGroup}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_seen', true);
    if (!mounted) return;
    if (goToGroup && _grupoId.isNotEmpty) {
      context.go('/group/$_grupoId');
    } else {
      context.go('/home');
    }
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
      4 => OBJoinOrCreate(
          onBack: _goBack,
          onJoin: () {
            setState(() => _path = 'join');
            _goTo(5);
          },
          onCreate: () {
            setState(() => _path = 'create');
            _goTo(5);
          },
          onSkip: _skipOnboarding,
        ),
      5 => _path == 'join'
          ? OBJoinGroup(onBack: _goBack, onJoined: _onGroupDone)
          : OBCreateGroup(onBack: _goBack, onCreated: _onGroupDone),
      _ => OBReady(
          grupoId: _grupoId,
          grupoNombre: _grupoNombre,
          grupoColor: _grupoColor,
          isCreated: _path == 'create',
          onFinish: _finish,
        ),
    };
  }
}
