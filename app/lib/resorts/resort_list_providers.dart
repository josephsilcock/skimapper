import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../endpoint/contract_envelope.dart';
import '../endpoint/dev_endpoint.dart';
import '../endpoint/endpoint_client.dart';
import '../storage/app_support_file.dart';
import 'catalogue.dart';
import 'catalogue_document.dart';
import 'resort_list.dart';

final endpointClientProvider = Provider<EndpointClient>(
  (ref) => devEndpointClient(),
);

final resortListProvider = NotifierProvider<ResortList, ResortListState>(
  ResortList.new,
);

/// The saved copy of the catalogue, kept as served.
final catalogueFileProvider = Provider<AppSupportFile>(
  (ref) => savedCatalogueFile(),
);

AppSupportFile savedCatalogueFile() =>
    AppSupportFile.appSupport('catalogue.json');

/// The saved list as read at launch, once; a copy this app can't read counts as nothing saved.
final savedCatalogueAtLaunchProvider = FutureProvider<Catalogue?>((ref) async {
  final saved = await ref.watch(catalogueFileProvider).read();
  if (saved == null) return null;
  return switch (openCatalogue(saved)) {
    Understood(:final value) => value,
    _ => null,
  };
});
