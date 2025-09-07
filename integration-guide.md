# N8N + Whisper 服務整合指南

## 🏗️ 系統架構

```
用戶上傳音訊 → N8N Webhook → Whisper 轉錄服務 → AI 處理 → 結構化會議紀錄
```

## 🚀 完整部署步驟

### 1. 啟動 Whisper 服務
```bash
cd /volume3/ai-stack/meeting-minutes-automation/whisper-service
sudo docker-compose up -d
curl http://localhost:10300/health  # 確認服務正常
```

### 2. 啟動 N8N 服務
```bash
n8n start
# N8N 會在 http://localhost:5678 運行
```

### 3. 設定 N8N 工作流程

#### 匯入工作流程
1. 開啟 N8N: http://localhost:5678
2. 點擊 Import workflow
3. 選擇 `n8n-workflows/audio-transcription-workflow.json`

#### 修改轉錄節點
將工作流程中的轉錄節點改為調用本地 Whisper 服務：

**節點名稱**: "直接轉錄 (< 24MB)" 和 "轉錄音訊片段"
**節點類型**: HTTP Request
**設定**:
```json
{
  "method": "POST",
  "url": "http://localhost:10300/transcribe",
  "sendBody": true,
  "contentType": "multipart-form-data",
  "bodyParameters": {
    "parameters": [
      {
        "name": "language",
        "value": "zh"
      },
      {
        "name": "compute_mode",
        "value": "local"
      }
    ]
  },
  "sendBinaryData": true,
  "binaryPropertyName": "data",
  "options": {
    "timeout": 300000
  }
}
```

### 4. 啟用工作流程
在 N8N 中點擊右上角的 "Active" 開關

## 🌐 Web 界面整合

### 方案一: 直接使用 Whisper Web 界面
```bash
# 開啟 Whisper 專用界面
open web-interface/index.html
# 設定伺服器: http://192.168.0.222:10300
```

### 方案二: 使用 N8N 完整流程界面  
```bash
# 開啟 N8N 完整處理界面
open web-interface/index.html
# 設定伺服器: http://192.168.0.222:5678/webhook/audio-transcription
```

## 📊 使用流程比較

| 方式 | 輸入 | 輸出 | 適用場景 |
|------|------|------|----------|
| 直接 Whisper | 音訊檔案 | 純文字轉錄 | 快速轉錄 |
| N8N + Whisper | 音訊檔案 | 結構化會議紀錄 | 完整會議處理 |

## 🔧 API 對接範例

### 1. 直接調用 Whisper 服務
```bash
# 只要轉錄文字
curl -X POST \
  -F "audio_file=@meeting.mp3" \
  -F "language=zh" \
  http://localhost:10300/transcribe
```

### 2. 透過 N8N 完整處理
```bash  
# 要完整的會議紀錄處理
curl -X POST \
  -F "data=@meeting.mp3" \
  http://localhost:5678/webhook/audio-transcription
```

## 🎯 實際應用場景

### 場景一: 快速語音筆記
- 使用: Whisper Web 界面
- 網址: `web-interface/index.html` → `http://localhost:10300`
- 適合: 個人語音筆記、簡單轉錄

### 場景二: 正式會議處理  
- 使用: N8N 工作流程
- 網址: `web-interface/index.html` → `http://localhost:5678/webhook/audio-transcription`
- 適合: 公司會議、需要結構化輸出

### 場景三: 程式整合
```python
import requests

# 直接轉錄
def quick_transcribe(audio_file):
    with open(audio_file, 'rb') as f:
        response = requests.post(
            'http://localhost:10300/transcribe',
            files={'audio_file': f},
            data={'language': 'zh'}
        )
    return response.json()['text']

# 完整會議處理
def full_meeting_process(audio_file):
    with open(audio_file, 'rb') as f:
        response = requests.post(
            'http://localhost:5678/webhook/audio-transcription',
            files={'data': f}
        )
    return response.json()
```

## 🔄 動態切換運算模式

### 在 N8N 中支援遠端運算
修改 HTTP 請求節點，加入運算模式參數：

```json
{
  "bodyParameters": {
    "parameters": [
      {
        "name": "language", 
        "value": "zh"
      },
      {
        "name": "compute_mode",
        "value": "={{$json.fileSize > 100 ? 'remote' : 'local'}}"
      },
      {
        "name": "remote_host",
        "value": "http://gpu-server:10300"  
      }
    ]
  }
}
```

這樣可以根據檔案大小自動選擇本地或遠端運算。

## 🔍 監控和除錯

### 檢查服務狀態
```bash
# Whisper 服務
curl http://localhost:10300/health

# N8N 服務  
curl http://localhost:5678/healthz

# 查看日誌
sudo docker-compose logs whisper-flexible
pm2 logs n8n  # 如果使用 pm2 管理 N8N
```

### 測試完整流程
```bash
# 測試檔案 (建立小測試檔案)
echo "這是測試音訊" | espeak -v zh -w test.wav

# 測試 Whisper
curl -X POST -F "audio_file=@test.wav" http://localhost:10300/transcribe

# 測試 N8N 流程  
curl -X POST -F "data=@test.wav" http://localhost:5678/webhook/audio-transcription
```

## 🎉 完成！

現在你有：
- ✅ 功能完整的 Web 操作界面
- ✅ 靈活的 Whisper 轉錄服務 
- ✅ 自動化的 N8N 會議處理流程
- ✅ 可程式化的 API 接口
- ✅ 本地/遠端運算切換能力

根據需求選擇合適的使用方式即可！