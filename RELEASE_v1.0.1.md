# Release 1.0.1

**zgate-tunnel-sdk-c-builder** 首個正式版本，提供從 [openziti/ziti-tunnel-sdk-c](https://github.com/openziti/ziti-tunnel-sdk-c) 自動取得原始碼、套用 ziti→zgate 品牌與程式調整、並產出 **zgate-tunnel-sdk-c** 多平台建置的完整流程。

---

## 主要功能

- **一鍵建置**：執行 `./build.sh` 即可完成環境檢查、取得最新 tunnel SDK、整合 zgate-sdk-c、套用 patch、多平台編譯與清理。
- **多平台支援**：預設編譯 Linux x64、arm64、arm、mipsel（可透過 `TUNNEL_PRESETS` 自訂）。
- **與 zgate-sdk-c-builder 整合**：自動偵測並使用 [zgate-sdk-c-builder](https://github.com/Jameshclai/zgate-sdk-c-builder) 產出的 **zgate-sdk-c-xx.xx.xx**，同版本優先。
- **可設定選項**：`config.env` 支援 vcpkg 路徑、工作目錄、產出目錄、固定 tunnel/sdk 版本、跳過環境檢查等。

## 目錄與腳本

| 項目 | 說明 |
|------|------|
| `scripts/fetch-latest.sh` | 取得最新 ziti-tunnel-sdk-c 與版本變數 |
| `scripts/ensure-zgate-sdk.sh` | 確保 zgate-sdk-c 已存在（來自 zgate-sdk-c-builder output） |
| `scripts/apply-patch.sh` | 複製並套用 ziti→zgate 重新命名與內容替換 |
| `scripts/build-all-platforms.sh` | 依 CMake presets 進行多平台編譯 |
| `scripts/cleanup-output.sh` | 清理產出目錄 |

## 需求

- Bash、Git、CMake、Ninja、vcpkg、C/C++ 編譯器。
- 需先於 **zgate-sdk-c-builder** 執行 `build.sh` 產出對應版本的 zgate-sdk-c。

## 版權

- **Copyright (c) eCloudseal Inc.  All rights reserved.**
- **作者：Lai Hou Chang (James Lai)** — 詳見 [COPYRIGHT](COPYRIGHT)。

---

**完整使用說明請見 [README](README.md)。**
