import 'package:flutter/material.dart';

import 'attribution/attribution_line.dart';
import 'map/fixture_map.dart';
import 'resorts/resort_list_view.dart';

/// F1's home screen: the resort list, with the fixture map proof pinned below it until F5.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _mapLine = 'map: loading';

  void _showFixtureChecked(bool found) => setState(
    () => _mapLine = found
        ? 'map: fixture feature found'
        : 'map: fixture not rendered',
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SkiMapper',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            const Expanded(child: ResortListView()),
            const SizedBox(height: 16),
            SizedBox(
              height: 240,
              child: FixtureMap(onFixtureChecked: _showFixtureChecked),
            ),
            const SizedBox(height: 8),
            Text(_mapLine),
            const SizedBox(height: 8),
            const AttributionLine(),
          ],
        ),
      ),
    ),
  );
}
