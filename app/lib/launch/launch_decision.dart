import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../resorts/catalogue.dart';
import '../resorts/choose_resort.dart';
import '../resorts/resort_list_providers.dart';

/// The resort whose map the app opens on at launch, if any.
Resort? resortToReopen({
  required String? defaultId,
  required Catalogue? saved,
}) => saved?.resorts.where((resort) => resort.id == defaultId).firstOrNull;

/// The launch decision, from what is on the device alone.
final resortToReopenProvider = FutureProvider<Resort?>(
  (ref) async => resortToReopen(
    defaultId: await ref.watch(defaultResortFileProvider).read(),
    saved: await ref.watch(savedCatalogueAtLaunchProvider.future),
  ),
);
