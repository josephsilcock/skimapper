import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:skimapper/endpoint/endpoint_client.dart';
import 'package:skimapper/map/basemap_layers.dart';
import 'package:skimapper/map/map_assets.dart';
import 'package:skimapper/map/resort_manifest.dart';
import 'package:skimapper/map/resort_map.dart';
import 'package:skimapper/map/resort_map_providers.dart';
import 'package:skimapper/map/resort_map_screen.dart';
import 'package:skimapper/resorts/catalogue.dart';
import 'package:skimapper/resorts/resort_list_providers.dart';

import '../support/pump_until_found.dart';
import 'fake_native_map.dart';

void main() {
  testWidgets('opening a resort shows its map, drawn from its verified parts', (
    tester,
  ) async {
    FakeNativeMap(tester);
    await tester.pumpWidget(_screen(endpoint: _serving));
    await pumpUntilFound(tester, find.byType(ResortMap));

    final map = tester.widget<ResortMap>(find.byType(ResortMap));
    expect(map.manifest.bounds, (
      west: 6.81,
      south: 45.57,
      east: 6.83,
      north: 45.585,
    ));
    expect(File(map.parts[PartRole.pistes]!).readAsBytesSync(), _pistes);
    expect(map.assets, same(_assets));
  });
}

Widget _screen({required MockClientHandler endpoint}) {
  final scratch = Directory.systemTemp.createTempSync('resort-maps-');
  addTearDown(() => scratch.deleteSync(recursive: true));
  return ProviderScope(
    overrides: [
      endpointClientProvider.overrideWithValue(
        EndpointClient(
          baseUrl: Uri.parse('http://endpoint.test'),
          timeout: const Duration(milliseconds: 500),
          newHttpClient: () => MockClient(endpoint),
        ),
      ),
      scratchRootProvider.overrideWithValue(Future.value(scratch)),
      mapAssetsProvider.overrideWithValue(Future.value(_assets)),
    ],
    child: const MaterialApp(home: ResortMapScreen(resort: _paradiski)),
  );
}

const _assets = MapAssets(
  glyphs: '/data/glyphs',
  basemap: BasemapLayers(under: [], over: []),
);

const _paradiski = Resort(
  id: 'paradiski',
  name: 'Paradiski',
  countries: ['France'],
  centre: (lat: 45.56, lon: 6.8),
);

final _pistes = utf8.encode('{"type":"FeatureCollection","features":[]}');
final _pistesSha256 = sha256.convert(_pistes).toString();

Future<http.Response> _serving(http.Request request) async =>
    switch (request.url.path) {
      '/v1/resorts/paradiski/manifest' => http.Response(
        jsonEncode({
          'kind': 'resort-manifest',
          'schemaVersion': 1,
          'dataVersion': '2026-11-14',
          'data': {
            'bounds': [6.81, 45.57, 6.83, 45.585],
            'credits': <String>[],
            'parts': [
              {
                'role': 'pistes',
                'sha256': _pistesSha256,
                'size': _pistes.length,
              },
            ],
          },
        }),
        200,
      ),
      final path when path == '/v1/parts/$_pistesSha256' => http.Response.bytes(
        _pistes,
        200,
      ),
      _ => http.Response('not found', 404),
    };
