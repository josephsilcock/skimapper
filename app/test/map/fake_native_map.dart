import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stands in for the native side of the map plugin at its channel boundary, so the real
/// `MapLibreMap` and its method-channel platform run against it.
///
/// Like a device, it serves the per-map channel only while the native view exists.
class FakeNativeMap {
  FakeNativeMap(this._tester, {this.holdViewCreation = false}) {
    _messenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      _handlePlatformViewCall,
    );
    addTearDown(_closeEverything);
  }

  final WidgetTester _tester;
  final bool holdViewCreation;
  final _waitForMap = Completer<Object?>();
  int? _viewId;
  bool waitForMapRequested = false;

  bool get viewCreationRequested => _viewId != null;

  /// Sends [method] to the map as the native side would, and says whether anything handled it.
  Future<bool> sendToMap(String method) async {
    final reply = Completer<ByteData?>();
    await _messenger.handlePlatformMessage(
      _mapChannel.name,
      _mapChannel.codec.encodeMethodCall(MethodCall(method)),
      reply.complete,
    );
    return await reply.future != null;
  }

  TestDefaultBinaryMessenger get _messenger =>
      _tester.binding.defaultBinaryMessenger;

  MethodChannel get _mapChannel =>
      MethodChannel('plugins.flutter.io/maplibre_gl_$_viewId');

  Future<Object?> _handlePlatformViewCall(MethodCall call) async {
    switch (call.method) {
      case 'create':
        _viewId = (call.arguments as Map)['id'] as int;
        if (holdViewCreation) return Completer<Object?>().future;
        _messenger.setMockMethodCallHandler(_mapChannel, _handleMapCall);
        return _textureIdForTarget();
      case 'dispose':
        _messenger.setMockMethodCallHandler(_mapChannel, null);
    }
    return null;
  }

  Future<Object?> _handleMapCall(MethodCall call) async {
    switch (call.method) {
      case 'map#waitForMap':
        waitForMapRequested = true;
        return _waitForMap.future;
    }
    return null;
  }

  int? _textureIdForTarget() =>
      defaultTargetPlatform == TargetPlatform.android ? 0 : null;

  void _closeEverything() {
    _messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    if (viewCreationRequested) {
      _messenger.setMockMethodCallHandler(_mapChannel, null);
    }
  }
}
