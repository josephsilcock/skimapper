import 'package:flutter/material.dart';

/// The credits for the sources a map's data came from, as its manifest lists them: the build
/// owns the credit duty (OpenStreetMap's ODbL asks for it wherever its data is shown).
class AttributionLine extends StatelessWidget {
  const AttributionLine({super.key, required this.credits});

  final List<String> credits;

  @override
  Widget build(BuildContext context) =>
      Text(credits.join(' · '), style: Theme.of(context).textTheme.bodySmall);
}
