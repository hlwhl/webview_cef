# CEF Prebuilt Tarballs

此目录用于放置 CEF 官方预编译包，加速 `pod install` 中的下载过程。

## 为什么需要？

`pod install` 时会执行 `download_cef.sh`，默认需要从 Spotify CDN 下载两个架构的 CEF 包（共约 560MB）。国内网络环境下 CDN 下载速度可能很慢（数十分钟），将 tarball 预先放置到此目录后，脚本会自动跳过下载，直接使用本地文件，整个过程只需数秒。

## 如何获取？

### 方式一：执行下载脚本（推荐）

```bash
bash cef_tar/download_cef_tars.sh
```

脚本会自动读取 `third/download.cmake` 中的版本号，下载对应版本的 arm64 和 x86_64 两个 tarball。已存在的文件会自动跳过。

### 方式二：手动下载

从 Spotify CDN 下载当前版本：

```bash
# arm64（Apple Silicon）
curl -L -o cef_tar/cef_binary_149.0.4+g2f1bfd8+chromium-149.0.7827.156_macosarm64.tar.bz2 \
  "https://cef-builds.spotifycdn.com/cef_binary_149.0.4%2Bg2f1bfd8%2Bchromium-149.0.7827.156_macosarm64.tar.bz2"

# x86_64（Intel）
curl -L -o cef_tar/cef_binary_149.0.4+g2f1bfd8+chromium-149.0.7827.156_macosx64.tar.bz2 \
  "https://cef-builds.spotifycdn.com/cef_binary_149.0.4%2Bg2f1bfd8%2Bchromium-149.0.7827.156_macosx64.tar.bz2"
```

也可以在浏览器中直接打开上述 URL 下载，然后手动移动到 `cef_tar/` 目录下。

> **注意**：如果 CEF 版本升级（`third/download.cmake` 中的 `CEF_VERSION` 发生变化），需要下载对应新版本的 tarball，旧版本不会被使用。

## 放置后效果

下次执行 `pod install` 时，日志会显示：

```
==> Using local cef_binary_..._macosarm64.tar.bz2 (arm64) from cef_tar/
```

而非：

```
==> Downloading cef_binary_..._macosarm64.tar.bz2 (arm64)
```

## 文件不会被提交到 Git

此目录下的 `*.tar.bz2` 已通过 `.gitignore` 排除，不会被提交到版本管理。
