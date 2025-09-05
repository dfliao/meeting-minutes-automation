# 會議紀錄自動化系統 - 安裝指南

## 系統架構
本系統包含三個主要組件：
1. **網頁上傳界面** - 使用者友好的檔案上傳界面
2. **N8N 自動化工作流程** - 處理音訊檔案和生成會議紀錄
3. **Whisper 轉錄服務** - 本地音訊轉錄服務（可選）

## 快速開始

### 步驟 1：準備環境

確保你的系統已安裝：
- Docker 和 Docker Compose
- Node.js 16+ (用於 N8N)
- 有效的 OpenAI API 金鑰

### 步驟 2：啟動 N8N

```bash
# 安裝 N8N
npm install -g n8n

# 啟動 N8N（將在 http://localhost:5678 運行）
n8n start
```

### 步驟 3：匯入工作流程

1. 開啟 N8N 管理界面：`http://localhost:5678`
2. 點擊左上角的選單 → Import
3. 選擇 `n8n-workflows/audio-transcription-workflow.json` 檔案
4. 匯入完成後，工作流程會出現在工作區

### 步驟 4：設定 OpenAI API 憑證

1. 在 N8N 中，點擊右上角的「Settings」
2. 選擇「Credentials」
3. 新增「OpenAI API」憑證
4. 輸入你的 OpenAI API Key
5. 儲存憑證並記住憑證 ID

### 步驟 5：更新工作流程設定

1. 在工作流程中，點擊「直接轉錄 (< 24MB)」節點
2. 在「Credentials」欄位選擇你剛建立的 OpenAI API 憑證
3. 對「轉錄音訊片段」節點重複相同操作
4. 對「OpenAI - 生成會議記錄」節點重複相同操作

### 步驟 6：啟用工作流程

1. 點擊工作流程右上角的開關按鈕
2. 確保顯示為「Active」狀態
3. 工作流程現在可以接收請求

### 步驟 7：使用網頁界面

1. 開啟 `web-interface/index.html` 檔案
2. 如果你的 N8N 不是運行在 `localhost:5678`，請更新「伺服器網址」欄位
3. 選擇音訊檔案並開始上傳

## 進階設定

### 使用本地 Whisper 服務（可選）

如果你想使用本地的 Whisper 服務而非 OpenAI API：

```bash
# 啟動 Whisper 服務
cd whisper-service
docker-compose up --build
```

然後修改工作流程，將 OpenAI API 調用替換為對 `http://localhost:10300/transcribe` 的 HTTP 請求。

### 自訂伺服器部署

如果你想在不同的伺服器上運行：

1. 修改 `whisper-service/docker-compose.yaml` 中的連接埠設定
2. 更新 `web-interface/index.html` 中的預設伺服器網址
3. 確保防火牆允許相關連接埠的連接

## 疑難排解

### 常見問題

**問題：404 錯誤 "webhook not registered"**
- 確認工作流程已匯入並啟用
- 檢查 webhook 路徑是否正確（應為 `/webhook/audio-transcription`）

**問題：OpenAI API 錯誤**
- 檢查 API 金鑰是否正確設定
- 確認你的 OpenAI 帳戶有足夠的額度
- 檢查網路連線是否正常

**問題：大檔案處理失敗**
- 確認系統有足夠的儲存空間
- 檢查 N8N 的記憶體限制設定
- 考慮調整檔案分割的大小限制

**問題：轉錄結果品質不佳**
- 確認音訊檔案品質良好
- 嘗試不同的語言設定
- 對於嘈雜的音訊，考慮預先進行降噪處理

### 日誌檢查

- N8N 日誌：檢查 N8N 控制台輸出
- Whisper 服務日誌：`docker-compose logs -f whisper-nonavx`
- 瀏覽器開發者工具：檢查網頁界面的錯誤

## 系統需求

- **記憶體**：至少 4GB RAM（推薦 8GB+）
- **儲存**：至少 10GB 可用空間
- **網路**：穩定的網際網路連線（用於 OpenAI API）
- **處理器**：x86_64 架構（Whisper 服務針對非 AVX 處理器最佳化）

## 安全注意事項

- 將 OpenAI API 金鑰保存在安全的地方
- 不要將包含 API 金鑰的檔案提交到版本控制系統
- 在生產環境中使用 HTTPS
- 定期更新系統組件以獲得安全修補程式
- 考慮設定存取限制和身份驗證