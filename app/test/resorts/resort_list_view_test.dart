import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:skimapper/endpoint/endpoint_client.dart';
import 'package:skimapper/resorts/catalogue_store.dart';
import 'package:skimapper/resorts/resort_list_providers.dart';
import 'package:skimapper/resorts/resort_list_view.dart';

import '../support/pump_until_found.dart';

void main() {
  late CatalogueStore store;

  setUp(() {
    final directory = Directory.systemTemp.createTempSync('resort-list-');
    addTearDown(() => directory.deleteSync(recursive: true));
    store = CatalogueStore(() async => directory);
  });

  testWidgets('lists each served resort by name, with its countries', (
    tester,
  ) async {
    await tester.pumpWidget(_resortList(endpoint: _serving, store: store));
    await pumpUntilFound(tester, find.text('Espace San Bernardo'));

    expect(find.text('Espace San Bernardo'), findsOneWidget);
    expect(find.text('France · Italy'), findsOneWidget);
    expect(find.text('Paradiski'), findsOneWidget);
    expect(find.text('France'), findsOneWidget);
  });

  testWidgets('saves the understood catalogue exactly as served', (
    tester,
  ) async {
    await tester.pumpWidget(_resortList(endpoint: _serving, store: store));
    await pumpUntilFound(tester, find.text('Espace San Bernardo'));

    expect(
      await _savedCopyOnceItIs(jsonEncode(_catalogue), tester, store),
      jsonEncode(_catalogue),
    );
  });

  testWidgets('shows the saved list when the service cannot be reached', (
    tester,
  ) async {
    await tester.runAsync(() => store.write(jsonEncode(_catalogue)));

    await tester.pumpWidget(_resortList(endpoint: _refusing, store: store));
    await pumpUntilFound(tester, find.text('Espace San Bernardo'));

    expect(find.text('Espace San Bernardo'), findsOneWidget);
    expect(find.text('Paradiski'), findsOneWidget);
  });

  for (final (unreadable, copy) in [
    ('corrupt', 'not a catalogue'),
    ('older-schema', jsonEncode({..._catalogue, 'schemaVersion': 0})),
  ]) {
    testWidgets(
      'a $unreadable saved copy counts as nothing saved, and the fetch replaces it',
      (tester) async {
        await tester.runAsync(() => store.write(copy));

        await tester.pumpWidget(_resortList(endpoint: _serving, store: store));
        await pumpUntilFound(tester, find.text('Espace San Bernardo'));

        expect(find.text('Espace San Bernardo'), findsOneWidget);
        expect(
          await _savedCopyOnceItIs(jsonEncode(_catalogue), tester, store),
          jsonEncode(_catalogue),
        );
      },
    );
  }

  testWidgets(
    'a save that fails still shows the new list, and reports the failure',
    (tester) async {
      final unwritable = CatalogueStore(
        () async => Directory(
          '${Directory.systemTemp.path}/no-such-dir-${DateTime.now().microsecondsSinceEpoch}',
        ),
      );

      await tester.pumpWidget(
        _resortList(endpoint: _serving, store: unwritable),
      );
      await pumpUntilFound(tester, find.text('Espace San Bernardo'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();

      expect(find.text('Espace San Bernardo'), findsOneWidget);
      expect(tester.takeException(), isA<FileSystemException>());
    },
  );
}

Widget _resortList({
  required MockClientHandler endpoint,
  required CatalogueStore store,
}) => ProviderScope(
  overrides: [
    endpointClientProvider.overrideWithValue(
      EndpointClient(
        baseUrl: Uri.parse('http://endpoint.test'),
        timeout: const Duration(milliseconds: 100),
        newHttpClient: () => MockClient(endpoint),
      ),
    ),
    catalogueStoreProvider.overrideWithValue(store),
  ],
  child: const MaterialApp(home: Scaffold(body: ResortListView())),
);

/// The saved copy once it reads as [expected], or as it last read if it doesn't within a second:
/// the app's save lands after the list shows.
Future<String?> _savedCopyOnceItIs(
  String expected,
  WidgetTester tester,
  CatalogueStore store,
) async {
  String? saved;
  for (var tries = 0; tries < 50 && saved != expected; tries++) {
    saved = await tester.runAsync<String?>(store.read);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  return saved;
}

Future<http.Response> _serving(http.Request request) async =>
    request.url.path == '/v1/catalogue'
    ? http.Response(jsonEncode(_catalogue), 200)
    : http.Response('not found', 404);

Future<http.Response> _refusing(http.Request request) async =>
    throw http.ClientException('Connection refused');

const _catalogue = {
  'kind': 'catalogue',
  'schemaVersion': 1,
  'dataVersion': '2026-10-24',
  'data': {
    'resorts': [
      {
        'name': 'Paradiski',
        'countries': ['France'],
        'centre': {'lat': 45.55, 'lon': 6.8},
      },
      {
        'name': 'Espace San Bernardo',
        'countries': ['France', 'Italy'],
        'centre': {'lat': 45.68, 'lon': 6.88},
      },
    ],
  },
};
