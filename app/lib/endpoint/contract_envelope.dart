import 'dart:convert';

/// Single home for envelope compatibility (C4 design § 3): every JSON document the endpoint
/// serves is `{kind, schemaVersion, dataVersion, data}`, and the app accepts only the schema
/// versions it knows for each kind.
const _acceptedSchemaVersions = {'catalogue': 1};

/// What a document turned out to be (D8): the only three answers any fetch or saved copy gives.
sealed class DocumentOutcome<T> {
  const DocumentOutcome();
}

class Understood<T> extends DocumentOutcome<T> {
  const Understood(this.body, this.value);

  /// The document exactly as served, for saving.
  final String body;
  final T value;
}

/// A kind or schema version this app doesn't know: only an app update helps.
class Incompatible<T> extends DocumentOutcome<T> {
  const Incompatible();
}

class Failed<T> extends DocumentOutcome<T> {
  const Failed(this.cause);

  /// Why, for the fetch log.
  final String cause;
}

/// Opens [body] as an envelope of [kind], then reads its data with [parse], which rejects data it
/// can't use by throwing a [FormatException].
DocumentOutcome<T> openDocument<T>(
  String body, {
  required String kind,
  required T Function(Map<String, Object?> data) parse,
}) => switch (_decoded(body)) {
  {
    'kind': final String documentKind,
    'schemaVersion': final int version,
    'data': Map<String, Object?> data,
  } =>
    documentKind == kind && _isAccepted(kind, version)
        ? _parsed(body, data, parse)
        : Incompatible<T>(),
  _ => Failed<T>('not an envelope'),
};

bool _isAccepted(String kind, int schemaVersion) =>
    _acceptedSchemaVersions[kind] == schemaVersion;

Object? _decoded(String body) {
  try {
    return jsonDecode(body);
  } on FormatException {
    return null;
  }
}

DocumentOutcome<T> _parsed<T>(
  String body,
  Map<String, Object?> data,
  T Function(Map<String, Object?> data) parse,
) {
  try {
    return Understood(body, parse(data));
  } on FormatException catch (rejection) {
    return Failed('data rejected: ${rejection.message}');
  }
}
