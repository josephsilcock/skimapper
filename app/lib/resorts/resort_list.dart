import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../endpoint/contract_envelope.dart';
import 'catalogue.dart';
import 'catalogue_document.dart';
import 'resort_list_providers.dart';

/// What the resort list area shows.
class ResortListState {
  const ResortListState({this.shown});

  final Catalogue? shown;
}

/// The only writer of the shown resort list.
class ResortList extends Notifier<ResortListState> {
  @override
  ResortListState build() {
    Future.microtask(_launch);
    return const ResortListState();
  }

  Future<void> _launch() async {
    final outcome = await ref.read(endpointClientProvider).fetchCatalogue();
    if (outcome case Understood(:final value)) {
      state = ResortListState(shown: value);
    }
  }
}
