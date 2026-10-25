import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:skimapper/endpoint/endpoint_client.dart';
import 'package:skimapper/resorts/catalogue_store.dart';
import 'package:skimapper/resorts/resort_list_providers.dart';
import 'package:skimapper/resorts/resort_list_view.dart';

import '../support/pump_until_found.dart';

void main() {
  late CatalogueStore store;

  setUp(() {
    final directory = Directory.systemTemp.createTempSync('resort-list-');
    addTearDown(() => directory.deleteSync(recursive: true));
    store = CatalogueStore(() async => directory);
  });

  testWidgets('lists each served resort by name, with its countries', (
    tester,
  ) async {
    await tester.pumpWidget(_resortList(endpoint: _serving, store: store));
    await pumpUntilFound(tester, find.text('Espace San Bernardo'));

    expect(find.text('Espace San Bernardo'), findsOneWidget);
    expect(find.text('France · Italy'), findsOneWidget);
    expect(find.text('Paradiski'), findsOneWidget);
    expect(find.text('France'), findsOneWidget);
  });

  testWidgets('lists resorts by name, ignoring accents and capitals', (
    tester,
  ) async {
    await tester.pumpWidget(
      _resortList(
        endpoint: _answering(
          jsonEncode(_catalogueOf(['Zermatt', 'Évolène', 'alpe'])),
        ),
        store: store,
      ),
    );
    await pumpUntilFound(tester, find.text('Zermatt'));

    final tops = [
      'alpe',
      'Évolène',
      'Zermatt',
    ].map((name) => tester.getTopLeft(find.text(name)).dy).toList();
    expect(tops, orderedEquals([...tops]..sort()));
  });

  testWidgets('pulling the list down fetches again and shows the new list', (
    tester,
  ) async {
    final served = File(
      '${Directory.systemTemp.createTempSync('served-').path}/catalogue.json',
    )..writeAsStringSync(jsonEncode(_catalogue));
    await tester.pumpWidget(
      _resortList(endpoint: _answeringFrom(served.path), store: store),
    );
    await pumpUntilFound(tester, find.text('Paradiski'));

    served.writeAsStringSync(
      jsonEncode(_catalogueOf(['Paradiski', 'Évasion Mont-Blanc'])),
    );
    await _pullDown(tester);
    await pumpUntilFound(tester, find.text('Évasion Mont-Blanc'));

    expect(find.text('Évasion Mont-Blanc'), findsOneWidget);
  });

  testWidgets(
    'a slow launch answer landing after a pull never overwrites the pull\'s list',
    (tester) async {
      final served = File(
        '${Directory.systemTemp.createTempSync('served-').path}/catalogue.json',
      )..writeAsStringSync(jsonEncode({..._catalogue, 'dataVersion': 'slow'}));
      final pulled = jsonEncode(
        _catalogueOf(['Paradiski', 'Évasion Mont-Blanc']),
      );
      await tester.pumpWidget(
        _resortList(
          endpoint: _answeringFrom(served.path),
          store: store,
          timeout: const Duration(seconds: 5),
        ),
      );

      served.writeAsStringSync(pulled);
      await _pullDown(tester);
      await pumpUntilFound(tester, find.text('Évasion Mont-Blanc'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 2)),
      );
      await tester.pump();

      expect(find.text('Évasion Mont-Blanc'), findsOneWidget);
      expect(await _savedCopyOnceItIs(pulled, tester, store), pulled);
    },
  );

  testWidgets(
    'the newest understood answer is the one saved, even when an earlier save is slow',
    (tester) async {
      final directory = Directory.systemTemp.createTempSync('slow-store-');
      final slowFirstSave = _SlowFirstWrite(() async => directory);
      final served = File(
        '${Directory.systemTemp.createTempSync('served-').path}/catalogue.json',
      )..writeAsStringSync(jsonEncode(_catalogue));
      final pulled = jsonEncode(
        _catalogueOf(['Paradiski', 'Évasion Mont-Blanc']),
      );
      await tester.pumpWidget(
        _resortList(
          endpoint: _answeringFrom(served.path),
          store: slowFirstSave,
        ),
      );
      await pumpUntilFound(tester, find.text('Paradiski'));

      served.writeAsStringSync(pulled);
      await _pullDown(tester);
      await pumpUntilFound(tester, find.text('Évasion Mont-Blanc'));
      await _letTimePass(tester, const Duration(seconds: 2));

      expect(await tester.runAsync(slowFirstSave.read), pulled);
    },
  );

  testWidgets(
    'a fast failed launch fetch never beats a slow saved read to the screen',
    (tester) async {
      final directory = Directory.systemTemp.createTempSync('slow-read-');
      final slowRead = _SlowRead(() async => directory);
      await tester.runAsync(() => slowRead.write(jsonEncode(_catalogue)));

      await tester.pumpWidget(
        _resortList(endpoint: _refusing, store: slowRead),
      );
      await _letTimePass(tester, const Duration(milliseconds: 500));
      expect(find.text("Couldn't load resorts"), findsNothing);

      await _letTimePass(tester, const Duration(seconds: 1));
      expect(find.text('Paradiski'), findsOneWidget);
      expect(find.text("Couldn't load resorts"), findsNothing);
    },
  );

  testWidgets(
    'with nothing saved, shows a loading indicator while the first fetch runs',
    (tester) async {
      final served = File(
        '${Directory.systemTemp.createTempSync('served-').path}/catalogue.json',
      )..writeAsStringSync(jsonEncode({..._catalogue, 'dataVersion': 'slow'}));
      await tester.pumpWidget(
        _resortList(
          endpoint: _answeringFrom(served.path),
          store: store,
          timeout: const Duration(seconds: 5),
        ),
      );
      await _letTimePass(tester, const Duration(milliseconds: 300));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await pumpUntilFound(tester, find.text('Paradiski'));
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets(
    'with nothing saved and no service, says the resorts could not be loaded',
    (tester) async {
      await tester.pumpWidget(_resortList(endpoint: _refusing, store: store));
      await pumpUntilFound(tester, find.text("Couldn't load resorts"));

      expect(find.text("Couldn't load resorts"), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    },
  );

  for (final (recovery, recover) in [
    ('Retry', (WidgetTester tester) => tester.tap(find.text('Retry'))),
    ('pulling down', _pullDown),
  ]) {
    testWidgets(
      'after a failed first load, $recovery loads the list once the service answers',
      (tester) async {
        final served = File(
          '${Directory.systemTemp.createTempSync('served-').path}/catalogue.json',
        )..writeAsStringSync('service unavailable');
        await tester.pumpWidget(
          _resortList(endpoint: _answeringFrom(served.path), store: store),
        );
        await pumpUntilFound(tester, find.text("Couldn't load resorts"));

        served.writeAsStringSync(jsonEncode(_catalogue));
        await recover(tester);
        await pumpUntilFound(tester, find.text('Paradiski'));

        expect(find.text('Paradiski'), findsOneWidget);
        expect(find.text("Couldn't load resorts"), findsNothing);
      },
    );
  }

  testWidgets(
    'a pull that cannot reach the service keeps the list and says it couldn\'t refresh',
    (tester) async {
      await tester.runAsync(() => store.write(jsonEncode(_catalogue)));
      await tester.pumpWidget(_resortList(endpoint: _refusing, store: store));
      await pumpUntilFound(tester, find.text('Paradiski'));
      await _letTimePass(tester, const Duration(milliseconds: 300));
      expect(find.text("Couldn't refresh resorts"), findsNothing);

      await _pullDown(tester);
      await pumpUntilFound(tester, find.text("Couldn't refresh resorts"));

      expect(find.text("Couldn't refresh resorts"), findsOneWidget);
      expect(find.text('Paradiski'), findsOneWidget);
    },
  );

  for (final (answer, endpoint) in [
    ('a server error', _answeringStatus(500)),
    ('an empty catalogue', _answering(jsonEncode(_catalogueOf([])))),
  ]) {
    testWidgets(
      'a pull answered with $answer keeps the list and says it couldn\'t refresh',
      (tester) async {
        await tester.runAsync(() => store.write(jsonEncode(_catalogue)));
        await tester.pumpWidget(_resortList(endpoint: endpoint, store: store));
        await pumpUntilFound(tester, find.text('Paradiski'));

        await _pullDown(tester);
        await pumpUntilFound(tester, find.text("Couldn't refresh resorts"));

        expect(find.text("Couldn't refresh resorts"), findsOneWidget);
        expect(find.text('Paradiski'), findsOneWidget);
      },
    );
  }

  testWidgets('saves the understood catalogue exactly as served', (
    tester,
  ) async {
    await tester.pumpWidget(_resortList(endpoint: _serving, store: store));
    await pumpUntilFound(tester, find.text('Espace San Bernardo'));

    expect(
      await _savedCopyOnceItIs(jsonEncode(_catalogue), tester, store),
      jsonEncode(_catalogue),
    );
  });

  testWidgets('shows the saved list when the service cannot be reached', (
    tester,
  ) async {
    await tester.runAsync(() => store.write(jsonEncode(_catalogue)));

    await tester.pumpWidget(_resortList(endpoint: _refusing, store: store));
    await pumpUntilFound(tester, find.text('Espace San Bernardo'));

    expect(find.text('Espace San Bernardo'), findsOneWidget);
    expect(find.text('Paradiski'), findsOneWidget);
  });

  for (final (unreadable, copy) in [
    ('corrupt', 'not a catalogue'),
    ('older-schema', jsonEncode({..._catalogue, 'schemaVersion': 0})),
  ]) {
    testWidgets(
      'a $unreadable saved copy counts as nothing saved, and the fetch replaces it',
      (tester) async {
        await tester.runAsync(() => store.write(copy));

        await tester.pumpWidget(_resortList(endpoint: _serving, store: store));
        await pumpUntilFound(tester, find.text('Espace San Bernardo'));

        expect(find.text('Espace San Bernardo'), findsOneWidget);
        expect(
          await _savedCopyOnceItIs(jsonEncode(_catalogue), tester, store),
          jsonEncode(_catalogue),
        );
      },
    );
  }

  testWidgets(
    'a save that fails still shows the new list, and reports the failure',
    (tester) async {
      final unwritable = CatalogueStore(
        () async => Directory(
          '${Directory.systemTemp.path}/no-such-dir-${DateTime.now().microsecondsSinceEpoch}',
        ),
      );

      await tester.pumpWidget(
        _resortList(endpoint: _serving, store: unwritable),
      );
      await pumpUntilFound(tester, find.text('Espace San Bernardo'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();

      expect(find.text('Espace San Bernardo'), findsOneWidget);
      expect(tester.takeException(), isA<FileSystemException>());
    },
  );
}

Widget _resortList({
  required MockClientHandler endpoint,
  required CatalogueStore store,
  Duration timeout = const Duration(milliseconds: 100),
}) => ProviderScope(
  overrides: [
    endpointClientProvider.overrideWithValue(
      EndpointClient(
        baseUrl: Uri.parse('http://endpoint.test'),
        timeout: timeout,
        newHttpClient: () => MockClient(endpoint),
      ),
    ),
    catalogueStoreProvider.overrideWithValue(store),
  ],
  child: const MaterialApp(home: Scaffold(body: ResortListView())),
);

/// The saved copy once it reads as [expected], or as it last read if it doesn't within a second:
/// the app's save lands after the list shows.
Future<String?> _savedCopyOnceItIs(
  String expected,
  WidgetTester tester,
  CatalogueStore store,
) async {
  String? saved;
  for (var tries = 0; tries < 50 && saved != expected; tries++) {
    saved = await tester.runAsync<String?>(store.read);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  return saved;
}

Future<http.Response> _serving(http.Request request) async =>
    request.url.path == '/v1/catalogue'
    ? http.Response(jsonEncode(_catalogue), 200)
    : http.Response('not found', 404);

Future<http.Response> _refusing(http.Request request) async =>
    throw http.ClientException('Connection refused');

/// Answers every request with an empty body and [status].
MockClientHandler _answeringStatus(int status) =>
    (request) async => http.Response('', status);

/// Answers every request with [body]; captures nothing but it, so it can cross to the fetch isolate.
MockClientHandler _answering(String body) =>
    (request) async => http.Response(body, 200);

/// A store whose reads take a second.
class _SlowRead extends CatalogueStore {
  _SlowRead(super.directory);

  @override
  Future<String?> read() async {
    await Future<void>.delayed(const Duration(seconds: 1));
    return super.read();
  }
}

/// A store whose first save takes a second longer than the rest.
class _SlowFirstWrite extends CatalogueStore {
  _SlowFirstWrite(super.directory);

  var _writes = 0;

  @override
  Future<void> write(String body) async {
    if (_writes++ == 0) await Future<void>.delayed(const Duration(seconds: 1));
    await super.write(body);
  }
}

/// Lets [duration] pass in both real time (isolates, file IO) and the test's clock (timers).
Future<void> _letTimePass(WidgetTester tester, Duration duration) async {
  for (var step = Duration.zero; step < duration; step += _tick) {
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump(_tick);
  }
}

const _tick = Duration(milliseconds: 50);

/// Flings the list down and lets the refresh indicator's arm animation run, as a skier's pull does.
Future<void> _pullDown(WidgetTester tester) async {
  await tester.fling(find.byType(Scrollable).first, const Offset(0, 300), 1000);
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/// Answers every request with the file at [path] as it reads when the request arrives, so a test
/// can change what is served between fetches; a document whose dataVersion is "slow" is answered
/// a second late.
MockClientHandler _answeringFrom(String path) => (request) async {
  final body = File(path).readAsStringSync();
  if (body.contains('"dataVersion":"slow"')) {
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  return http.Response(body, 200);
};

Map<String, Object?> _catalogueOf(List<String> names) => {
  ..._catalogue,
  'data': {
    'resorts': [
      for (final name in names)
        {
          'name': name,
          'countries': ['Switzerland'],
          'centre': {'lat': 46.0, 'lon': 7.5},
        },
    ],
  },
};

const _catalogue = {
  'kind': 'catalogue',
  'schemaVersion': 1,
  'dataVersion': '2026-10-24',
  'data': {
    'resorts': [
      {
        'name': 'Paradiski',
        'countries': ['France'],
        'centre': {'lat': 45.55, 'lon': 6.8},
      },
      {
        'name': 'Espace San Bernardo',
        'countries': ['France', 'Italy'],
        'centre': {'lat': 45.68, 'lon': 6.88},
      },
    ],
  },
};
