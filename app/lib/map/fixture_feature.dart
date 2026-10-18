const _fixtureMarker = 'c4-skeleton';

bool containsFixtureFeature(List<Object?> renderedFeatures) =>
    renderedFeatures.any(_isFixtureFeature);

bool _isFixtureFeature(Object? feature) => switch (feature) {
  {'properties': {'fixture': _fixtureMarker}} => true,
  _ => false,
};
