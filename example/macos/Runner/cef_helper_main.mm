// Entry point for the CEF helper (sub-)processes on macOS.
//
// CEF is multi-process: the renderer / GPU / plugin / utility processes run as
// separate executables. On macOS the main app bundle cannot serve as the
// sub-process (its main() boots Flutter), so each sub-process is launched from
// a dedicated "<App> Helper*.app" whose main() does nothing but hand control to
// CEF. This file is that main().
//
// It reuses the shared common/ sources (the same unity the plugin compiles via
// macos/Classes/cef_bridge.cc) so the renderer process gets WebviewApp's
// CefRenderProcessHandler — i.e. the JavaScript bridge and process-message
// handling work across processes. Passing nullptr (as the stock CEF template
// does) would silently break the JS bridge in the renderer.
#import "include/cef_app.h"
#import "include/wrapper/cef_library_loader.h"
#import "webview_app.h"

// Reuse the shared C++ sources (mirrors macos/Classes/cef_bridge.cc).
#include "webview_app.cc"
#include "webview_handler.cc"
#include "webview_cookieVisitor.cc"
#include "webview_js_handler.cc"
#include "webview_plugin.cc"
#include "webview_value.cc"

int main(int argc, char* argv[]) {
  // Load the CEF framework from the app bundle for a helper process.
  CefScopedLibraryLoader library_loader;
  if (!library_loader.LoadInHelper()) {
    return 1;
  }

  CefMainArgs main_args(argc, argv);
  // WebviewApp provides the render-process handler (JS bridge); reuse it here
  // so message routing between browser and renderer keeps working.
  CefRefPtr<WebviewApp> app(new WebviewApp());
  return CefExecuteProcess(main_args, app, nullptr);
}
