import 'dart:async';
import 'dart:convert';

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
    this.fixtureNeverRenders = false,
  }) {
    _messenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      _handlePlatformViewCall,
    );
    addTearDown(_closeEverything);
  }

  final bool holdViewCreation;
  final bool holdWaitForMap;

  /// Answers every fixture query at once without the fixture feature, instead of holding it.
  final bool fixtureNeverRenders;

  final WidgetTester _tester;
  int? _viewId;
  bool waitForMapRequested = false;
  Completer<Object?>? _queryInFlight;

  bool get viewCreationRequested => _viewId != null;

  bool get queryInFlight => _queryInFlight != null;

  /// Answers the fixture query in flight, as the native map would even once its view has gone.
  void answerQuery({required bool found}) {
    _queryInFlight!.complete(_queryReply(found: found));
    _queryInFlight = null;
  }

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
    switch (call.method) {
      case 'map#waitForMap':
        waitForMapRequested = true;
        return holdWaitForMap ? Completer<Object?>().future : null;
      case 'map#queryRenderedFeatures':
        if (fixtureNeverRenders) return _queryReply(found: false);
        _queryInFlight = Completer<Object?>();
        return _queryInFlight!.future;
    }
    return null;
  }

  static Map<String, Object?> _queryReply({required bool found}) => {
    'features': [if (found) jsonEncode(_fixtureFeature)],
  };

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

const _fixtureFeature = {
  'type': 'Feature',
  'properties': {'fixture': 'c4-skeleton'},
};
