import 'package:webview_cef/src/webview.dart';

/// Decides whether to allow or cancel a navigation request.
enum NavigationPolicy {
  /// Cancel the navigation.
  cancel,

  /// Allow the navigation to proceed.
  allow,
}

/// Error information passed to [PageErrorCallback].
class WebViewError {
  const WebViewError(this.code, this.message, [this.extraInfo]);

  /// CEF error code (e.g. ERR_ABORTED, ERR_NAME_NOT_RESOLVED).
  final int code;

  /// Localized error description.
  final String message;

  /// Additional error context. Includes "url" key with the failing URL.
  final Map<String, dynamic>? extraInfo;
}

/// Called before a navigation starts. Return [NavigationPolicy.cancel] to
/// reject the navigation; follow up with [WebViewController.stopLoading]
/// to actually abort it.
typedef PageNavigationDelegate = NavigationPolicy Function(
    WebViewController controller, String url);

/// Called when a page has started loading.
typedef PageStartedCallback = void Function(
    WebViewController controller, String url);

/// Called when a page has finished loading.
typedef PageFinishedCallback = void Function(
    WebViewController controller, String url);

/// Called as page load progress updates.
typedef PageProgressCallback = void Function(
    WebViewController controller, double progress);

/// Called when a page load fails with an error.
typedef PageErrorCallback = void Function(
    WebViewController controller, String url, WebViewError error);

/// Called when the CEF render process terminates unexpectedly (crash, OOM,
/// killed). Use [WebViewController.reload] to restore the page — CEF has
/// already created a new render process.
///
/// [status]: 0 = TS_ABNORMAL_TERMINATION, 1 = TS_PROCESS_WAS_KILLED,
///           2 = TS_PROCESS_CRASHED, 3 = TS_PROCESS_OOM.
/// [errorCode]: platform-specific exit/crash code (e.g. Posix signal).
/// [errorString]: human-readable error description.
typedef RenderProcessTerminatedCallback = void Function(
    WebViewController controller, int status, int errorCode, String errorString);

/// Called when a console message is emitted from the page.
///
/// [level]: log severity (from CEF include/internal/cef_types.h):
///   0 = default logging (currently info), 1 = verbose/debug,
///   2 = info, 3 = warning, 4 = error, 5 = fatal,
///   99 = disable logging.
/// [message]: the console message text.
/// [source]: the source URL or identifier.
/// [line]: the line number in the source.
typedef PageConsoleCallback = void Function(
    int level, String message, String source, int line);

/// Callback for [WebView] events.
class WebViewEventsListener {
  const WebViewEventsListener({
    this.onConsoleMessage,
    this.onNavigateRequest,
    this.onPageStarted,
    this.onPageFinished,
    this.onProgressUpdated,
    this.onPageFailed,
    this.onRenderProcessTerminated,
  });

  /// Console message from the web page.
  final PageConsoleCallback? onConsoleMessage;

  /// Intercept a navigation before it starts.
  final PageNavigationDelegate? onNavigateRequest;

  /// A page has started loading.
  final PageStartedCallback? onPageStarted;

  /// A page has finished loading.
  final PageFinishedCallback? onPageFinished;

  /// Page load progress (0.0 – 1.0).
  final PageProgressCallback? onProgressUpdated;

  /// A page load failed.
  final PageErrorCallback? onPageFailed;

  /// The CEF render process terminated unexpectedly (crash, OOM, killed).
  /// Reload the page to restore it — CEF created a new render process.
  final RenderProcessTerminatedCallback? onRenderProcessTerminated;
}
