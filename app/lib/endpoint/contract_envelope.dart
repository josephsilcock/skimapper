/// Single home for envelope compatibility (C4 design § 3): every JSON document the endpoint
/// serves is `{kind, schemaVersion, dataVersion, data}`, and the app accepts only the schema
/// versions it knows for each kind.
const _acceptedSchemaVersions = {'skeleton-message': 1};

Map<String, Object?> openEnvelope(Object? document, {required String kind}) =>
    switch (document) {
      {
        'kind': final String documentKind,
        'schemaVersion': final int version,
        'data': Map<String, Object?> data,
      }
          when documentKind == kind && _isAccepted(kind, version) =>
        data,
      _ => throw const FormatException('envelope not understood'),
    };

bool _isAccepted(String kind, int schemaVersion) =>
    _acceptedSchemaVersions[kind] == schemaVersion;
