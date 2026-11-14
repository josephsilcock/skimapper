import 'dart:convert';

import 'basemap_layers.dart';
import 'resort_manifest.dart';

/// How a run is drawn, by its difficulty.
enum RunStyle { novice, easy, intermediate, advanced, freeride, unrated }

/// How a lift is drawn, by its type.
enum LiftStyle { aerial, drag }

String runLayerId(RunStyle style) => 'run-line-${style.name}';
const runAreaLayerId = 'run-area';
String liftLayerId(LiftStyle style) => 'lift-${style.name}';
const liftLabelLayerId = 'lift-label';
const liftCasingLayerId = 'lift-casing';
const liftStationLayerId = 'lift-station';
const runLabelLayerId = 'run-label';
const hillshadeLayerId = 'hillshade';

/// The basemap's land layer, drawn wherever there is land.
const basemapLandLayerId = 'earth';

/// The only style builder: a resort's map, every path in it a local file.
String resortMapStyle({
  required Map<PartRole, String> parts,
  required String glyphs,
  required BasemapLayers basemap,
}) => jsonEncode({
  'version': 8,
  'glyphs': 'file://$glyphs/{fontstack}/{range}.pbf',
  'sources': {
    'basemap': {
      'type': 'vector',
      'url': 'pmtiles://file://${parts[PartRole.basemap]}',
    },
    'terrain': {
      'type': 'raster-dem',
      'url': 'pmtiles://file://${parts[PartRole.terrain]}',
      'encoding': 'terrarium',
      'tileSize': 512,
    },
    'pistes': {'type': 'geojson', 'data': 'file://${parts[PartRole.pistes]}'},
  },
  'layers': [
    {
      'id': 'background',
      'type': 'background',
      'paint': {'background-color': '#f2f2f0'},
    },
    ...basemap.under,
    {
      'id': hillshadeLayerId,
      'type': 'hillshade',
      'source': 'terrain',
      'paint': {
        'hillshade-exaggeration': 0.3,
        'hillshade-shadow-color': '#6b6b6b',
      },
    },
    ...basemap.over,
    _runArea,
    for (final style in RunStyle.values) _runLine(style),
    _liftCasing,
    for (final style in LiftStyle.values) _liftCore(style),
    _liftStations,
    _label(runLabelLayerId, _isRun),
    _label(liftLabelLayerId, _isLift),
  ],
});

const _isRun = [
  '==',
  ['get', 'kind'],
  'run',
];

/// Single home for how a run is drawn by its difficulty: its colour, and the difficulties it
/// draws; a run of any other difficulty, or none, is unrated.
const _runLooks = {
  RunStyle.novice: (colour: '#1f9a2b', difficulties: ['novice'], dashed: false),
  RunStyle.easy: (colour: '#0060a8', difficulties: ['easy'], dashed: false),
  RunStyle.intermediate: (
    colour: '#ef2b31',
    difficulties: ['intermediate'],
    dashed: false,
  ),
  RunStyle.advanced: (
    colour: '#111111',
    difficulties: ['advanced', 'expert'],
    dashed: false,
  ),
  RunStyle.freeride: (
    colour: '#2e2a3a',
    difficulties: ['freeride', 'extreme'],
    dashed: true,
  ),
  RunStyle.unrated: (
    colour: '#8a8a8a',
    difficulties: <String>[],
    dashed: false,
  ),
};

final _ratedDifficulties = [
  for (final look in _runLooks.values) ...look.difficulties,
];

Map<String, Object?> _runLine(RunStyle style) => {
  'id': runLayerId(style),
  'type': 'line',
  'source': 'pistes',
  'filter': ['all', _isRun, _isLine, _hasDifficulty(style)],
  'paint': {
    'line-color': _runLooks[style]!.colour,
    'line-width': 3,
    if (_runLooks[style]!.dashed) 'line-dasharray': [2, 1.5],
  },
};

final _runArea = {
  'id': runAreaLayerId,
  'type': 'fill',
  'source': 'pistes',
  'filter': ['all', _isRun, _isPolygon],
  'paint': {
    'fill-color': [
      'match',
      ['get', 'difficulty'],
      for (final look in _runLooks.values)
        if (look.difficulties.isNotEmpty) ...[look.difficulties, look.colour],
      _runLooks[RunStyle.unrated]!.colour,
    ],
    'fill-opacity': 0.15,
  },
};

List<Object?> _hasDifficulty(RunStyle style) => style == RunStyle.unrated
    ? ['!', _difficultyIn(_ratedDifficulties)]
    : _difficultyIn(_runLooks[style]!.difficulties);

List<Object?> _difficultyIn(List<String> difficulties) => [
  'in',
  ['get', 'difficulty'],
  ['literal', difficulties],
];

const _isLine = [
  '==',
  ['geometry-type'],
  'LineString',
];

const _isPolygon = [
  '==',
  ['geometry-type'],
  'Polygon',
];

/// Single home for which lift types are drawn as drag lifts; every other type, or none, is an
/// aerial lift.
const _dragLiftTypes = [
  'drag_lift',
  't-bar',
  'j-bar',
  'platter',
  'rope_tow',
  'magic_carpet',
];

const _liftColour = '#2e2a3a';

const _isLift = [
  '==',
  ['get', 'kind'],
  'lift',
];

const _isDragLift = [
  'in',
  ['get', 'liftType'],
  ['literal', _dragLiftTypes],
];

List<Object?> _liftsOf(LiftStyle style) =>
    style == LiftStyle.drag ? _isDragLift : ['!', _isDragLift];

const _liftCasing = {
  'id': liftCasingLayerId,
  'type': 'line',
  'source': 'pistes',
  'filter': _isLift,
  'paint': {'line-color': '#ffffff', 'line-width': 6},
};

Map<String, Object?> _liftCore(LiftStyle style) => {
  'id': liftLayerId(style),
  'type': 'line',
  'source': 'pistes',
  'filter': ['all', _isLift, _liftsOf(style)],
  'paint': {
    'line-color': _liftColour,
    'line-width': 2.5,
    if (style == LiftStyle.drag) 'line-dasharray': [1, 1.5],
  },
};

final _liftStations = {
  'id': liftStationLayerId,
  'type': 'circle',
  'source': 'pistes',
  // A lift's vertices include its pylons; zoomed out, their dots would hide the runs.
  'minzoom': 14,
  'filter': ['all', _isLift, _liftsOf(LiftStyle.aerial)],
  'paint': {
    'circle-color': _liftColour,
    'circle-radius': 3.5,
    'circle-stroke-color': '#ffffff',
    'circle-stroke-width': 1.5,
  },
};

/// Names along each feature's line, in the map's one label look.
Map<String, Object?> _label(String id, List<Object?> filter) => {
  'id': id,
  'type': 'symbol',
  'source': 'pistes',
  'filter': filter,
  'layout': {
    'text-field': ['get', 'name'],
    'text-font': ['Noto Sans Regular'],
    'text-size': 12,
    'symbol-placement': 'line',
  },
  'paint': {
    'text-color': '#1b2a2e',
    'text-halo-color': '#ffffff',
    'text-halo-width': 1.5,
  },
};
