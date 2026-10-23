import 'package:flutter/material.dart';

import 'endpoint/run_record.dart';
import 'placeholder_screen.dart';

void main() {
  runApp(const SkimapperApp());
}

class SkimapperApp extends StatefulWidget {
  const SkimapperApp({super.key});

  @override
  State<SkimapperApp> createState() => _SkimapperAppState();
}

class _SkimapperAppState extends State<SkimapperApp> {
  // Here rather than in main(): Patrol pumps the app without calling main().
  @override
  void initState() {
    super.initState();
    recordRun('app launch');
  }

  @override
  Widget build(BuildContext context) =>
      const MaterialApp(home: PlaceholderScreen());
}
