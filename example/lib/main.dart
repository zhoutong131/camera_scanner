import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:camera_scanner_example/scan_overlay.dart';
import 'package:flutter/material.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:camera_scanner/src/messages.g.dart';
import 'package:flutter/services.dart';
import 'package:camera_scanner/camera_scanner.dart';
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart';
void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> implements ScanCodeEventApi{
  String _platformVersion = 'Unknown';
  // final _cameraScannerPlugin = CameraScanner();
  //
  List<CameraDescription> _cameras = <CameraDescription>[];
  int _cameraIndex = 0;
  bool _initialized = false;
  int _cameraId = -1;
  final MediaSettings _mediaSettings = const MediaSettings(
    resolutionPreset: ResolutionPreset.max,
    fps: 15,
    videoBitrate: 200000,
    audioBitrate: 32000,
    enableAudio: false,
  );
  Size? _previewSize;
  StreamSubscription<CameraErrorEvent>? _errorStreamSubscription;
  StreamSubscription<CameraClosingEvent>? _cameraClosingStreamSubscription;

  @override
  void initState() {
    super.initState();
    writeContent("你好,我好，大家好");
    CameraScanner.registerWith();
    _fetchCameras().then((res) async{
      await _initializeCamera();
      if (_initialized &&_cameraId > 0) {
        print(9989);
      }
    });
  }

  Future<void> _fetchCameras() async {
    String cameraInfo;
    List<CameraDescription> cameras = <CameraDescription>[];

    int cameraIndex = 0;
    try {
      cameras = await CameraPlatform.instance.availableCameras();
      if (cameras.isEmpty) {
        cameraInfo = 'No available cameras';
      } else {
        cameraIndex = _cameraIndex % cameras.length;
        cameraInfo = 'Found camera: ${cameras[cameraIndex].name}';
      }
    } on PlatformException catch (e) {
      cameraInfo = 'Failed to get cameras: ${e.code}: ${e.message}';
    }
    _cameras = cameras;
  }

  Future<void> _initializeCamera() async {
    // 初始化相机
    assert(!_initialized);
    if (_cameras.isEmpty) {
      print("无摄像头");
      return;
    }
    int cameraId = -1;
    try {
      final int cameraIndex = 1;
      final
      camera = _cameras[cameraIndex];
      cameraId = await CameraPlatform.instance.createCameraWithSettings(
        camera,
        _mediaSettings,
      );

      unawaited(_errorStreamSubscription?.cancel());
      _errorStreamSubscription = CameraPlatform.instance
          .onCameraError(cameraId)
          .listen(_onCameraError);

      unawaited(_cameraClosingStreamSubscription?.cancel());
      _cameraClosingStreamSubscription = CameraPlatform.instance
          .onCameraClosing(cameraId)
          .listen(_onCameraClosing);

      final Future<CameraInitializedEvent> initialized =
          CameraPlatform.instance.onCameraInitialized(cameraId).first;

      ScanCodeEventApi.setUp(this, messageChannelSuffix: cameraId.toString());
      await CameraPlatform.instance.initializeCamera(
        cameraId,
      );
      final CameraInitializedEvent event = await initialized;
      _previewSize = Size(
        event.previewWidth,
        event.previewHeight,
      );
      print("当前宽：${event.previewWidth},高：${event.previewHeight}");
      if (mounted) {
        setState(() {
          _initialized = true;
          _cameraId = cameraId;
          _cameraIndex = cameraIndex;
        });
      }
    } on CameraException catch (e) {
      try {
        if (cameraId >= 0) {
          await CameraPlatform.instance.dispose(cameraId);
        }
      } on CameraException catch (e) {
        debugPrint('Failed to dispose camera: ${e.code}: ${e.description}');
      }

      // Reset state.
      if (mounted) {
        setState(() {
          _initialized = false;
          _cameraId = -1;
          _cameraIndex = 0;
          _previewSize = null;
          print('Failed to initialize camera: ${e.code}: ${e.description}');
        });
      }
    }
  }

  void _onCameraError(CameraErrorEvent event) {
    if (mounted) {
      print('Error: ${event.description}');
      _disposeCurrentCamera();
      _fetchCameras();
    }
  }

  void _onCameraClosing(CameraClosingEvent event) {
    if (mounted) {
      print('相机关了');
    }
  }

  Future<void> _disposeCurrentCamera() async {
    if (_cameraId >= 0 && _initialized) {
      try {
        await CameraPlatform.instance.dispose(_cameraId);

        if (mounted) {
          setState(() {
            _initialized = false;
            _cameraId = -1;
            _previewSize = null;
            // _recordingTimed = false;
            // _previewPaused = false;
          });
        }
      } on CameraException catch (e) {
        print('相机无法释放${e.code}: ${e.description}');
      }
    }
  }

  Widget _buildPreview() {
    return CameraPlatform.instance.buildPreview(_cameraId);
  }

  @override
  Widget build(BuildContext context) {
    return (_initialized && _cameraId > 0 && _previewSize != null)?AspectRatio(
      aspectRatio: _previewSize!.width / _previewSize!.height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform(
              alignment: Alignment.center,
              transform: Matrix4.rotationY(math.pi),
              child: _buildPreview()
          ),
          ScanOverlay(
            imgWidth: _previewSize?.width??640
          )
        ],
      ),
    ):Container();
  }

  void writeContent(String msg) async {
    if (!Platform.isWindows) {
      return;
    }
    String topPart = DateFormat('yyyy-MM-dd').format(DateTime.now());
    File logsFile = File("${path.dirname(Platform.resolvedExecutable)}\\${topPart}_logs.txt");
    if (!logsFile.existsSync()) {
      await logsFile.create();
    }
    logsFile.writeAsStringSync('$msg,时间：${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}${Platform.lineTerminator}',mode: FileMode.append);
  }
  @override
  void onScan(String code) {
    // TODO: implement onScan
    print(code);
    writeContent("当前code:$code");

  }
}
