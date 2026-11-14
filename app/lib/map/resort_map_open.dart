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
import 'scratch_folders.dart';

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

  /// Fetches are numbered as they start; only the newest one's answer is shown, and only while
  /// the screen is there.
  var _fetchesStarted = 0;

  /// The scratch folders this screen's fetches made, held until the screen goes.
  final _folders = <Directory>[];
  late final ScratchFolders _scratch;
  var _gone = false;

  @override
  ResortMapView build() {
    _scratch = ref.read(scratchFoldersProvider);
    ref.onDispose(() {
      _gone = true;
      _folders.forEach(_scratch.release);
    });
    Future.microtask(_open);
    return const MapLoading();
  }

  /// The skier's Retry: fetches everything again, installing the map assets afresh.
  Future<void> retry() {
    ref.invalidate(mapAssetsProvider);
    state = const MapLoading();
    return _open();
  }

  Future<void> _open() async {
    final fetch = ++_fetchesStarted;
    // Everything the fetch needs is read before its first wait: the screen may go meanwhile,
    // and the fetch then runs to its end and is dropped.
    final fetching = _Fetch(
      endpoint: ref.read(endpointClientProvider),
      newFolder: _newFolder,
      mapAssets: ref.read(mapAssetsProvider),
    ).of(resort);
    final answer = await _orCouldNotLoad(fetching);
    if (fetch == _fetchesStarted && ref.mounted) state = answer;
  }

  /// Anything the fetch throws (a full disk, assets that won't install) leaves the skier on
  /// Couldn't load map with Retry, not on the spinner.
  Future<ResortMapView> _orCouldNotLoad(Future<ResortMapView> fetching) async {
    try {
      return await fetching;
    } on Object catch (failure) {
      recordRun('map open failed: $failure');
      return const MapCouldNotLoad();
    }
  }

  /// A folder for one fetch; one made after the screen went is released at once.
  Future<Directory> _newFolder() async {
    final folder = await _scratch.newFolder();
    _gone ? _scratch.release(folder) : _folders.add(folder);
    return folder;
  }
}

/// One fetch of a resort's map data, and what the screen should show for it.
class _Fetch {
  const _Fetch({
    required this.endpoint,
    required this.newFolder,
    required this.mapAssets,
  });

  final EndpointClient endpoint;
  final Future<Directory> Function() newFolder;
  final Future<MapAssets> mapAssets;

  Future<ResortMapView> of(Resort resort) async =>
      switch (await endpoint.fetchResortManifest(resort.id)) {
        Understood(value: final manifest) => switch ((
          await _parts(manifest),
          await mapAssets,
        )) {
          (final parts?, final assets) => MapReady(manifest, parts, assets),
          _ => const MapCouldNotLoad(),
        },
        Incompatible() => const MapNeedsUpdate(),
        Failed() => const MapCouldNotLoad(),
      };

  /// Fetches every part the manifest pins, in parallel, into a scratch folder of this fetch's
  /// own; null if any part failed.
  Future<Map<PartRole, String>?> _parts(ResortManifest manifest) async {
    final folder = await newFolder();
    final outcomes = await Future.wait([
      for (final part in manifest.parts)
        endpoint.fetchPart(
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
