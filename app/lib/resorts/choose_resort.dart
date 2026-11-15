import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../map/resort_map_screen.dart';
import '../storage/app_support_file.dart';
import 'catalogue.dart';

/// The default resort: the catalogue id of the resort the skier last chose.
final defaultResortFileProvider = Provider<AppSupportFile>(
  (ref) => defaultResortFile(),
);

AppSupportFile defaultResortFile() =>
    AppSupportFile.appSupport('default-resort');

/// The only way the app opens a resort's map.
Route<void> resortMapRoute(Resort resort) =>
    MaterialPageRoute<void>(builder: (_) => ResortMapScreen(resort: resort));

/// The skier chooses [resort]: its map opens, and it becomes the default resort.
void chooseResort(BuildContext context, WidgetRef ref, Resort resort) {
  ref.read(defaultResortFileProvider).write(resort.id);
  Navigator.of(context).push(resortMapRoute(resort));
}
