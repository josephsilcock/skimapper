import 'package:flutter/foundation.dart';

import '../endpoint/contract_envelope.dart';
import '../endpoint/endpoint_client.dart';

enum PartRole { pistes, basemap, terrain }

/// A part of a resort's map data, pinned by its hash and size.
@immutable
class PinnedPart {
  factory PinnedPart._parse(Object? entry) => switch (entry) {
    {'role': String role, 'sha256': String sha256, 'size': int size}
        when PartRole.values.asNameMap().containsKey(role) =>
      PinnedPart(
        role: PartRole.values.byName(role),
        sha256: sha256,
        size: size,
      ),
    _ => throw FormatException('malformed part', entry),
  };

  const PinnedPart({
    required this.role,
    required this.sha256,
    required this.size,
  });

  final PartRole role;
  final String sha256;
  final int size;

  @override
  bool operator ==(Object other) =>
      other is PinnedPart &&
      other.role == role &&
      other.sha256 == sha256 &&
      other.size == size;

  @override
  int get hashCode => Object.hash(role, sha256, size);
}

typedef Bounds = ({double west, double south, double east, double north});

/// What a resort's map is made of: where it is, who to credit, and its parts.
class ResortManifest {
  const ResortManifest({
    required this.bounds,
    required this.credits,
    required this.parts,
  });

  final Bounds bounds;
  final List<String> credits;
  final List<PinnedPart> parts;

  /// The resort-manifest kind's parse for `openDocument`.
  static ResortManifest parse(Map<String, Object?> data) => switch (data) {
    {
      'bounds': [num west, num south, num east, num north],
      'credits': List<Object?> credits,
      'parts': List<Object?> parts,
    }
        when credits.every((credit) => credit is String) =>
      ResortManifest(
        bounds: (
          west: west.toDouble(),
          south: south.toDouble(),
          east: east.toDouble(),
          north: north.toDouble(),
        ),
        credits: credits.cast<String>(),
        parts: _withEveryRole([
          for (final part in parts) PinnedPart._parse(part),
        ]),
      ),
    _ => throw const FormatException('malformed resort manifest'),
  };

  /// The map is drawn from one part of every role, so a manifest lacking one is not understood.
  static List<PinnedPart> _withEveryRole(List<PinnedPart> parts) {
    final roles = {for (final part in parts) part.role};
    if (roles.length != PartRole.values.length ||
        parts.length != roles.length) {
      throw const FormatException('parts are not one of every role');
    }
    return parts;
  }
}

/// The resort-manifest document, as the endpoint serves it.
extension ResortManifestDocument on EndpointClient {
  Future<DocumentOutcome<ResortManifest>> fetchResortManifest(
    String resortId,
  ) => fetchDocument(
    '/v1/resorts/$resortId/manifest',
    kind: resortManifestKind,
    parse: ResortManifest.parse,
  );
}
