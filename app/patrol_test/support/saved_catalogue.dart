import 'package:flutter_test/flutter_test.dart';
import 'package:skimapper/resorts/catalogue_store.dart';

/// Precondition: nothing saved on the device.
Future<void> clearSavedCatalogue() => CatalogueStore.appSupport().clear();

/// Waits until the app has saved a catalogue, so a relaunch can rely on it.
Future<void> awaitSavedCatalogue() async {
  final store = CatalogueStore.appSupport();
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (await store.read() == null) {
    if (DateTime.now().isAfter(deadline)) {
      fail('the app saved no catalogue within 10 s');
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
}
