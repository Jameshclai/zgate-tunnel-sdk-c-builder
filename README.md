# zgate-tunnel-sdk-c-builder

自動從 [openziti/ziti-tunnel-sdk-c](https://github.com/openziti/ziti-tunnel-sdk-c) 取得最新版本、套用 ziti→zgate patch、並編譯產出 **zgate-tunnel-sdk-c-xx.xx.xx**（含多平台二進位）。編譯時會依需要呼叫或使用 [zgate-sdk-c-builder](https://github.com/ecloudseal/zgate-sdk-c-builder) 產出的同版本 **zgate-sdk-c-xx.xx.xx**。

**Copyright (c) eCloudseal Inc.  All rights reserved.**  
**Author: Lai Hou Chang (James Lai)** — 詳見 [COPYRIGHT](COPYRIGHT)。

## 需求

- 與 zgate-sdk-c-builder 相同：Bash、Git、CMake、Ninja、vcpkg、C/C++ 編譯器。
- 需先備妥或由本專案觸發產生 **zgate-sdk-c-xx.xx.xx**（與 tunnel 版本號一致）。

## 使用方式

### 一鍵執行

```bash
./build.sh
```

會依序：檢查環境 → 取得最新 ziti-tunnel-sdk-c → 確保 zgate-sdk-c-<ver> 存在（必要時執行 zgate-sdk-c-builder）→ patch → 多平台編譯 → 清理。

### 設定

可複製 `config.env.example` 為 `config.env` 並調整：

| 變數 | 說明 | 預設 |
|------|------|------|
| `VCPKG_ROOT` | vcpkg 根目錄 | `/home/user/vcpkg` |
| `WORK_DIR` | 下載暫存目錄 | `./work` |
| `OUTPUT_DIR` | 產出目錄的父目錄 | `./output` |
| `ZGATE_SDK_BUILDER_OUTPUT` | zgate-sdk-c-builder 的 output | `/home/user/zgate-sdk-c-builder/output` |
| `ZGATE_SDK_BUILDER_ROOT` | zgate-sdk-c-builder 專案路徑 | `/home/user/zgate-sdk-c-builder` |
| `ZITI_TUNNEL_SDK_TAG` | 固定 tunnel 版本（如 v1.10.10） | 不設則用最新 release |
| `TUNNEL_PRESETS` | 要編譯的 CMake presets（分號分隔） | `ci-linux-x64;ci-linux-arm64` |
| `SKIP_ENV_CHECK` | 設為 1 略過環境檢查 | 不設則執行檢查 |

## 目錄結構

```
zgate-tunnel-sdk-c-builder/
├── .git/
├── .gitignore
├── COPYRIGHT
├── README.md
├── config.env.example
├── build.sh
├── scripts/
│   ├── setup-build-env.sh
│   ├── fetch-latest.sh
│   ├── ensure-zgate-sdk.sh
│   ├── apply-patch.sh
│   ├── build-all-platforms.sh
│   └── cleanup-output.sh
└── output/                  # 產出 zgate-tunnel-sdk-c-xx.xx.xx
```

## 版權聲明

- **Copyright (c) eCloudseal Inc.  All rights reserved.**
- **作者 (Author): Lai Hou Chang (James Lai)**
- 完整版權與法律聲明請見 [COPYRIGHT](COPYRIGHT).
