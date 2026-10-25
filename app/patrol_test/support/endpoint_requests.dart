import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skimapper/endpoint/contract_envelope.dart';
import 'package:skimapper/endpoint/dev_endpoint.dart';
import 'package:skimapper/resorts/catalogue.dart';
import 'package:skimapper/resorts/catalogue_document.dart';

/// The ski area tools/e2e's extra-area catalogue gains.
const extraArea = String.fromEnvironment('E2E_EXTRA_AREA');

/// Asks tools/e2e to serve the curated catalogue, then waits until a fetch reads it.
Future<void> requestCuratedCatalogue() => _request(
  'serve-catalogue curated',
  until: (outcome) => _lists(outcome, extraArea) == false,
);

/// Asks tools/e2e to serve the catalogue with [extraArea] added, then waits until a fetch reads it.
Future<void> requestCatalogueWithExtraArea() => _request(
  'serve-catalogue extra-area',
  until: (outcome) => _lists(outcome, extraArea) == true,
);

/// Whether an understood catalogue lists [name]; null if the fetch wasn't understood.
bool? _lists(DocumentOutcome<Catalogue> outcome, String name) =>
    switch (outcome) {
      Understood(:final value) => value.resorts.any(
        (resort) => resort.name == name,
      ),
      _ => null,
    };

/// Asks tools/e2e to stop the endpoint, then waits until a catalogue fetch fails.
Future<void> requestEndpointStopped() =>
    _request('stop-endpoint', until: (outcome) => outcome is Failed);

/// Logs [request] for tools/e2e to act on (its vocabulary lives there), then probes the catalogue
/// until [until] holds, failing the test if it never does.
Future<void> _request(
  String request, {
  required bool Function(DocumentOutcome<Catalogue> outcome) until,
}) async {
  debugPrint('[e2e-request] $request');
  final endpoint = devEndpointClient();
  final deadline = DateTime.now().add(const Duration(seconds: 60));
  while (!until(await endpoint.fetchCatalogue())) {
    if (DateTime.now().isAfter(deadline)) {
      fail('the endpoint did not change within 60 s of "$request"');
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
}
