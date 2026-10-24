import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../endpoint/contract_envelope.dart';
import '../endpoint/run_record.dart';
import 'catalogue.dart';
import 'catalogue_document.dart';
import 'catalogue_store.dart';
import 'resort_list_providers.dart';

/// What the resort list area shows.
class ResortListState {
  const ResortListState({this.shown});

  final Catalogue? shown;
}

/// The only writer of the shown resort list and its saved copy.
class ResortList extends Notifier<ResortListState> {
  @override
  ResortListState build() {
    Future.microtask(_launch);
    return const ResortListState();
  }

  CatalogueStore get _store => ref.read(catalogueStoreProvider);

  Future<void> _launch() async {
    final fetched = ref.read(endpointClientProvider).fetchCatalogue();
    _showSaved(await _store.read());
    await _accept(await fetched);
  }

  /// A saved copy this app can't read counts as nothing saved.
  void _showSaved(String? saved) {
    if (saved == null) return;
    if (openCatalogue(saved) case Understood(:final value)) {
      state = ResortListState(shown: value);
    }
  }

  Future<void> _accept(DocumentOutcome<Catalogue> outcome) async {
    if (outcome case Understood(:final body, :final value)) {
      state = ResortListState(shown: value);
      await _save(body);
    }
  }

  /// A failed save keeps the list shown and the previous copy saved; it is reported, not shown.
  Future<void> _save(String body) async {
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
