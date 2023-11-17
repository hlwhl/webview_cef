#include "my_application.h"
#include <webview_cef/webview_cef_plugin.h>

int main(int argc, char** argv) {
  initCEFProcesses(argc, argv);
  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
