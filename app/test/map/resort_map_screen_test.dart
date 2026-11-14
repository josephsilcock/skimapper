import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:skimapper/attribution/attribution_line.dart';
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

  testWidgets(
    "a resort whose map data can't be fetched says its map couldn't be loaded, with Retry",
    (tester) async {
      FakeNativeMap(tester);
      await tester.pumpWidget(_screen(endpoint: _refusing));
      await pumpUntilFound(tester, find.text("Couldn't load map"));

      expect(find.text("Couldn't load map"), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
      expect(find.byType(ResortMap), findsNothing);
    },
  );

  testWidgets("a part that can't be fetched means the map couldn't be loaded", (
    tester,
  ) async {
    FakeNativeMap(tester);
    await tester.pumpWidget(_screen(endpoint: _servingManifestOnly));
    await pumpUntilFound(tester, find.text("Couldn't load map"));

    expect(find.text("Couldn't load map"), findsOneWidget);
    expect(find.byType(ResortMap), findsNothing);
  });

  testWidgets(
    "glyphs that can't be installed mean the map couldn't be loaded",
    (tester) async {
      FakeNativeMap(tester);
      await tester.pumpWidget(
        _screen(
          endpoint: _serving,
          // Ignored here so it's unhandled only where the open awaits it.
          assets: Future<MapAssets>.error(
            const FileSystemException('disk full'),
          )..ignore(),
        ),
      );
      await pumpUntilFound(tester, find.text("Couldn't load map"));

      expect(find.text("Couldn't load map"), findsOneWidget);
    },
  );

  testWidgets('while the map data is fetched, the screen shows it is loading', (
    tester,
  ) async {
    FakeNativeMap(tester);
    await tester.pumpWidget(_screen(endpoint: _serving));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Paradiski'), findsOneWidget);
    await pumpUntilFound(tester, find.byType(ResortMap));
  });

  testWidgets(
    "a resort's map shows its manifest's credits below it, and only with the map",
    (tester) async {
      FakeNativeMap(tester);
      await tester.pumpWidget(_screen(endpoint: _serving));
      expect(find.byType(AttributionLine), findsNothing, reason: 'loading');
      await pumpUntilFound(tester, find.byType(ResortMap));

      expect(
        find.text('© OpenStreetMap contributors · Mapterhorn'),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(find.byType(AttributionLine)).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(find.byType(ResortMap)).dy),
      );
    },
  );

  testWidgets('a snackbar over a resort map leaves its credits uncovered', (
    tester,
  ) async {
    FakeNativeMap(tester);
    await tester.pumpWidget(_screen(endpoint: _serving));
    await pumpUntilFound(tester, find.byType(AttributionLine));

    ScaffoldMessenger.of(tester.element(find.byType(AttributionLine)))
        .showSnackBar(const SnackBar(content: Text('a message')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final snackBar = tester.getRect(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.byType(Material),
      ),
    );
    expect(
      snackBar.overlaps(tester.getRect(find.byType(AttributionLine))),
      isFalse,
    );
  });

  testWidgets(
    'a manifest this app version cannot read asks for an app update, with Retry',
    (tester) async {
      FakeNativeMap(tester);
      await tester.pumpWidget(_screen(endpoint: _servingUnknownVersion));
      await pumpUntilFound(
        tester,
        find.text('Update SkiMapper to see this map'),
      );

      expect(find.text('Update SkiMapper to see this map'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
      expect(find.text("Couldn't load map"), findsNothing);
    },
  );

  testWidgets(
    'Retry fetches again, and shows the map once the data can be fetched',
    (tester) async {
      FakeNativeMap(tester);
      final serving = _flagFile();
      await tester.pumpWidget(
        _screen(endpoint: _servingOnceFlagged(serving.path)),
      );
      await pumpUntilFound(tester, find.text("Couldn't load map"));

      serving.createSync();
      await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
      await pumpUntilFound(tester, find.byType(ResortMap));

      expect(find.byType(ResortMap), findsOneWidget);
      expect(find.text("Couldn't load map"), findsNothing);
    },
  );
}

/// A path for a test to create, to flag a change to the handlers in the fetching isolate.
File _flagFile() {
  final directory = Directory.systemTemp.createTempSync('flag-');
  addTearDown(() => directory.deleteSync(recursive: true));
  return File('${directory.path}/flag');
}

/// Refuses every request until the file at [flag] exists, then serves the resort.
MockClientHandler _servingOnceFlagged(String flag) =>
    (request) async =>
        File(flag).existsSync() ? _serving(request) : _refusing(request);

/// Serves the manifest, but answers every part as missing.
Future<http.Response> _servingManifestOnly(http.Request request) async =>
    request.url.path.startsWith('/v1/parts/')
    ? http.Response('not found', 404)
    : _serving(request);

/// Serves the manifest at a schema version no app knows.
Future<http.Response> _servingUnknownVersion(http.Request request) async {
  final served = await _serving(request);
  if (!request.url.path.endsWith('/manifest')) return served;
  final envelope = jsonDecode(served.body) as Map<String, Object?>;
  return http.Response(jsonEncode({...envelope, 'schemaVersion': 999}), 200);
}

Future<http.Response> _refusing(http.Request request) async =>
    throw http.ClientException('Connection refused');

Widget _screen({
  required MockClientHandler endpoint,
  Future<MapAssets>? assets,
}) {
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
      mapAssetsProvider.overrideWithValue(assets ?? Future.value(_assets)),
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
            'credits': ['© OpenStreetMap contributors', 'Mapterhorn'],
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
