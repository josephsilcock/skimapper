import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:skimapper/endpoint/contract_envelope.dart';

void main() {
  group('openDocument', () {
    test(
      'a known envelope is understood, keeping its body and the parsed data',
      () {
        final body = jsonEncode(_envelope());

        final outcome = openDocument(
          body,
          kind: 'skeleton-message',
          parse: (data) => data['message'],
        );

        expect(
          outcome,
          isA<Understood<Object?>>()
              .having((understood) => understood.body, 'body', body)
              .having((understood) => understood.value, 'value', 'hello'),
        );
      },
    );

    test('an envelope of another kind or an unknown schema version is incompatible', () {
      for (final envelope in [
        _envelope(schemaVersion: 2),
        _envelope(kind: 'catalogue'),
      ]) {
        expect(
          openDocument(
            jsonEncode(envelope),
            kind: 'skeleton-message',
            parse: (data) => data['message'],
          ),
          isA<Incompatible<Object?>>(),
        );
      }
    });

    test('a body that is not an envelope has failed, naming why', () {
      for (final body in ['this is not an envelope', '{"message": "hello"}']) {
        expect(
          openDocument(
            body,
            kind: 'skeleton-message',
            parse: (data) => data['message'],
          ),
          isA<Failed<Object?>>().having(
            (failed) => failed.cause,
            'cause',
            'not an envelope',
          ),
        );
      }
    });

    test('data its kind rejects has failed, naming the rejection', () {
      final outcome = openDocument(
        jsonEncode(_envelope()),
        kind: 'skeleton-message',
        parse: (data) => throw const FormatException('no resorts'),
      );

      expect(
        outcome,
        isA<Failed<Object?>>().having(
          (failed) => failed.cause,
          'cause',
          'data rejected: no resorts',
        ),
      );
    });
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
