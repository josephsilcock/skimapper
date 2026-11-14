import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:skimapper/endpoint/contract_envelope.dart';
import 'package:skimapper/map/resort_manifest.dart';

void main() {
  test('a resort manifest is understood, with its bounds, credits and pinned parts', () {
    final outcome = openResortManifest(jsonEncode(_manifest));

    expect(
      outcome,
      isA<Understood<ResortManifest>>()
          .having((it) => it.value.bounds, 'bounds', (
            west: 6.81,
            south: 45.57,
            east: 6.83,
            north: 45.585,
          ))
          .having((it) => it.value.credits, 'credits', [
            '© OpenStreetMap contributors',
          ])
          .having((it) => it.value.parts, 'parts', [
            PinnedPart(role: PartRole.pistes, sha256: 'a' * 64, size: 243),
          ]),
    );
  });
}

final _manifest = {
  'kind': 'resort-manifest',
  'schemaVersion': 1,
  'dataVersion': '2026-11-14',
  'data': {
    'bounds': [6.81, 45.57, 6.83, 45.585],
    'credits': ['© OpenStreetMap contributors'],
    'parts': [
      {'role': 'pistes', 'sha256': 'a' * 64, 'size': 243},
    ],
  },
};
