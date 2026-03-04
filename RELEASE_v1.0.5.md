# Release 1.0.5

**zgate-tunnel-sdk-c-builder** 1.0.5：macOS 交叉編譯完成、build.sh 控制指令、複製至 latest_version、fetch 容錯。

---

## 變更摘要（相對於 1.0.4）

### 建置與工具鏈

- **macOS 交叉編譯**：修正 osxcross 建置流程，使 **ci-macOS-x64**、**ci-macOS-arm64** 可成功產出 `zgate-edge-tunnel`。
  - **apply-patch.sh**：工具鏈 `CMAKE_C_FLAGS` / `CMAKE_CXX_FLAGS` 改為 CMake 變數展開（`${OSXCROSS_SDK}`），避免傳入 autotools 時為字面量；新增 **CMAKE_AR**、**CMAKE_RANLIB** 指向 osxcross 的 `ar` / `ranlib`，產出正確格式之靜態庫。
  - **build-all-platforms.sh**：macOS 建置時匯出 **AR**、**RANLIB** 環境變數，供 vcpkg 以 Meson 建置 stc 時使用 target archiver，解決 `libstc.a` malformed 導致連結失敗之問題；維持 overlay triplets、keychain.c Security 標頭 patch 等。
- **fetch-latest.sh**：GitHub API 失敗（如 502）時，改以既有 **work/** 目錄內之 `ziti-tunnel-sdk-c-*` 版本繼續建置，不因網路錯誤中斷。

### 建置流程與產出

- **build.sh 控制指令**：新增指令列參數，可指定建置範圍（會覆寫 `TUNNEL_PRESETS`）：
  - **`-all`**：全部平台（Linux x64/arm64/arm、macOS x64/arm64、Windows x64）
  - **`-linux`**：僅 Linux（ci-linux-x64、ci-linux-arm64、ci-linux-arm）
  - **`-windows`**：僅 Windows（ci-windows-x64-mingw）
  - **`-macos`**：僅 macOS（ci-macOS-x64、ci-macOS-arm64，需 osxcross）
  - **`-h` / `--help`**：顯示用法說明
- **複製至 latest_version**：建置完成後自動將成功編譯之二進位複製至 **`latest_version/<版本號>/`**，目錄結構與 auto_zgate_edge_tunnel_build_bot 一致（`linux/x64`、`linux/arm64`、`linux/arm`、`windows/`、`macos/x64`、`macos/arm64`）；新增 **scripts/copy-to-latest-version.sh**，`.gitignore` 加入 `latest_version/`。

### 文件

- **README**：新增「build.sh 控制指令」表格、「複製至 latest_version」一節，說明各參數與產出目錄結構。

## 主要功能（延續）

- **一鍵建置**：執行 `./build.sh`（可選 `-all`、`-linux`、`-windows`、`-macos`）完成環境檢查、取得 tunnel SDK、整合 zgate-sdk-c、patch、多平台編譯、清理與複製至 latest_version。
- **多平台產出**：Linux x64/arm64/arm、macOS x64/arm64、Windows x64（MinGW），含 wintun.dll；成功產出自動彙整至 `latest_version/<版號>/`。

---

**完整使用說明請見 [README](README.md)。**
