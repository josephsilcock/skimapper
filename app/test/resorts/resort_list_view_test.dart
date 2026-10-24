import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:skimapper/endpoint/endpoint_client.dart';
import 'package:skimapper/resorts/resort_list_providers.dart';
import 'package:skimapper/resorts/resort_list_view.dart';

import '../support/pump_until_found.dart';

void main() {
  testWidgets('lists each served resort by name, with its countries', (
    tester,
  ) async {
    await tester.pumpWidget(
      _resortListServedBy(
        (request) async => request.url.path == '/v1/catalogue'
            ? http.Response(jsonEncode(_catalogue), 200)
            : http.Response('not found', 404),
      ),
    );
    await pumpUntilFound(tester, find.text('Espace San Bernardo'));

    expect(find.text('Espace San Bernardo'), findsOneWidget);
    expect(find.text('France · Italy'), findsOneWidget);
    expect(find.text('Paradiski'), findsOneWidget);
    expect(find.text('France'), findsOneWidget);
  });
}

Widget _resortListServedBy(MockClientHandler endpoint) => ProviderScope(
  overrides: [
    endpointClientProvider.overrideWithValue(
      EndpointClient(
        baseUrl: Uri.parse('http://endpoint.test'),
        timeout: const Duration(milliseconds: 100),
        newHttpClient: () => MockClient(endpoint),
      ),
    ),
  ],
  child: const MaterialApp(home: Scaffold(body: ResortListView())),
);

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
