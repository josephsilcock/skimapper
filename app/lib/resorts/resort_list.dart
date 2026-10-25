import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../endpoint/contract_envelope.dart';
import '../endpoint/run_record.dart';
import 'catalogue.dart';
import 'catalogue_document.dart';
import 'catalogue_store.dart';
import 'resort_list_providers.dart';

/// How the first load is going while no list is shown.
enum FirstLoad { loading, couldNotLoad }

/// What the resort list area shows.
class ResortListState {
  const ResortListState({this.shown, this.firstLoad = FirstLoad.loading});

  final Catalogue? shown;
  final FirstLoad firstLoad;
}

typedef _Answer = (int generation, DocumentOutcome<Catalogue> outcome);

/// The only writer of the shown resort list and its saved copy.
class ResortList extends Notifier<ResortListState> {
  @override
  ResortListState build() {
    Future.microtask(_launch);
    return const ResortListState();
  }

  /// Fetches are numbered as they start; the newest applied understood answer's number.
  var _fetchesStarted = 0;
  var _newestApplied = 0;
  Future<void> _saves = Future.value();

  /// The skier's pull.
  Future<void> refresh() async => _accept(await _fetch());

  CatalogueStore get _store => ref.read(catalogueStoreProvider);

  Future<void> _launch() async {
    final fetched = _fetch();
    _showSaved(await _store.read());
    await _accept(await fetched);
  }

  Future<_Answer> _fetch() async {
    final generation = ++_fetchesStarted;
    return (
      generation,
      await ref.read(endpointClientProvider).fetchCatalogue(),
    );
  }

  /// A saved copy this app can't read counts as nothing saved.
  void _showSaved(String? saved) {
    if (saved == null) return;
    if (openCatalogue(saved) case Understood(:final value)) {
      state = ResortListState(shown: value);
    }
  }

  /// An answer older than the newest applied understood one is dropped, whatever it is.
  Future<void> _accept(_Answer answer) async {
    final (generation, outcome) = answer;
    if (generation < _newestApplied) return;
    if (outcome case Understood(:final body, :final value)) {
      _newestApplied = generation;
      state = ResortListState(shown: value);
      await _save(generation, body);
    } else if (state.shown == null) {
      state = const ResortListState(firstLoad: FirstLoad.couldNotLoad);
    }
  }

  /// Saves run one at a time, and a save whose answer is no longer the newest is skipped, so an
  /// earlier save can never land last.
  Future<void> _save(int generation, String body) => _saves = _saves.then(
    (_) => generation == _newestApplied ? _write(body) : null,
  );

  /// A failed save keeps the list shown and the previous copy saved; it is reported, not shown.
  Future<void> _write(String body) async {
    try {
      await _store.write(body);
    } on FileSystemException catch (failure, stack) {
      recordRun('catalogue save failed: ${failure.message}');
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: failure,
          stack: stack,
          library: 'resorts',
          context: ErrorDescription('while saving the catalogue'),
        ),
      );
    }
  }
}
