import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../resorts/catalogue.dart';
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
      MapReady(:final manifest, :final parts) => ResortMap(
        manifest: manifest,
        parts: parts,
      ),
      MapLoading() => const SizedBox.expand(),
    },
  );
}
