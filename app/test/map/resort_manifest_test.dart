import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:skimapper/endpoint/contract_envelope.dart';
import 'package:skimapper/map/resort_manifest.dart';

void main() {
  test('a resort manifest is understood, with its bounds, credits and pinned parts', () {
    final outcome = _open(jsonEncode(_manifest));

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
            for (final role in PartRole.values)
              PinnedPart(role: role, sha256: 'a' * 64, size: 243),
          ]),
    );
  });

  test('a manifest missing a part role is rejected', () {
    final withoutTerrain = _manifestWithParts([
      for (final role in [PartRole.pistes, PartRole.basemap])
        {'role': role.name, 'sha256': 'a' * 64, 'size': 243},
    ]);

    expect(_open(jsonEncode(withoutTerrain)), isA<Failed>());
  });
}

DocumentOutcome<ResortManifest> _open(String body) =>
    openDocument(body, kind: resortManifestKind, parse: ResortManifest.parse);

Map<String, Object?> _manifestWithParts(List<Object?> parts) => {
  ..._manifest,
  'data': {...(_manifest['data'] as Map<String, Object?>), 'parts': parts},
};

final _manifest = {
  'kind': 'resort-manifest',
  'schemaVersion': 1,
  'dataVersion': '2026-11-14',
  'data': {
    'bounds': [6.81, 45.57, 6.83, 45.585],
    'credits': ['© OpenStreetMap contributors'],
    'parts': [
      for (final role in PartRole.values)
        {'role': role.name, 'sha256': 'a' * 64, 'size': 243},
    ],
  },
};
