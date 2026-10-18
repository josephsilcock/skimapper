import 'package:flutter_test/flutter_test.dart';
import 'package:skimapper/map/fixture_feature.dart';

void main() {
  test('recognises the fixture feature among rendered features', () {
    final rendered = [
      {'type': 'Feature', 'properties': {'name': 'other'}},
      {'type': 'Feature', 'properties': {'fixture': 'c4-skeleton'}},
    ];

    expect(containsFixtureFeature(rendered), isTrue);
  });
}
