import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// App-level theme mode (in-memory; persists for the session).
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);
