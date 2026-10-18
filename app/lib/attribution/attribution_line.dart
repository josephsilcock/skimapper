import 'package:flutter/material.dart';

/// Single home for the data credits (C4 design § 3). OpenStreetMap's ODbL requires the
/// credit wherever its data is shown; Mapterhorn's terrain mixes open sources that ask the same.
class AttributionLine extends StatelessWidget {
  const AttributionLine({super.key});

  static const _credits = [
    '© OpenStreetMap contributors',
    'OpenSkiMap',
    'Protomaps',
    'Mapterhorn',
  ];

  @override
  Widget build(BuildContext context) =>
      Text(_credits.join(' · '), style: Theme.of(context).textTheme.bodySmall);
}
