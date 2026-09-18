import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_cef/webview_cef.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('webview_cef');
  final List<MethodCall> calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  /// Records the arguments the manager sends with 'init'.
  Future<dynamic> initArguments({String? userAgent, String? rootCachePath}) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      calls.add(call);
      return null;
    });
    await WebviewManager()
        .initialize(userAgent: userAgent, rootCachePath: rootCachePath);
    return calls.firstWhere((MethodCall call) => call.method == 'init').arguments;
  }

  test('init is sent without arguments when nothing is configured', () async {
    expect(await initArguments(), isNull);
  });

  test('init carries the user agent', () async {
    expect(await initArguments(userAgent: 'agent/1.0'),
        <String, String>{'userAgent': 'agent/1.0'});
  });

  test('init carries the root cache path', () async {
    expect(await initArguments(rootCachePath: '/tmp/webview_cef'),
        <String, String>{'rootCachePath': '/tmp/webview_cef'});
  });

  test('init carries both settings', () async {
    expect(
      await initArguments(userAgent: 'agent/1.0', rootCachePath: '/tmp/webview_cef'),
      <String, String>{'userAgent': 'agent/1.0', 'rootCachePath': '/tmp/webview_cef'},
    );
  });

  test('empty settings are left out', () async {
    expect(await initArguments(userAgent: '', rootCachePath: ''), isNull);
  });
}
