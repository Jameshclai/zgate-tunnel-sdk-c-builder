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

會依序：**建置編譯環境**（確認 git、cmake、ninja、gcc、vcpkg 等已安裝；若缺少會自動安裝，不詢問）→ 取得最新 ziti-tunnel-sdk-c → 使用 zgate-sdk-c-builder 產出的 zgate-sdk-c → patch → 多平台編譯 → 清理。

**一鍵建置不互動**：在 `config.env` 中設定 `SUDO_PASS` 後執行 `./build.sh`，腳本將以 `sudo -S` 自動輸入密碼，不會重複詢問。**切記：密碼切勿記錄於任何檔案、文件或版控中**；`config.env` 已列於 `.gitignore`，請勿提交。

### build.sh 控制指令

可傳入參數指定建置範圍（會覆寫 `config.env` 的 `TUNNEL_PRESETS`）：

| 參數 | 說明 |
|------|------|
| 無參數 | 使用 `config.env` 的 `TUNNEL_PRESETS`；未設定則為全部平台。 |
| `-all` | 編譯全部平台：Linux x64/arm64/arm、macOS x64/arm64、Windows x64。 |
| `-linux` | 僅編譯所有 Linux 平台：ci-linux-x64、ci-linux-arm64、ci-linux-arm。 |
| `-windows` | 僅編譯 Windows：ci-windows-x64-mingw。 |
| `-macos` | 僅編譯 macOS：ci-macOS-x64、ci-macOS-arm64（需 osxcross）。 |
| `-h`、`--help` | 顯示用法說明。 |

亦可使用環境變數 `TUNNEL_PRESETS`（例：`export TUNNEL_PRESETS="ci-linux-x64;ci-windows-x64-mingw"`）。

### 建置與版本規範

- **產出**：建置須成功產出至少 **Linux x64**（`ci-linux-x64`）與 **Windows x64 MinGW**（`ci-windows-x64-mingw`）二進位。

### 複製至 latest_version

建置完成後，`build.sh` 會自動將**成功編譯的二進位**複製到專案根目錄下的 **`latest_version/<版本號>/`**，目錄結構與 [auto_zgate_edge_tunnel_build_bot](https://github.com/Jameshclai/auto_zgate_edge_tunnel_build_bot) 一致，依平台分層：

- `latest_version/<版號>/linux/x64/`、`linux/arm64/`、`linux/arm/` — `zgate-edge-tunnel`
- `latest_version/<版號>/windows/` — `zgate-edge-tunnel.exe`、`wintun.dll`
- `latest_version/<版號>/macos/x64/`、`macos/arm64/` — `zgate-edge-tunnel`

僅**有成功產出的平台**會寫入對應子目錄；`latest_version/` 已列入 `.gitignore`，不會被提交至版控。

### 設定

可複製 `config.env.example` 為 `config.env` 並調整：

| 變數 | 說明 | 預設 |
|------|------|------|
| `SUDO_PASS` | 一鍵建置時提供給 sudo 用（不設則會互動詢問）；**切勿將密碼記錄於可提交的檔案或文件中** | 不設則會互動詢問 |
| `VCPKG_ROOT` | vcpkg 根目錄 | `/home/user/vcpkg` |
| `WORK_DIR` | 下載暫存目錄 | `./work` |
| `OUTPUT_DIR` | 產出目錄的父目錄 | `./output` |
| `ZGATE_SDK_BUILDER_OUTPUT` | zgate-sdk-c 來源（zgate-sdk-c-builder 的 output） | `/home/user/zgate-sdk-c-builder/output` |
| `ZITI_TUNNEL_SDK_TAG` | 固定 tunnel 版本（如 v1.10.10） | 不設則用最新 release |
| `TUNNEL_PRESETS` | 要編譯的 CMake presets（分號分隔） | 7 平台（Darwin/Linux/Windows）；Windows x86_64 使用 MinGW 以支援 Linux 主機交叉編譯 |
| `SKIP_CROSS_TOOLCHAINS` | 設為 1 略過 Darwin/Windows 工具鏈安裝 | 不設則會自動安裝 MinGW、osxcross 等 |
| `SKIP_WINDOWS_ARM64` | 設為 1 略過 Windows arm64 建置（僅建置其餘 6 平台） | 不設則會嘗試安裝/編譯 aarch64-w64-mingw32，失敗則自動略過 |
| `SKIP_ENV_CHECK` | 設為 1 略過環境檢查 | 不設則執行檢查 |

若測試機或環境無 **aarch64-w64-mingw32**（Windows arm64 交叉編譯），建置會**自動略過 ci-windows-arm64-mingw**，其餘 6 個平台照常編譯，不會整機失敗。  
**說明**：`gcc-aarch64-w64-mingw32` / `g++-aarch64-w64-mingw32` 目前**不在多數 Ubuntu/Debian 預設 apt 源**內（GCC 對 Windows ARM64 支援較新），若 `apt-get install` 出現「Unable to locate package」屬正常，腳本會略過該平台或嘗試從 [Windows-on-ARM-Experiments/mingw-woarm64-build](https://github.com/Windows-on-ARM-Experiments/mingw-woarm64-build) 編譯。

## Git 版控與釋出

本專案使用 Git 版控，建議分支策略與釋出流程如下。

### 本次修訂與版控說明

以下為目前工作區修訂的檔案與版控注意事項，提交前請確認：

| 檔案 | 修訂摘要 | 版控說明 |
|------|----------|----------|
| `.gitignore` | 新增 `config.env` 忽略規則 | 務必提交，確保密碼與 token 絕不納入版控、亦不記錄於文件中。 |
| `README.md` | 一鍵建置不互動說明、建置與版本規範、設定表 `SUDO_PASS`、忽略檔案說明、Git 釋出流程 | 文件變更，可一併提交。 |
| `config.env.example` | `SUDO_PASS` 註解與「切勿記錄密碼」提醒 | 範本檔，可提交；實際 `config.env` 由各端自行複製，密碼不記錄、不提交。 |
| `scripts/apply-patch.sh` | 版本字串單一化（SAVED_SIMPLE_GIT_VERSION）、lwip BYTE_ORDER/MinGW、wintun.dll 路徑、MinGW 視為 Windows 等 patch | 建置邏輯變更，提交時建議註明「patch：版本顯示、MinGW 交叉編譯與 wintun 路徑」。 |
| `scripts/build-all-platforms.sh` | MinGW 平台設定 `CMAKE_BUILD_WITH_INSTALL_RPATH=ON` 避免 RPATH 錯誤 | 建置腳本，可與 apply-patch 一併或分開提交。 |
| `scripts/ensure-zgate-sdk.sh` | 同版本缺失時改用 output 最新版、建置前對 zgate-sdk-c 執行 apply-patch 刷新 | 依賴與一鍵建置流程，建議提交。 |
| `scripts/setup-build-env.sh` | 支援 `SUDO_PASS` 非互動安裝（讀取 config.env；密碼切勿記錄於版控） | 與 .gitignore、README 一併提交，確保「一鍵建置不互動」說明與實作一致。 |

**提交建議**：可將上述變更分為 1～2 個 commit，例如「docs & config: 一鍵建置說明、config.env 忽略與 SUDO_PASS」與「build: MinGW 交叉編譯、版本顯示、zgate-sdk 依賴與 patch 修正」，或合併為單一 commit「build: 一鍵編譯 Linux/Windows、SUDO_PASS 非互動、MinGW 與版本修正」。

**勿提交且切勿記錄密碼**：`config.env`（已列於 .gitignore，請勿在內寫入或記錄密碼後提交）、`work/`、`output/`、`.cross-toolchains/` 等建置產物。

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
   若使用 Personal Access Token 驗證，**切勿將 token 記錄於任何檔案或提交**；可於推送時依提示輸入，或使用 Git 憑證儲存。

4. 在 GitHub 專案頁面 **Releases** 中可依標籤建立 Release 並撰寫釋出說明。

### 自動推送到 GitHub

- **手動一鍵推送**：執行 `./scripts/push-to-github.sh` 會推送目前分支與所有標籤到 `origin`；若目前分支為 `master`，會一併更新遠端 `main`，避免 GitHub 預設分支顯示舊程式。
- **建置完成後自動推送**：在 `config.env` 中設定：
  - `AUTO_PUSH=1`：建置流程結束後自動執行推送。
  - `GITHUB_TOKEN=你的 token`：非互動環境下使用（例如 CI），腳本會用此 token 推送；**切勿將 token 記錄於任何可提交的檔案或文件中**。
- 若未設定 `GITHUB_TOKEN`，自動推送會使用目前 Git 設定的遠端與憑證（需已設定 credential helper 或 SSH）。

### 忽略的檔案（見 .gitignore）

- `work/`、`output/`、`build*/`：建置與產出目錄
- `.build-env.vcpkg`、`.build-env.cross`：執行期產生的環境變數檔
- `.cross-toolchains/`：交叉編譯工具鏈安裝目錄
- `config.env`：本機設定（**密碼與 token 切勿記錄於此檔或任何可提交處**）

### 若 GitHub 顯示舊程式或 Releases 仍是 1.0.1

- **程式碼看起來是舊的**：GitHub 預設分支多為 `main`，若只推送到 `master`，首頁仍會顯示 `main` 的舊內容。請執行一次 `GITHUB_TOKEN=你的token ./scripts/push-to-github.sh`（腳本會同時更新 `master` 與 `main`），或手動執行：`git push origin master:refs/heads/main`。
- **Releases 頁面只看到 1.0.1**：Git 標籤與 GitHub「Releases」是分開的；標籤 `v1.0.2` 已存在，但**必須手動建立 Release** 才會出現在 [Releases 頁面](https://github.com/Jameshclai/zgate-tunnel-sdk-c-builder/releases)：
  1. 開啟 **Releases** → **Draft a new release**
  2. **Choose a tag** 選擇 **v1.0.2**（若無則先推送標籤）
  3. **Release title** 填寫例如：Release 1.0.2
  4. 填寫說明後點 **Publish release**
  - 或使用腳本（需 token 具 `repo` 權限）：`GITHUB_TOKEN=你的token ./scripts/create-github-release.sh v1.0.2 "Release 1.0.2"`

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
│   ├── create-github-release.sh
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
