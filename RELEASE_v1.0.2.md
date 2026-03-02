# Release 1.0.2

**zgate-tunnel-sdk-c-builder** 1.0.2：新增 vcpkg 自動下載與編譯、預裝 zip 套件，一鍵建置更完整。

---

## 變更摘要（相對於 1.0.1）

- **vcpkg 自動設置**：若未安裝 vcpkg，執行 `./build.sh` 時會提示是否自動 clone 並 bootstrap vcpkg 至 `VCPKG_ROOT`（預設 `$HOME/vcpkg`），無需手動安裝。
- **build.sh 整合**：建置流程會自動 source `.build-env.vcpkg`，使剛安裝的 vcpkg 路徑在後續步驟中生效。
- **預裝 zip**：環境檢查與 apt 安裝清單加入 `zip`，確保建置與打包所需指令存在。

## 主要功能（同 1.0.1，並強化）

- **一鍵建置**：執行 `./build.sh` 完成環境檢查、vcpkg（可自動安裝）、取得最新 tunnel SDK、整合 zgate-sdk-c、套用 patch、多平台編譯與清理。
- **多平台支援**：預設編譯 Linux x64、arm64、arm、mipsel 等（可透過 `TUNNEL_PRESETS` 自訂）。
- **與 zgate-sdk-c-builder 整合**：自動偵測並使用 zgate-sdk-c-builder 產出的 **zgate-sdk-c-xx.xx.xx**。
- **可設定選項**：`config.env` 支援 VCPKG_ROOT、工作目錄、產出目錄、固定版本、跳過環境檢查等。

## 需求

- Bash、Git、CMake、Ninja、C/C++ 編譯器；**vcpkg** 可於首次執行時依提示自動安裝。
- 建議先於 **zgate-sdk-c-builder** 執行 `build.sh` 產出對應版本的 zgate-sdk-c。

## 版權

- **Copyright (c) eCloudseal Inc.  All rights reserved.**
- **作者：Lai Hou Chang (James Lai)** — 詳見 [COPYRIGHT](COPYRIGHT)。

---

**完整使用說明請見 [README](README.md)。**
