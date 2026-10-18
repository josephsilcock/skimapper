import 'package:flutter/material.dart';

import 'placeholder_screen.dart';

void main() {
  runApp(const SkimapperApp());
}

class SkimapperApp extends StatelessWidget {
  const SkimapperApp({super.key});

  @override
  Widget build(BuildContext context) =>
      const MaterialApp(home: PlaceholderScreen());
}
