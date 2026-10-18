/// Single home for envelope compatibility (C4 design § 3): every JSON document the endpoint
/// serves is `{kind, schemaVersion, dataVersion, data}`.
Map<String, Object?> openEnvelope(Object? document, {required String kind}) =>
    switch (document) {
      {'data': Map<String, Object?> data} => data,
      _ => throw const FormatException('not an envelope'),
    };
