import 'package:flutter_test/flutter_test.dart';
import 'package:skimapper/resorts/catalogue.dart';

void main() {
  test('reads each resort with its id, name, countries and centre', () {
    final catalogue = Catalogue.parse({
      'resorts': [
        {
          'id': 'espace-san-bernardo',
          'name': 'Espace San Bernardo',
          'countries': ['France', 'Italy'],
          'centre': {'lat': 45.68, 'lon': 6.88},
        },
      ],
    });

    expect(catalogue.resorts, [
      const Resort(
        id: 'espace-san-bernardo',
        name: 'Espace San Bernardo',
        countries: ['France', 'Italy'],
        centre: (lat: 45.68, lon: 6.88),
      ),
    ]);
  });

  test('rejects a catalogue with no resorts', () {
    expect(() => Catalogue.parse({'resorts': []}), throwsFormatException);
  });

  test('rejects a catalogue with any entry missing its id, name, countries or centre, or with a malformed id', () {
    const complete = {
      'id': 'paradiski',
      'name': 'Paradiski',
      'countries': ['France'],
      'centre': {'lat': 45.55, 'lon': 6.8},
    };
    for (final malformed in [
      {...complete}..remove('id'),
      {...complete, 'id': 'Paradiski'},
      {...complete, 'id': 'para diski'},
      {...complete, 'id': ''},
      {...complete}..remove('name'),
      {...complete}..remove('countries'),
      {...complete, 'countries': <String>[]},
      {...complete}..remove('centre'),
      {
        ...complete,
        'centre': {'lat': 45.55},
      },
    ]) {
      expect(
        () => Catalogue.parse({
          'resorts': [complete, malformed],
        }),
        throwsFormatException,
        reason: '$malformed',
      );
    }
  });

  test('rejects a catalogue in which two resorts share an id', () {
    Map<String, Object?> entry(String name) => {
      'id': 'paradiski',
      'name': name,
      'countries': ['France'],
      'centre': {'lat': 45.55, 'lon': 6.8},
    };

    expect(
      () => Catalogue.parse({
        'resorts': [entry('Paradiski'), entry('Les Arcs')],
      }),
      throwsFormatException,
    );
  });

  test('labels a resort with all its countries, in catalogue order', () {
    const resort = Resort(
      id: 'espace-san-bernardo',
      name: 'Espace San Bernardo',
      countries: ['France', 'Italy'],
      centre: (lat: 45.68, lon: 6.88),
    );

    expect(resort.countriesLabel, 'France · Italy');
  });

  test('orders resorts by name, ignoring accents and capitals, ties on the name as written', () {
    Resort named(String name) => Resort(
      id: 'any',
      name: name,
      countries: const ['France'],
      centre: (lat: 0, lon: 0),
    );
    final catalogue = Catalogue([
      named('Zermatt'),
      named('Évolène'),
      named('alpe'),
      named('Alpe'),
    ]);

    expect(catalogue.byName.map((resort) => resort.name), [
      'Alpe',
      'alpe',
      'Évolène',
      'Zermatt',
    ]);
  });
}
