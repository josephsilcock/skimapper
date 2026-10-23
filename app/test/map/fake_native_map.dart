import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stands in for the native side of the map plugin at its channel boundary, so the real
/// `MapLibreMap` and its method-channel platform run against it.
class FakeNativeMap {
  FakeNativeMap(this._tester) {
    _messenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      _handlePlatformViewCall,
    );
    addTearDown(
      () => _messenger.setMockMethodCallHandler(
        SystemChannels.platform_views,
        null,
      ),
    );
  }

  final WidgetTester _tester;
  final _heldViewCreation = Completer<Object?>();
  bool viewCreationRequested = false;

  TestDefaultBinaryMessenger get _messenger =>
      _tester.binding.defaultBinaryMessenger;

  Future<Object?> _handlePlatformViewCall(MethodCall call) async {
    switch (call.method) {
      case 'create':
        viewCreationRequested = true;
        return _heldViewCreation.future;
      default:
        return null;
    }
  }
}
