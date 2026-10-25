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
  const ResortListState({
    this.shown,
    this.firstLoad = FirstLoad.loading,
    this.failedRefreshes = 0,
  });

  final Catalogue? shown;
  final FirstLoad firstLoad;

  /// Counts the skier's refreshes that failed over a shown list; each new one is a brief message.
  final int failedRefreshes;
}

/// Who asked for a fetch: the app at launch, quietly, or the skier (pull or Retry).
enum _Trigger { quietLaunch, skier }

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
  Future<void> refresh() async =>
      _accept(await _fetch(), trigger: _Trigger.skier);

  CatalogueStore get _store => ref.read(catalogueStoreProvider);

  Future<void> _launch() async {
    final fetched = _fetch();
    _showSaved(await _store.read());
    await _accept(await fetched, trigger: _Trigger.quietLaunch);
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

  /// The apply step: what the skier sees for an answer, given who asked and whether a list is
  /// shown. An answer older than the newest applied understood one is dropped, whatever it is.
  Future<void> _accept(_Answer answer, {required _Trigger trigger}) async {
    final (generation, outcome) = answer;
    if (generation < _newestApplied) return;
    switch (outcome) {
      case Understood(:final body, :final value):
        _newestApplied = generation;
        state = ResortListState(shown: value);
        await _save(generation, body);
      case Incompatible() || Failed():
        state = _afterFailure(trigger);
    }
  }

  ResortListState _afterFailure(_Trigger trigger) =>
      switch ((state.shown, trigger)) {
        (null, _) => const ResortListState(firstLoad: FirstLoad.couldNotLoad),
        (final shown, _Trigger.skier) => ResortListState(
          shown: shown,
          failedRefreshes: state.failedRefreshes + 1,
        ),
        (_, _Trigger.quietLaunch) => state,
      };

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
