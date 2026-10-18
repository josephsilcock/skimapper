import 'package:flutter_test/flutter_test.dart';
import 'package:skimapper/endpoint/contract_envelope.dart';

void main() {
  test('opens an envelope of the expected kind and a known schema version', () {
    final document = {
      'kind': 'skeleton-message',
      'schemaVersion': 1,
      'dataVersion': '2026-10-18',
      'data': {'message': 'hello'},
    };

    expect(openEnvelope(document, kind: 'skeleton-message'), {
      'message': 'hello',
    });
  });
}
