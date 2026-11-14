import 'package:flutter/material.dart';

import 'attribution/attribution_line.dart';
import 'resorts/resort_list_view.dart';

/// The home screen: the resort list.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SkiMapper',
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 8),
            const Expanded(child: ResortListView()),
          ],
        ),
      ),
    ),
    // A floating snackbar sits above the bottom bar, so the credits stay visible under it.
    bottomNavigationBar: const SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: AttributionLine(),
      ),
    ),
  );
}
