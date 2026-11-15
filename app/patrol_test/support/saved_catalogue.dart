import 'package:flutter_test/flutter_test.dart';
import 'package:skimapper/resorts/resort_list_providers.dart';

/// Precondition: nothing saved on the device.
Future<void> clearSavedCatalogue() => savedCatalogueFile().clear();

/// Precondition: [copy] is the saved catalogue, exactly as given.
Future<void> saveCatalogueCopy(String copy) => savedCatalogueFile().write(copy);

/// Waits until the app has saved a catalogue, so a relaunch can rely on it.
Future<void> awaitSavedCatalogue() =>
    _awaitSaved((saved) => saved != null, 'no catalogue');

/// Waits until the app has saved a catalogue that mentions [name].
Future<void> awaitSavedCatalogueListing(String name) => _awaitSaved(
  (saved) => saved?.contains(name) ?? false,
  'no catalogue listing $name',
);

Future<void> _awaitSaved(
  bool Function(String? saved) until,
  String what,
) async {
  final store = savedCatalogueFile();
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (!until(await store.read())) {
    if (DateTime.now().isAfter(deadline)) {
      fail('the app saved $what within 10 s');
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
}
