import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stands in for the native side of the map plugin at its channel boundary, so the real
/// `MapLibreMap` and its method-channel platform run against it.
///
/// Like a device, it serves the per-map channel only while the native view exists; once the view
/// is disposed, a call on that channel is answered as not implemented.
class FakeNativeMap {
  FakeNativeMap(
    this._tester, {
    this.holdViewCreation = false,
    this.holdWaitForMap = false,
  }) {
    _messenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      _handlePlatformViewCall,
    );
    addTearDown(_closeEverything);
  }

  final bool holdViewCreation;
  final bool holdWaitForMap;

  final WidgetTester _tester;
  int? _viewId;
  bool _waitForMapRequested = false;
  final List<MethodCall> _cameraMoves = [];
  final List<String> _mapCalls = [];

  /// The camera updates the map asked the native side for, in order.
  List<Object?> get cameraMoves => [
    for (final call in _cameraMoves) (call.arguments as Map)['cameraUpdate'],
  ];

  /// The methods the map called on the native side, in order.
  List<String> get mapCalls => List.unmodifiable(_mapCalls);

  bool get waitForMapRequested => _waitForMapRequested;

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
        _messenger.setMockMessageHandler(_mapChannel.name, _notImplemented);
    }
    return null;
  }

  Future<Object?> _handleMapCall(MethodCall call) async {
    _mapCalls.add(call.method);
    switch (call.method) {
      case 'map#waitForMap':
        _waitForMapRequested = true;
        return holdWaitForMap ? Completer<Object?>().future : null;
      case 'camera#move':
        _cameraMoves.add(call);
        return true;
    }
    return null;
  }

  static Future<ByteData?> _notImplemented(ByteData? _) async => null;

  int? _textureIdForTarget() =>
      defaultTargetPlatform == TargetPlatform.android ? 0 : null;

  void _closeEverything() {
    _messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    if (viewCreationRequested) {
      _messenger.setMockMessageHandler(_mapChannel.name, null);
    }
  }
}
