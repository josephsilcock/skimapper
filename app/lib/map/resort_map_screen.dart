import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../resorts/catalogue.dart';
import '../theme/full_area_message.dart';
import 'resort_map.dart';
import 'resort_map_open.dart';

/// A resort's map, under a name bar with back to the list.
class ResortMapScreen extends ConsumerStatefulWidget {
  const ResortMapScreen({super.key, required this.resort});

  final Resort resort;

  @override
  ConsumerState<ResortMapScreen> createState() => _ResortMapScreenState();
}

class _ResortMapScreenState extends ConsumerState<ResortMapScreen> {
  /// Made per screen, so every open of a resort fetches afresh.
  late final _open = NotifierProvider.autoDispose<ResortMapOpen, ResortMapView>(
    () => ResortMapOpen(widget.resort),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.resort.name,
        style: TextStyle(color: Theme.of(context).colorScheme.primary),
      ),
    ),
    body: switch (ref.watch(_open)) {
      MapReady(:final manifest, :final parts, :final assets) => ResortMap(
        manifest: manifest,
        parts: parts,
        assets: assets,
      ),
      MapLoading() => const Center(child: CircularProgressIndicator()),
      MapCouldNotLoad() => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: FullAreaMessage(
            icon: Icons.cloud_off_outlined,
            heading: "Couldn't load map",
            detail: 'Check your connection, then try again.',
            onRetry: ref.read(_open.notifier).retry,
          ),
        ),
      ),
    },
  );
}
