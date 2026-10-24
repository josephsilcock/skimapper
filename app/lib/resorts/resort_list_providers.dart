import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../endpoint/dev_endpoint.dart';
import '../endpoint/endpoint_client.dart';
import 'catalogue_store.dart';
import 'resort_list.dart';

final endpointClientProvider = Provider<EndpointClient>(
  (ref) => devEndpointClient(),
);

final resortListProvider = NotifierProvider<ResortList, ResortListState>(
  ResortList.new,
);

final catalogueStoreProvider = Provider<CatalogueStore>(
  (ref) => CatalogueStore.appSupport(),
);
