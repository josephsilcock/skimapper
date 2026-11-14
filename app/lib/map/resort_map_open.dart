import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../endpoint/contract_envelope.dart';
import '../endpoint/endpoint_client.dart';
import '../endpoint/run_record.dart';
import '../resorts/catalogue.dart';
import '../resorts/resort_list_providers.dart';
import 'map_assets.dart';
import 'resort_manifest.dart';
import 'resort_map_providers.dart';

/// What a resort's map screen shows.
sealed class ResortMapView {
  const ResortMapView();
}

class MapLoading extends ResortMapView {
  const MapLoading();
}

class MapReady extends ResortMapView {
  const MapReady(this.manifest, this.parts, this.assets);

  final ResortManifest manifest;

  /// Each part's verified local file.
  final Map<PartRole, String> parts;
  final MapAssets assets;
}

class MapCouldNotLoad extends ResortMapView {
  const MapCouldNotLoad();
}

/// The endpoint serves this resort's map data in a form only a newer app reads.
class MapNeedsUpdate extends ResortMapView {
  const MapNeedsUpdate();
}

/// One screen's open of a resort's map: the only writer of what that screen shows.
class ResortMapOpen extends Notifier<ResortMapView> {
  ResortMapOpen(this.resort);

  final Resort resort;

  @override
  ResortMapView build() {
    Future.microtask(_open);
    return const MapLoading();
  }

  /// The skier's Retry: fetches everything again.
  Future<void> retry() {
    state = const MapLoading();
    return _open();
  }

  EndpointClient get _endpoint => ref.read(endpointClientProvider);

  Future<void> _open() async {
    switch (await _endpoint.fetchResortManifest(resort.id)) {
      case Understood(value: final manifest):
        state = switch ((await _fetchParts(manifest), await _mapAssets())) {
          (final parts?, final assets?) => MapReady(manifest, parts, assets),
          _ => const MapCouldNotLoad(),
        };
      case Incompatible():
        state = const MapNeedsUpdate();
      case Failed():
        state = const MapCouldNotLoad();
    }
  }

  /// The glyphs and basemap layers; null if they couldn't be installed.
  Future<MapAssets?> _mapAssets() async {
    try {
      return await ref.read(mapAssetsProvider);
    } on FileSystemException catch (failure) {
      recordRun('map assets failed: $failure');
      return null;
    }
  }

  /// Fetches every part the manifest pins, in parallel, into a scratch folder of this open's own;
  /// null if any part failed.
  Future<Map<PartRole, String>?> _fetchParts(ResortManifest manifest) async {
    final root = await ref.read(scratchRootProvider);
    final folder = await root.createTemp('open-');
    final outcomes = await Future.wait([
      for (final part in manifest.parts)
        _endpoint.fetchPart(
          sha256: part.sha256,
          size: part.size,
          directory: folder.path,
        ),
    ]);
    final verified = {
      for (final (index, part) in manifest.parts.indexed)
        if (outcomes[index] case VerifiedPart(:final path)) part.role: path,
    };
    return verified.length == manifest.parts.length ? verified : null;
  }
}
