import 'package:maplibre_gl/maplibre_gl.dart';

/// The plugin's method-channel platform, made safe to tear down before its channel is opened.
///
/// The plugin opens the channel in [initPlatform], once the native view exists, but tears the
/// platform down whenever the map is removed. Removed earlier, there is nothing to close.
class StartUpSafeMapPlatform extends MapLibreMethodChannel {
  bool _channelOpened = false;

  @override
  Future<void> initPlatform(int id) {
    _channelOpened = true;
    return super.initPlatform(id);
  }

  @override
  void dispose() {
    if (_channelOpened) super.dispose();
  }
}

void installStartUpSafeMapPlatform() {
  MapLibrePlatform.createInstance = StartUpSafeMapPlatform.new;
}
