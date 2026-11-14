import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stands in for the native side of the map plugin at its channel boundary, so the real
/// `MapLibreMap` and its Pigeon-based platform run against it.
///
/// Like a device, it serves the map's host calls only while the native view exists; once the view
/// is disposed, a host call goes unanswered.
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
  final List<Object?> _cameraMoves = [];

  /// The camera updates the map asked the native side for, in order, each as the fields Pigeon
  /// sends it with, nested types included.
  List<Object?> get cameraMoves => List.unmodifiable(_cameraMoves);

  bool get waitForMapRequested => _waitForMapRequested;

  bool get viewCreationRequested => _viewId != null;

  /// Sends the map event [event] as the native side would, and says whether anything handled it.
  Future<bool> sendToMap(String event) async {
    final reply = Completer<ByteData?>();
    await _messenger.handlePlatformMessage(
      '$_flutterApi.$event.$_viewId',
      _codec.encodeMessage(null),
      reply.complete,
    );
    return await reply.future != null;
  }

  static const _hostApi = 'dev.flutter.pigeon.maplibre_gl.MapLibreMapHostApi';
  static const _flutterApi =
      'dev.flutter.pigeon.maplibre_gl.MapLibreMapFlutterApi';
  static const _codec = _PigeonFieldsCodec();

  TestDefaultBinaryMessenger get _messenger =>
      _tester.binding.defaultBinaryMessenger;

  late final Map<String, Future<Object?> Function(List<Object?> args)>
  _hostCalls = {
    'mapWaitForMap': (_) async {
      _waitForMapRequested = true;
      if (holdWaitForMap) await Completer<void>().future;
      return null;
    },
    'cameraMove': (args) async {
      _cameraMoves.add(args.single);
      return true;
    },
    // The plugin's annotation managers add their sources and layers on every style load.
    for (final method in const [
      'sourceAddGeoJson',
      'fillLayerAdd',
      'lineLayerAdd',
      'circleLayerAdd',
      'symbolLayerAdd',
    ])
      method: (_) async => null,
  };

  String _hostChannel(String method) => '$_hostApi.$method.$_viewId';

  Future<Object?> _handlePlatformViewCall(MethodCall call) async {
    switch (call.method) {
      case 'create':
        _viewId = (call.arguments as Map)['id'] as int;
        if (holdViewCreation) return Completer<Object?>().future;
        _serveHostCalls();
        return _textureIdForTarget();
      case 'dispose':
        _stopServingHostCalls();
    }
    return null;
  }

  void _serveHostCalls() {
    for (final MapEntry(key: method, value: answer) in _hostCalls.entries) {
      _messenger.setMockMessageHandler(_hostChannel(method), (message) async {
        // A call without arguments sends none, not an empty list.
        final args = _codec.decodeMessage(message) as List<Object?>? ?? [];
        return _codec.encodeMessage([await answer(args)]);
      });
    }
  }

  void _stopServingHostCalls() {
    for (final method in _hostCalls.keys) {
      _messenger.setMockMessageHandler(_hostChannel(method), null);
    }
  }

  int? _textureIdForTarget() =>
      defaultTargetPlatform == TargetPlatform.android ? 0 : null;

  void _closeEverything() {
    _messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    if (viewCreationRequested) _stopServingHostCalls();
  }
}

/// Pigeon's codec as seen from the native side, reading each of its own types as the list of
/// fields it is sent as.
class _PigeonFieldsCodec extends StandardMessageCodec {
  const _PigeonFieldsCodec();

  static const _firstPigeonType = 129;

  @override
  Object? readValueOfType(int type, ReadBuffer buffer) =>
      type >= _firstPigeonType
      ? readValue(buffer)
      : super.readValueOfType(type, buffer);
}
