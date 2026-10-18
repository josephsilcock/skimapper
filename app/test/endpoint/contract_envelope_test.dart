import 'package:flutter_test/flutter_test.dart';
import 'package:skimapper/endpoint/contract_envelope.dart';

void main() {
  test('opens an envelope of the expected kind and a known schema version', () {
    expect(openEnvelope(_envelope(), kind: 'skeleton-message'), {
      'message': 'hello',
    });
  });

  test('rejects a schema version this app does not know', () {
    expect(
      () => openEnvelope(_envelope(schemaVersion: 2), kind: 'skeleton-message'),
      throwsFormatException,
    );
  });

  test('rejects a document of a different kind', () {
    expect(
      () => openEnvelope(
        _envelope(kind: 'resort-catalogue'),
        kind: 'skeleton-message',
      ),
      throwsFormatException,
    );
  });
}

Map<String, Object?> _envelope({
  String kind = 'skeleton-message',
  int schemaVersion = 1,
}) => {
  'kind': kind,
  'schemaVersion': schemaVersion,
  'dataVersion': '2026-10-18',
  'data': {'message': 'hello'},
};
