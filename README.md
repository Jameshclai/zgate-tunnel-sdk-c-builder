# zgate-tunnel-sdk-c-builder

自動從 [openziti/ziti-tunnel-sdk-c](https://github.com/openziti/ziti-tunnel-sdk-c) 取得最新版本、套用 ziti→zgate patch、並編譯產出 **zgate-tunnel-sdk-c-xx.xx.xx**（含多平台二進位）。編譯時**參考使用** [zgate-sdk-c-builder](/home/user/zgate-sdk-c-builder) 的產出目錄 **zgate-sdk-c-xx.xx.xx**（需先於該專案執行 `build.sh`）。

**Copyright (c) eCloudseal Inc.  All rights reserved.**  
**Author: Lai Hou Chang (James Lai)** — 詳見 [COPYRIGHT](COPYRIGHT)。

## 需求

- 與 zgate-sdk-c-builder 相同：Bash、Git、CMake、Ninja、vcpkg、C/C++ 編譯器。
- 需先於 **zgate-sdk-c-builder** 執行 `build.sh` 產出 **zgate-sdk-c-xx.xx.xx**，本專案會使用該目錄（同版本優先，否則使用該 output 下最新版本）。

## 使用方式

### 一鍵執行

```bash
./build.sh
```

會依序：**建置編譯環境**（若需安裝套件會先詢問 sudo，一次安裝基本工具與交叉編譯工具鏈）→ 取得最新 ziti-tunnel-sdk-c → 使用 zgate-sdk-c-builder 產出的 zgate-sdk-c → patch → 多平台編譯 → 清理。

### 設定

可複製 `config.env.example` 為 `config.env` 並調整：

| 變數 | 說明 | 預設 |
|------|------|------|
| `VCPKG_ROOT` | vcpkg 根目錄 | `/home/user/vcpkg` |
| `WORK_DIR` | 下載暫存目錄 | `./work` |
| `OUTPUT_DIR` | 產出目錄的父目錄 | `./output` |
| `ZGATE_SDK_BUILDER_OUTPUT` | zgate-sdk-c 來源（zgate-sdk-c-builder 的 output） | `/home/user/zgate-sdk-c-builder/output` |
| `ZITI_TUNNEL_SDK_TAG` | 固定 tunnel 版本（如 v1.10.10） | 不設則用最新 release |
| `TUNNEL_PRESETS` | 要編譯的 CMake presets（分號分隔） | 7 平台（Darwin/Linux/Windows）；Windows x86_64 使用 MinGW 以支援 Linux 主機交叉編譯 |
| `SKIP_CROSS_TOOLCHAINS` | 設為 1 略過 Darwin/Windows 工具鏈安裝 | 不設則會自動安裝 MinGW、osxcross 等 |
| `SKIP_ENV_CHECK` | 設為 1 略過環境檢查 | 不設則執行檢查 |

## Git 版控與釋出

本專案使用 Git 版控，建議分支策略與釋出流程如下。

### 日常開發

- 主分支：`master`
- 修改後提交：`git add .` → `git commit -m "說明"` → `git push origin master`

### 釋出版本（Release）

1. 確認所有變更已提交、建置通過。
2. 打標籤（與釋出版本號一致，例如 1.0.2）：
   ```bash
   git tag -a v1.0.2 -m "Release 1.0.2"
   ```
3. 推送到 GitHub（含標籤）：
   ```bash
   git push origin master
   git push origin v1.0.2
   ```
   或使用本專案提供的**一鍵推送腳本**（會推送目前分支與所有標籤）：
   ```bash
   ./scripts/push-to-github.sh
   ```
   若使用 Personal Access Token 驗證，請勿將 token 寫入任何檔案或提交；可於推送時依提示輸入，或使用 Git 憑證儲存。

4. 在 GitHub 專案頁面 **Releases** 中可依標籤建立 Release 並撰寫釋出說明。

### 自動推送到 GitHub

- **手動一鍵推送**：執行 `./scripts/push-to-github.sh` 會推送目前分支與所有標籤到 `origin`。
- **建置完成後自動推送**：在 `config.env` 中設定：
  - `AUTO_PUSH=1`：建置流程結束後自動執行推送。
  - `GITHUB_TOKEN=你的 token`：非互動環境下使用（例如 CI），腳本會用此 token 推送，**請勿將 config.env 提交至版控**。
- 若未設定 `GITHUB_TOKEN`，自動推送會使用目前 Git 設定的遠端與憑證（需已設定 credential helper 或 SSH）。

### 忽略的檔案（見 .gitignore）

- `work/`、`output/`、`build*/`：建置與產出目錄
- `.build-env.vcpkg`、`.build-env.cross`：執行期產生的環境變數檔
- `.cross-toolchains/`：交叉編譯工具鏈安裝目錄
- `config.env`：本機設定（請勿提交含密碼或 token 的設定）

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
│   ├── setup-cross-toolchains.sh
│   ├── push-to-github.sh
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
