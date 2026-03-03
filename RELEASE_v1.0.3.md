# Release 1.0.3

**zgate-tunnel-sdk-c-builder** 1.0.3：一鍵編譯 Linux 與 Windows（MinGW 交叉編譯）、非互動建置（SUDO_PASS）、版控與密碼安全說明。

---

## 變更摘要（相對於 1.0.2）

- **一鍵編譯 Linux + Windows**：預設或可設定 `TUNNEL_PRESETS=ci-linux-x64;ci-windows-x64-mingw`，於 Linux 主機一次產出 Linux x64 與 Windows x64（MinGW）二進位。
- **非互動建置**：於 `config.env` 設定 `SUDO_PASS` 後執行 `./build.sh`，腳本以 `sudo -S` 自動輸入密碼，無需手動輸入。**切記：密碼切勿記錄於任何可提交的檔案或文件中**；`config.env` 已列入 `.gitignore`。
- **MinGW 交叉編譯修正**：`apply-patch.sh` 與 `build-all-platforms.sh` 修正 lwip BYTE_ORDER、wintun.dll 路徑（amd64）、MinGW 視為 Windows 之條件、dnsapi/resolv、RPATH 等，確保 Windows 建置成功。
- **zgate-sdk-c 依賴**：同版本 zgate-sdk-c 缺失時改為使用 output 下最新版本；建置前可對 zgate-sdk-c 執行 apply-patch 刷新（tlsuv/log 等）。
- **版控與安全說明**：README 新增「本次修訂與版控說明」、忽略檔案列表、提交建議；各處強調密碼與 token **切勿記錄**於可提交的檔案或文件中。

## 主要功能（延續並強化）

- **一鍵建置**：執行 `./build.sh` 完成環境檢查（可選 SUDO_PASS 非互動）、取得最新 tunnel SDK、整合 zgate-sdk-c、套用 patch、多平台編譯與清理。
- **多平台支援**：可編譯 **Linux x64**、**Windows x64 MinGW**，以及選配之 Linux arm64/arm、macOS、Windows arm64 等（依 `TUNNEL_PRESETS`）。
- **與 zgate-sdk-c-builder 整合**：自動偵測並使用 zgate-sdk-c-builder 產出的 **zgate-sdk-c-xx.xx.xx**，同版本優先，否則使用最新版並可刷新 patch。
- **可設定選項**：`config.env` 支援 SUDO_PASS、VCPKG_ROOT、TUNNEL_PRESETS、跳過交叉工具鏈等；範本為 `config.env.example`，實際 `config.env` 不納入版控。

## 需求

- Bash、Git、CMake、Ninja、vcpkg、C/C++ 編譯器；Windows 交叉編譯需 MinGW（腳本可協助安裝）。
- 需先於 **zgate-sdk-c-builder** 執行 `build.sh` 產出 zgate-sdk-c，本專案會使用該 output 目錄。

## 版權

- **Copyright (c) eCloudseal Inc.  All rights reserved.**
- **作者：Lai Hou Chang (James Lai)** — 詳見 [COPYRIGHT](COPYRIGHT)。

---

**完整使用說明請見 [README](README.md)。**
