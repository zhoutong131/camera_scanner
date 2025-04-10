import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // MethodChannelCameraScanner platform = MethodChannelCameraScanner();
  const MethodChannel channel = MethodChannel('camera_scanner');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        return '42';
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  // test('getPlatformVersion', () async {
  //   expect(await platform.getPlatformVersion(), '42');
  // });
}
