import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'diagnostics/event_loop_lag.dart';
import 'endpoint/run_record.dart';
import 'home_screen.dart';
import 'launch/launch_gate.dart';
import 'map/scratch_clean_up.dart';
import 'resorts/catalogue.dart';
import 'resorts/choose_resort.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const SkimapperApp());
}

class SkimapperApp extends StatefulWidget {
  const SkimapperApp({super.key});

  @override
  State<SkimapperApp> createState() => _SkimapperAppState();
}

class _SkimapperAppState extends State<SkimapperApp> {
  Timer? _lagWatch;

  // Here rather than in main(): Patrol pumps the app without calling main().
  @override
  void initState() {
    super.initState();
    recordRun('app launch');
    if (kDebugMode) {
      _lagWatch = watchEventLoopLag(over: const Duration(seconds: 10));
    }
  }

  @override
  void dispose() {
    _lagWatch?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ProviderScope(
    child: ScratchCleanUp(child: LaunchGate(builder: _app)),
  );

  /// The resort list, under the reopened resort's map if there is one.
  Widget _app(Resort? reopened) => MaterialApp(
    theme: appTheme(),
    onGenerateRoute: (_) => _homeRoute(),
    onGenerateInitialRoutes: (_) => [
      _homeRoute(),
      if (reopened != null) resortMapRoute(reopened),
    ],
  );

  static Route<void> _homeRoute() =>
      MaterialPageRoute<void>(builder: (_) => const HomeScreen());
}
