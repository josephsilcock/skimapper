import 'package:flutter/material.dart';

import 'endpoint/dev_endpoint.dart';
import 'endpoint/skeleton_message_line.dart';
import 'map/fixture_map.dart';

class PlaceholderScreen extends StatefulWidget {
  const PlaceholderScreen({super.key});

  @override
  State<PlaceholderScreen> createState() => _PlaceholderScreenState();
}

class _PlaceholderScreenState extends State<PlaceholderScreen> {
  final _endpoint = devEndpointClient();
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
            SkeletonMessageLine(client: _endpoint),
            const SizedBox(height: 16),
            SizedBox(
              height: 240,
              child: FixtureMap(onFixtureChecked: _showFixtureChecked),
            ),
            const SizedBox(height: 8),
            Text(_mapLine),
          ],
        ),
      ),
    ),
  );
}
