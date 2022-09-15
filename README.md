# webview_cef
Flutter Desktop webview backed by CEF (Chromium Embedded Framework). *Still working in progress

# requirements
- Windows 7+
- macOS 10.12+

# How To Use
## Windows
Inside your application folder, you need to add two lines in your ```windows\runner\main.cpp```.（Because of Chromium multi process arch.）
```
#include "webview_cef/webview_cef_plugin_c_api.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  //start cef deamon processes. MUST CALL FIRST
  initCEFProcesses();
```
When first time building the project, a prebuilt cef bin package (200MB, link in release) will be downloaded automatically, hence you may wait for a longer time if you are building the project for the first time.

## macOS
1.Download prebuilt cef bundles from [arm64](https://github.com/hlwhl/webview_cef/releases/download/prebuilt_cef_bin_mac/CEFbins-mac103.0.12-arm64.zip) or [intel](https://github.com/hlwhl/webview_cef/releases/download/prebuilt_cef_bin_mac_intel/mac103.0.12-Intel.zip) depends on your target machine arch.

2.Unzip the archieve and put all files into macos/third/cef.

3.Run the example app.

[HELP WANTED!] Finding a more elegant way to distribute the prebuilt package.

Notice: currently the project haven't enable multi process mode because of debug convenience. You may want enable multi process mode by changing the implementation and built your own helper bundle. (Finding a more elegant way in the future)

# todos
- [x] macos support(partial, in progress..)
- [ ] multi instance support
- [ ] keyboard support
- [x] mouse events support
- [ ] js bridge support
- [x] release to pub
- [x] trackpad support (flutter 3.3)
- [ ] better macos binary distribution
- [ ] easier way to integrate macos helper bundles(multi process)

# demo
### Windows
![demo_compressed](https://user-images.githubusercontent.com/7610615/190432410-c53ef1c4-33c2-461b-af29-b0ecab983579.gif)
![image](https://user-images.githubusercontent.com/7610615/190431027-6824fac1-015d-4091-b034-dd58f79adbcb.png)
![image](https://user-images.githubusercontent.com/7610615/190431037-62ba0ea7-f7d1-4fca-8ce1-596a0a508f93.png)

### macOS
![image](https://user-images.githubusercontent.com/7610615/189533516-e5ab7dfa-4d53-4de9-b8c2-507eb5fa9196.png)
![image](https://user-images.githubusercontent.com/7610615/189533300-9fd87737-00f3-4e56-8750-ff276fc315b3.png)


# thanks
This project inspired by https://github.com/jnschulze/flutter-webview-windows
