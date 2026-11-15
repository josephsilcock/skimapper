import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skimapper/launch/launch_decision.dart';
import 'package:skimapper/resorts/catalogue.dart';
import 'package:skimapper/resorts/choose_resort.dart';
import 'package:skimapper/resorts/resort_list_providers.dart';
import 'package:skimapper/storage/app_support_file.dart';

void main() {
  test('the default resort reopens when it is in the saved list', () {
    expect(resortToReopen(defaultId: 'paradiski', saved: _saved), _paradiski);
  });

  test('with no default and nothing saved, nothing reopens', () {
    expect(resortToReopen(defaultId: null, saved: null), isNull);
  });

  test('with no default, nothing reopens from the saved list', () {
    expect(resortToReopen(defaultId: null, saved: _saved), isNull);
  });

  test(
    'launch reopens the default resort from what is saved on the device',
    () async {
      final directory = Directory.systemTemp.createTempSync('launch-');
      addTearDown(() => directory.deleteSync(recursive: true));
      final catalogueFile = AppSupportFile(
        'catalogue.json',
        () async => directory,
      );
      final defaultResort = AppSupportFile(
        'default-resort',
        () async => directory,
      );
      await catalogueFile.write(jsonEncode(_savedEnvelope));
      await defaultResort.write('paradiski');
      final container = ProviderContainer(
        overrides: [
          catalogueFileProvider.overrideWithValue(catalogueFile),
          defaultResortFileProvider.overrideWithValue(defaultResort),
        ],
      );
      addTearDown(container.dispose);

      expect(await container.read(resortToReopenProvider.future), _paradiski);
    },
  );
}

const _savedEnvelope = {
  'kind': 'catalogue',
  'schemaVersion': 1,
  'dataVersion': '2026-10-24',
  'data': {
    'resorts': [
      {
        'id': 'paradiski',
        'name': 'Paradiski',
        'countries': ['France'],
        'centre': {'lat': 45.55, 'lon': 6.8},
      },
    ],
  },
};

const _paradiski = Resort(
  id: 'paradiski',
  name: 'Paradiski',
  countries: ['France'],
  centre: (lat: 45.55, lon: 6.8),
);

const _saved = Catalogue([
  Resort(
    id: 'espace-san-bernardo',
    name: 'Espace San Bernardo',
    countries: ['France', 'Italy'],
    centre: (lat: 45.68, lon: 6.88),
  ),
  _paradiski,
]);
