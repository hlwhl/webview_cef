import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_cef/webview_cef_method_channel.dart';

void main() {
  MethodChannelWebviewCef platform = MethodChannelWebviewCef();
  const MethodChannel channel = MethodChannel('webview_cef');

  // Ensure test binding is initialized
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async => '42',
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}
