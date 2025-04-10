import 'dart:async';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:camera_scanner/src/messages.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stream_transform/stream_transform.dart';

class CameraScanner extends CameraPlatform {
  CameraScanner({@visibleForTesting CameraApi? api})
      : _hostApi = api ?? CameraApi();

  /// Registers the Windows implementation of CameraPlatform.
  static CameraScanner registerWith() {
    CameraScanner s = CameraScanner();
    CameraPlatform.instance = s;
    return s;
  }

  final CameraApi _hostApi;

  @visibleForTesting
  final Map<int, HostCameraMessageHandler> hostCameraHandlers =
  <int, HostCameraMessageHandler>{};

  @visibleForTesting
  final StreamController<CameraEvent> cameraEventStreamController =
  StreamController<CameraEvent>.broadcast();

  /// Returns a stream of camera events for the given [cameraId].
  Stream<CameraEvent> _cameraEvents(int cameraId) =>
      cameraEventStreamController.stream
          .where((CameraEvent event) => event.cameraId == cameraId);

  @override
  Future<List<CameraDescription>> availableCameras() async {
    try {
      final List<String?> cameras = await _hostApi.getAvailableCameras();

      return cameras.map((String? cameraName) {
        return CameraDescription(
          // This type is only nullable due to Pigeon limitations, see
          // https://github.com/flutter/flutter/issues/97848. The native code
          // will never return null.
          name: cameraName!,
          // TODO(stuartmorgan): Implement these; see
          // https://github.com/flutter/flutter/issues/97540.
          lensDirection: CameraLensDirection.front,
          sensorOrientation: 0,
        );
      }).toList();
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message);
    }
  }

  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int cameraId) {
    return _cameraEvents(cameraId).whereType<CameraInitializedEvent>();
  }

  @override
  Stream<CameraClosingEvent> onCameraClosing(int cameraId) {
    return _cameraEvents(cameraId).whereType<CameraClosingEvent>();
  }

  @override
  Stream<CameraErrorEvent> onCameraError(int cameraId) {
    return _cameraEvents(cameraId).whereType<CameraErrorEvent>();
  }
  @override
  Widget buildPreview(int cameraId) {
    return Texture(textureId: cameraId);
  }

  @override
  Future<int> createCamera(
      CameraDescription cameraDescription,
      ResolutionPreset? resolutionPreset, {
        bool enableAudio = false,
      }) =>
      createCameraWithSettings(
          cameraDescription,
          MediaSettings(
            resolutionPreset: resolutionPreset,
            enableAudio: enableAudio,
          ));

  @override
  Future<int> createCameraWithSettings(
      CameraDescription cameraDescription,
      MediaSettings? mediaSettings,
      ) async {
    try {
      // If resolutionPreset is not specified, plugin selects the highest resolution possible.
      return await _hostApi.create(
          cameraDescription.name, _pigeonMediaSettings(mediaSettings));
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message);
    }
  }

  /// Returns a [MediaSettings]'s Pigeon representation.
  PlatformMediaSettings _pigeonMediaSettings(MediaSettings? settings) {
    return PlatformMediaSettings(
      resolutionPreset: _pigeonResolutionPreset(settings?.resolutionPreset),
      enableAudio: settings?.enableAudio ?? true,
      framesPerSecond: settings?.fps,
      videoBitrate: settings?.videoBitrate,
      audioBitrate: settings?.audioBitrate,
    );
  }

  /// Returns a [ResolutionPreset]'s Pigeon representation.
  PlatformResolutionPreset _pigeonResolutionPreset(
      ResolutionPreset? resolutionPreset) {
    if (resolutionPreset == null) {
      // Provide a default if one isn't provided, since the native side needs
      // to set something.
      return PlatformResolutionPreset.max;
    }
    switch (resolutionPreset) {
      case ResolutionPreset.max:
        return PlatformResolutionPreset.max;
      case ResolutionPreset.ultraHigh:
        return PlatformResolutionPreset.ultraHigh;
      case ResolutionPreset.veryHigh:
        return PlatformResolutionPreset.veryHigh;
      case ResolutionPreset.high:
        return PlatformResolutionPreset.high;
      case ResolutionPreset.medium:
        return PlatformResolutionPreset.medium;
      case ResolutionPreset.low:
        return PlatformResolutionPreset.low;
    }
    // The enum comes from a different package, which could get a new value at
    // any time, so provide a fallback that ensures this won't break when used
    // with a version that contains new values. This is deliberately outside
    // the switch rather than a `default` so that the linter will flag the
    // switch as needing an update.
    // ignore: dead_code
    return PlatformResolutionPreset.max;
  }

  @override
  Future<void> initializeCamera(
      int cameraId, {
        double ratio = 1/4,
        ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
      }) async {
    hostCameraHandlers.putIfAbsent(cameraId,
            () => HostCameraMessageHandler(cameraId, cameraEventStreamController));

    final PlatformSize reply;
    try {
      reply = await _hostApi.initialize(cameraId,ratio: ratio);
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message);
    }

    cameraEventStreamController.add(
      CameraInitializedEvent(
        cameraId,
        reply.width,
        reply.height,
        ExposureMode.auto,
        false,
        FocusMode.auto,
        false,
      ),
    );
  }

  @override
  Future<void> dispose(int cameraId) async {
    await _hostApi.dispose(cameraId);

    // Destroy method channel after camera is disposed to be able to handle last messages.
    hostCameraHandlers.remove(cameraId)?.dispose();
    ScanCodeEventApi.setUp(null, messageChannelSuffix: cameraId.toString());
  }
}


/// Callback handler for camera-level events from the platform host.
@visibleForTesting
class HostCameraMessageHandler implements CameraEventApi {
  /// Creates a new handler that listens for events from camera [cameraId], and
  /// broadcasts them to [streamController].
  HostCameraMessageHandler(this.cameraId, this.streamController) {
    CameraEventApi.setUp(this, messageChannelSuffix: cameraId.toString());
  }

  /// Removes the handler for native messages.
  void dispose() {
    CameraEventApi.setUp(null, messageChannelSuffix: cameraId.toString());
  }

  /// The camera ID this handler listens for events from.
  final int cameraId;

  /// The controller used to broadcast camera events coming from the
  /// host platform.
  final StreamController<CameraEvent> streamController;

  @override
  void error(String message) {
    streamController.add(CameraErrorEvent(cameraId, message));
  }

  @override
  void cameraClosing() {
    streamController.add(CameraClosingEvent(cameraId));
  }
}
