import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../endpoint/contract_envelope.dart';
import '../endpoint/endpoint_client.dart';
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

/// One screen's open of a resort's map: the only writer of what that screen shows.
class ResortMapOpen extends Notifier<ResortMapView> {
  ResortMapOpen(this.resort);

  final Resort resort;

  @override
  ResortMapView build() {
    Future.microtask(_open);
    return const MapLoading();
  }

  EndpointClient get _endpoint => ref.read(endpointClientProvider);

  Future<void> _open() async {
    if (await _endpoint.fetchResortManifest(resort.id) case Understood(
      value: final manifest,
    )) {
      state = MapReady(
        manifest,
        await _fetchParts(manifest),
        await ref.read(mapAssetsProvider),
      );
    }
  }

  /// Fetches every part the manifest pins, in parallel, into a scratch folder of this open's own.
  Future<Map<PartRole, String>> _fetchParts(ResortManifest manifest) async {
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
    return {
      for (final (index, part) in manifest.parts.indexed)
        part.role: (outcomes[index] as VerifiedPart).path,
    };
  }
}
