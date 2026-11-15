import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:skimapper/main.dart';
import 'package:skimapper/resorts/choose_resort.dart';

/// Precondition: no default resort on the device.
Future<void> clearDefaultResort() => defaultResortFile().clear();

/// Precondition: [id] is the default resort.
Future<void> setDefaultResort(String id) => defaultResortFile().write(id);

/// Waits until the default resort is [id], so a relaunch can rely on it.
Future<void> awaitDefaultResort(String id) async {
  final file = defaultResortFile();
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (await file.read() != id) {
    if (DateTime.now().isAfter(deadline)) {
      fail('the default resort was not "$id" within 10 s');
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
}

/// Launches the app and returns the launch decision's run-record line once it is made.
Future<String> launchApp(PatrolIntegrationTester $) async {
  final decided = Completer<String>();
  final original = debugPrint;
  debugPrint = (message, {wrapWidth}) {
    original(message, wrapWidth: wrapWidth);
    if (message != null &&
        message.contains('] launch: ') &&
        !decided.isCompleted) {
      decided.complete(message);
    }
  };
  try {
    await $.pumpWidget(const SkimapperApp());
    return await decided.future.timeout(const Duration(seconds: 10));
  } finally {
    debugPrint = original;
  }
}
