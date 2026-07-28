# macOS Universal 构建

> 让 `flutter build macos` 产出同时包含 arm64 和 x86_64 两种架构的 Universal App。

## 背景与问题

### 现状

CEF 官方为 macOS 发布的二进制是按架构分开的——`macosarm64` 和 `macosx64` 各一个包，没有"双架构合体"版本。当前 `download_cef.sh` 只下载宿主架构的 CEF 包，`podspec` 通过 `EXCLUDED_ARCHS` 告诉 Xcode 排除非宿主架构，因此产出的 App 只能在和编译机器同架构的 Mac 上运行。

### 目标

无论在哪台 Mac 上构建，`flutter build macos --release` 都能产出 arm64 + x86_64 的 Universal App：

```bash
$ lipo -info Runner.app/Contents/MacOS/Runner
Architectures in the fat file: Runner are: arm64 x86_64
```

### 核心思路

同时下载 arm64 和 x86_64 两个 CEF 包 → 各自构建 → 用 `lipo -create` 合并成 fat binary → 去掉 `EXCLUDED_ARCHS`，让 Xcode 正常产出 Universal App。

---

## 需要合并哪些二进制

CEF 发行版中需要合并的二进制文件共 **7 个**：

| # | 文件 | 来源 | 合并方式 |
|---|------|------|----------|
| 1 | `Chromium Embedded Framework`（主 dylib） | CEF 官方包 | `lipo` |
| 2 | `libEGL.dylib` | CEF 官方包 | `lipo` |
| 3 | `libGLESv2.dylib` | CEF 官方包 | `lipo` |
| 4 | `libvk_swiftshader.dylib` | CEF 官方包 | `lipo` |
| 5 | `libcef_sandbox.dylib` | CEF 官方包 | `lipo` |
| 6 | `libcef_dll_wrapper.a` | 自己 cmake 编译 | `lipo` |
| 7 | `cef_helper` | 自己 clang++ 编译 | `lipo` |

> Framework 内的 dylib 不硬编码文件名，而是用 `find` + `file` 扫描所有 Mach-O 文件后逐一合并，CEF 版本升级时自动适应。

---

## 最优方案：始终 Universal + 逃生口回退

### 设计原则

- **默认行为**：始终产出 Universal 二进制，不需要开关
- **回退机制**：仅当显式设置 `CEF_UNIVERSAL=0` 时退回单架构（用于网络/磁盘紧张的紧急场景）
- **核心目标**：本地开发、CI、所有 Mac 上跑完全一致的逻辑，消除代码分支

### 方案选择理由

| | 按需切换方案 | 始终 Universal 方案 | 最优方案（本方案） |
|---|---|---|---|
| 默认行为 | 单架构 | 双架构 | **双架构** |
| 代码分支 | 多（脚本和 podspec 到处 if/else） | 无 | **极少（仅回退路径）** |
| 本地 / CI 一致性 | ❌ 不一致 | ✅ 一致 | ✅ 一致 |
| 日常 pod install 速度 | 快 | 首次慢，有缓存后秒级 | **本地 tarball 加速后接近单架构** |
| 灵活性 | 高 | 低 | **中等（保留逃生口）** |
| 维护成本 | 高（多路径测试矩阵） | 低 | **低** |

---

## 具体实现

### 改哪些文件

| 文件 | 改动内容 | 复杂度 |
|------|---------|--------|
| `macos/scripts/download_cef.sh` | 下载双架构 → 各自构建 → lipo 合并 | ⭐⭐⭐ |
| `macos/webview_cef.podspec` | 删除 `EXCLUDED_ARCHS`，只保留回退路径下的排除逻辑 | ⭐⭐ |
| `.github/workflows/test_macos.yaml` | 删除手动下载 CEF 的步骤 | ⭐ |

不动的东西：
- `embed_cef_helpers.sh` — 只是复制文件，文件已是 fat 的，无感
- `third/download.cmake` — macOS 不走这个路径
- `Runner.xcodeproj` — Debug 的 `ONLY_ACTIVE_ARCH = YES` 保留，本地调试仍只编宿主架构

---

### 一、`download_cef.sh` 改造

#### 1.1 架构检测：默认双架构 + 回退

```bash
# 默认：始终下载两个架构
# 回退：CEF_UNIVERSAL=0 时只下载宿主架构
if [ "${CEF_UNIVERSAL:-}" = "0" ]; then
  case "$(uname -m)" in
    arm64)  ARCHES=("arm64") ;;
    x86_64) ARCHES=("x86_64") ;;
    *)      err "不支持的架构: $(uname -m)" ;;
  esac
else
  ARCHES=("arm64" "x86_64")
fi
```

> `CEF_UNIVERSAL=0` 不是日常切换选项，而是一个**逃生口**——仅在网络极差或磁盘紧张时使用。回退路径的 stamp 格式不同（单架构标识），下次不带 `CEF_UNIVERSAL=0` 跑时会自动检测到不匹配，触发重新构建 Universal。

#### 1.2 抽成函数

核心逻辑抽成 `download_and_build()` 函数，对每个架构调用一次。helper 在函数内部构建——arm64 的 helper 必须链接 arm64 的 wrapper，x86_64 的 helper 必须链接 x86_64 的 wrapper。原则是：各编各的，最后再合。

#### 1.3 本地 tarball 加速

```bash
# 如果 cef_tar/ 目录下有对应架构的包，直接使用，跳过 CDN 下载
local_tar="${REPO_ROOT}/cef_tar/${pkg}.tar.bz2"
if [ -f "${local_tar}" ]; then
  cp "${local_tar}" "${tarball}"
else
  # 正常 CDN 下载 + 重试逻辑
fi
```

#### 1.4 lipo 合并

- **libcef_dll_wrapper.a**：直接 `lipo -create`
- **CEF Framework**：以 arm64 为基底复制框架结构，然后 `find` + `file` 扫描所有 Mach-O 文件逐一 lipo
- **cef_helper**：`lipo -create` 两个单架构版本

#### 1.5 关键细节

- **Stamp 格式**：`{version}_arm64,x86_64_{build_type}_{source_hash}`（双架构）/ 保持旧格式（回退）
- **is_fat 校验**：缓存命中时不仅检查 stamp，还验证关键文件确实是 fat binary，防止"半成品"缓存
- **原子化写入 stamp**：`.tmp → mv` 方式
- **临时目录**：固定命名 `_build_arm64` / `_build_x86_64`，退出时 `trap cleanup EXIT` 自动清理
- **bash 3.2 兼容**：使用 `cef_arch_for()` 函数代替 `declare -A` 关联数组

---

### 二、`webview_cef.podspec` 改造

**默认路径（Universal）**：删除 `EXCLUDED_ARCHS`。

**回退路径**：仅当 `ENV['CEF_UNIVERSAL'] == '0'` 时恢复 `EXCLUDED_ARCHS`。

```ruby
universal_disabled = ENV['CEF_UNIVERSAL'] == '0'

if universal_disabled
  # 恢复 EXCLUDED_ARCHS 排除非宿主架构
else
  # 不设 EXCLUDED_ARCHS，Xcode 正常编译 Universal
end
```

---

### 三、CI Workflow 改造

删除手动下载 CEF 的 step。`pod install` 已包含完整的下载 + 构建 + lipo 逻辑。CI 流程简化为：checkout → flutter setup → brew install → flutter analyze → flutter build macos。

---

## 验证清单

### 首次构建验证

```bash
# 1. 清缓存
rm -rf macos/third/cef

# 2. 跑 pod install
cd example/macos && pod install

# 3. 检查 stamp
cat macos/third/cef/version.txt
# 期望包含 "arm64,x86_64"

# 4. 检查 fat binary
lipo -info macos/third/cef/libcef_dll_wrapper.a
lipo -info macos/third/cef/cef_helper
lipo -info "macos/third/cef/Chromium Embedded Framework.framework/Versions/A/Chromium Embedded Framework"
# 每个都应显示: arm64 x86_64

# 5. Debug 构建（ONLY_ACTIVE_ARCH = YES，只编宿主架构）
flutter build macos --debug

# 6. Release 构建（完整双架构）
flutter build macos --release

# 7. 验证 App
lipo -info build/macos/Build/Products/Release/Runner.app/Contents/MacOS/Runner
# → arm64 x86_64
```

### 缓存验证

```bash
cd example/macos && pod install
# 期望：秒级完成，输出 "already prepared — nothing to do"
```

### 回退路径验证

```bash
rm -rf macos/third/cef
CEF_UNIVERSAL=0 pod install
# 产出单架构文件
# 下次不带 CEF_UNIVERSAL=0 跑时自动重建 Universal
```

---

## 注意事项

- **磁盘空间**：临时目录峰值约 2GB，构建完成后自动清理
- **首次构建时间**：使用本地 tarball（`cef_tar/`）时，跳过 CDN 下载，接近原单架构时间
- **被中断的 pod install**：`trap cleanup EXIT` 自动清理临时目录，下次重新开始
- **CEF 版本升级**：`find` + `file` 扫描机制自动适应 framework 内部结构变化
- **Intel Mac 兼容**：脚本不再依赖 `uname -m` 决定下载哪个架构，Intel Mac 上 Debug 构建时链接器只取 x86_64 的 slice
