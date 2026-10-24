import 'package:flutter_test/flutter_test.dart';
import 'package:skimapper/resorts/catalogue.dart';

void main() {
  test('reads each resort with its name, countries and centre', () {
    final catalogue = Catalogue.parse({
      'resorts': [
        {
          'name': 'Espace San Bernardo',
          'countries': ['France', 'Italy'],
          'centre': {'lat': 45.68, 'lon': 6.88},
        },
      ],
    });

    expect(catalogue.resorts, [
      const Resort(
        name: 'Espace San Bernardo',
        countries: ['France', 'Italy'],
        centre: (lat: 45.68, lon: 6.88),
      ),
    ]);
  });

  test('rejects a catalogue with no resorts', () {
    expect(() => Catalogue.parse({'resorts': []}), throwsFormatException);
  });

  test('rejects a catalogue with any entry missing its name, countries or centre', () {
    const complete = {
      'name': 'Paradiski',
      'countries': ['France'],
      'centre': {'lat': 45.55, 'lon': 6.8},
    };
    for (final malformed in [
      {...complete}..remove('name'),
      {...complete}..remove('countries'),
      {...complete, 'countries': <String>[]},
      {...complete}..remove('centre'),
      {...complete, 'centre': {'lat': 45.55}},
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

  test('labels a resort with all its countries, in catalogue order', () {
    const resort = Resort(
      name: 'Espace San Bernardo',
      countries: ['France', 'Italy'],
      centre: (lat: 45.68, lon: 6.88),
    );

    expect(resort.countriesLabel, 'France · Italy');
  });
}
