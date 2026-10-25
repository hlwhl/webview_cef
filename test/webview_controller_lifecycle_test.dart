import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_cef/webview_cef.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('webview_cef');
  final List<MethodCall> calls = <MethodCall>[];
  int nextBrowserId = 1;

  /// Answers 'create' with [createResult], or a new browser and texture id.
  void mockPlugin({Object? Function()? createResult}) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      calls.add(call);
      if (call.method == 'create') {
        if (createResult != null) {
          return createResult();
        }
        final int id = nextBrowserId++;
        return <int>[id, id];
      }
      return null;
    });
  }

  List<String> methods() =>
      calls.map((MethodCall call) => call.method).toList();

  setUp(() async {
    calls.clear();
    mockPlugin();
    await WebviewManager().initialize();
    calls.clear();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('dispose of a controller that was never initialized completes', () async {
    final WebViewController controller = WebviewManager().createWebView();

    await controller.dispose().timeout(const Duration(seconds: 1));

    expect(methods(), isNot(contains('close')));
  });

  test('overlapping initialize calls create one browser', () async {
    final WebViewController controller = WebviewManager().createWebView();

    await Future.wait(<Future<void>>[
      controller.initialize('about:blank'),
      controller.initialize('about:blank'),
    ]);

    expect(methods().where((String method) => method == 'create'), hasLength(1));
    await controller.dispose();
  });

  test('an initialize error that is not a PlatformException does not hang dispose',
      () async {
    mockPlugin(createResult: () => <int>[]);
    final WebViewController controller = WebviewManager().createWebView();

    await expectLater(controller.initialize('about:blank'), throwsRangeError);
    await controller.dispose().timeout(const Duration(seconds: 1));
  });

  test('channels registered before initialize are injected once it has a browser',
      () async {
    final WebViewController controller = WebviewManager().createWebView();

    await controller.setJavaScriptChannels(<JavascriptChannel>{
      JavascriptChannel(name: 'early', onMessageReceived: (_) {}),
    });
    expect(methods(), isNot(contains('setJavaScriptChannels')));

    await controller.initialize('about:blank');

    final MethodCall injected = calls.singleWhere(
        (MethodCall call) => call.method == 'setJavaScriptChannels');
    expect((injected.arguments as List<Object?>)[1], <String>['early']);
    await controller.dispose();
  });
}
