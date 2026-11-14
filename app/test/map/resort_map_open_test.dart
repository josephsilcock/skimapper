import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:skimapper/endpoint/contract_envelope.dart';
import 'package:skimapper/endpoint/endpoint_client.dart';
import 'package:skimapper/map/basemap_layers.dart';
import 'package:skimapper/map/map_assets.dart';
import 'package:skimapper/map/resort_map_open.dart';
import 'package:skimapper/map/resort_map_providers.dart';
import 'package:skimapper/resorts/catalogue.dart';
import 'package:skimapper/resorts/resort_list_providers.dart';

void main() {
  test("only the newest fetch's answer is shown, even when an older one answers after it", () async {
    final endpoint = _HeldEndpoint();
    final container = _container(endpoint);
    final open = NotifierProvider.autoDispose<ResortMapOpen, ResortMapView>(
      () => ResortMapOpen(_paradiski),
    );
    container.listen(open, (_, _) {});
    await pumpEventQueue();

    unawaited(container.read(open.notifier).retry());
    await pumpEventQueue();
    endpoint.answerManifest(1, const Incompatible());
    await pumpEventQueue();
    endpoint.answerManifest(0, const Failed('late'));
    await pumpEventQueue();

    expect(container.read(open), isA<MapNeedsUpdate>());
  });

  test('an answer that arrives after its screen has gone is dropped, raising nothing', () async {
    final endpoint = _HeldEndpoint();
    final container = _container(endpoint);
    final open = NotifierProvider.autoDispose<ResortMapOpen, ResortMapView>(
      () => ResortMapOpen(_paradiski),
    );
    final screen = container.listen(open, (_, _) {});
    await pumpEventQueue();

    screen.close();
    await pumpEventQueue();
    final errors = <Object>[];
    await runZonedGuarded(() async {
      endpoint.answerManifest(0, const Failed('late'));
      await pumpEventQueue();
    }, (error, _) => errors.add(error));

    expect(errors, isEmpty);
  });
}

const _paradiski = Resort(
  id: 'paradiski',
  name: 'Paradiski',
  countries: ['France'],
  centre: (lat: 45.56, lon: 6.8),
);

ProviderContainer _container(EndpointClient endpoint) {
  final scratch = Directory.systemTemp.createTempSync('resort-maps-');
  addTearDown(() => scratch.deleteSync(recursive: true));
  final container = ProviderContainer(
    overrides: [
      endpointClientProvider.overrideWithValue(endpoint),
      scratchRootProvider.overrideWithValue(Future.value(scratch)),
      mapAssetsProvider.overrideWithValue(
        Future.value(
          const MapAssets(
            glyphs: '/data/glyphs',
            basemap: BasemapLayers(under: [], over: []),
          ),
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// Holds each manifest fetch until the test answers it, by the order the fetches started.
class _HeldEndpoint extends EndpointClient {
  _HeldEndpoint()
    : super(
        baseUrl: Uri.parse('http://endpoint.test'),
        timeout: const Duration(seconds: 1),
        newHttpClient: http.Client.new,
      );

  final _manifests = <Completer<DocumentOutcome<Object?>>>[];

  void answerManifest(int fetch, DocumentOutcome<Object?> outcome) =>
      _manifests[fetch].complete(outcome);

  @override
  Future<DocumentOutcome<T>> fetchDocument<T>(
    String path, {
    required String kind,
    required T Function(Map<String, Object?> data) parse,
  }) async {
    final held = Completer<DocumentOutcome<Object?>>();
    _manifests.add(held);
    return switch (await held.future) {
      Incompatible() => Incompatible<T>(),
      Failed(:final cause) => Failed<T>(cause),
      Understood() => throw UnsupportedError('answer with a manifest'),
    };
  }
}
