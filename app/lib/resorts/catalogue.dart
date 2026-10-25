import 'package:flutter/foundation.dart';

import '../text/fold.dart';

/// The supported ski areas, as the catalogue document lists them. Single home for what an
/// understood catalogue is: at least one resort, each with a name, countries and a centre.
class Catalogue {
  const Catalogue(this.resorts);

  final List<Resort> resorts;

  /// Resorts by name, ignoring accents and capitals; never catalogue order, which F20 regenerates.
  List<Resort> get byName => [...resorts]..sort(_byFoldedName);

  static int _byFoldedName(Resort a, Resort b) {
    final byFolded = folded(a.name).compareTo(folded(b.name));
    return byFolded != 0 ? byFolded : a.name.compareTo(b.name);
  }

  /// The catalogue kind's parse for `openDocument`.
  static Catalogue parse(Map<String, Object?> data) => switch (data) {
    {'resorts': List<Object?> entries} when entries.isNotEmpty => Catalogue([
      for (final entry in entries) Resort._parse(entry),
    ]),
    _ => throw const FormatException('no resorts'),
  };
}

@immutable
class Resort {
  const Resort({
    required this.name,
    required this.countries,
    required this.centre,
  });

  factory Resort._parse(Object? entry) => switch (entry) {
    {
      'name': String name,
      'countries': List<Object?> countries,
      'centre': {'lat': num lat, 'lon': num lon},
    }
        when countries.isNotEmpty && countries.every((c) => c is String) =>
      Resort(
        name: name,
        countries: countries.cast<String>(),
        centre: (lat: lat.toDouble(), lon: lon.toDouble()),
      ),
    _ => throw FormatException('malformed resort', entry),
  };

  final String name;
  final List<String> countries;
  final ({double lat, double lon}) centre;

  String get countriesLabel => countries.join(' · ');

  @override
  bool operator ==(Object other) =>
      other is Resort &&
      other.name == name &&
      listEquals(other.countries, countries) &&
      other.centre == centre;

  @override
  int get hashCode => Object.hash(name, Object.hashAll(countries), centre);
}
