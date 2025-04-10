import 'package:flutter_test/flutter_test.dart';
import 'package:camera_scanner/camera_scanner.dart';
// import 'package:camera_scanner/camera_scanner_platform_interface.dart';
// import 'package:camera_scanner/camera_scanner_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockCameraScannerPlatform
    with MockPlatformInterfaceMixin {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  // final CameraScannerPlatform initialPlatform = CameraScannerPlatform.instance;
  //
  // test('$MethodChannelCameraScanner is the default instance', () {
  //   expect(initialPlatform, isInstanceOf<MethodChannelCameraScanner>());
  // });
  //
  // test('getPlatformVersion', () async {
  //   CameraScanner cameraScannerPlugin = CameraScanner();
  //   MockCameraScannerPlatform fakePlatform = MockCameraScannerPlatform();
  //   CameraScannerPlatform.instance = fakePlatform;
  //
  //   expect(await cameraScannerPlugin.getPlatformVersion(), '42');
  // });
}
