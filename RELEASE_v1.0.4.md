# Release 1.0.4

**zgate-tunnel-sdk-c-builder** 1.0.4：SUDO_PASS 保留、建置流程說明。

---

## 變更摘要（相對於 1.0.3）

- **build.sh**：保留呼叫端傳入的 `SUDO_PASS`（例如 Telegram Bot 或自動建置腳本詢問的密碼），不被 config.env 覆寫。
- **setup-build-env.sh**：非互動安裝說明與行為一致。
- **README**：建置與版本說明更新。

## 主要功能（延續）

- **一鍵建置**：執行 `./build.sh` 完成環境檢查、取得最新 tunnel SDK、整合 zgate-sdk-c、套用 patch、多平台編譯與清理。
- **預設產出**：Linux x64、Windows x64（MinGW），含 wintun.dll 路徑等修正。

---

**完整使用說明請見 [README](README.md)。**
