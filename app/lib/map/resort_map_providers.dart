import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// The folder under which each open of a resort's map keeps its parts.
final scratchRootProvider = Provider<Future<Directory>>(
  (ref) async =>
      Directory('${(await getTemporaryDirectory()).path}/resort-maps')
          .create(recursive: true),
);
