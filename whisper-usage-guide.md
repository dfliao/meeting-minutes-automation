# Whisper 靈活運算服務使用指南

## 🚀 功能特色

- **本地運算**: 使用本機 CPU/GPU 運行 Whisper 模型
- **遠端運算**: 連接到你的專用運算伺服器
- **自動切換**: 智能選擇最佳可用的運算資源
- **參數化配置**: 可透過 API 動態調整設定
- **多語言支援**: 中文、英文、日文、韓文等

## 📋 部署方式

### 方法一：使用靈活版本（推薦）

```bash
# 1. 進入專案目錄
cd /volume3/ai-stack/meeting-minutes-automation/whisper-service

# 2. 停止現有服務
docker-compose down

# 3. 使用靈活版本
cp server-flexible.py server.py
cp docker-compose.flexible.yaml docker-compose.yaml

# 4. 設定環境變數（可選）
export COMPUTE_MODE=local          # 預設使用本地運算
export WHISPER_MODEL=base          # 使用 base 模型
export WHISPER_LANG=zh             # 預設中文

# 5. 建置並啟動
docker-compose build --no-cache
docker-compose up -d

# 6. 檢查服務狀態
curl http://localhost:10300/health
```

## 🔧 運算模式設定

### 1. 本地運算模式

```bash
# 設定環境變數
export COMPUTE_MODE=local
export WHISPER_MODEL=base  # 可選: tiny, base, small, medium, large

# 重啟服務
docker-compose down && docker-compose up -d
```

### 2. 遠端運算模式

```bash
# 設定遠端伺服器
export COMPUTE_MODE=remote
export REMOTE_WHISPER_HOST=http://your-gpu-server:10300

# 重啟服務
docker-compose down && docker-compose up -d
```

### 3. 自動選擇模式

```bash
# 自動選擇最佳運算方式
export COMPUTE_MODE=auto
export REMOTE_WHISPER_HOST=http://your-gpu-server:10300  # 備用選項

# 重啟服務
docker-compose down && docker-compose up -d
```

## 📡 API 使用方式

### 1. 健康檢查

```bash
curl http://localhost:10300/health
```

回應範例：
```json
{
  "status": "ok",
  "version": "2.0.0",
  "local_whisper_available": true,
  "remote_whisper_available": false,
  "available_modes": ["local"],
  "current_compute_mode": "local",
  "model": "base",
  "language": "zh"
}
```

### 2. 語音轉文字（使用預設設定）

```bash
curl -X POST \
  -F "audio_file=@your-audio.mp3" \
  http://localhost:10300/transcribe
```

### 3. 語音轉文字（指定參數）

```bash
curl -X POST \
  -F "audio_file=@your-audio.mp3" \
  -F "language=zh" \
  -F "compute_mode=local" \
  http://localhost:10300/transcribe
```

### 4. 使用遠端運算

```bash
curl -X POST \
  -F "audio_file=@your-audio.mp3" \
  -F "language=zh" \
  -F "compute_mode=remote" \
  -F "remote_host=http://your-gpu-server:10300" \
  http://localhost:10300/transcribe
```

### 5. 動態設定運算模式

```bash
# 切換到本地運算
curl -X POST \
  -F "mode=local" \
  http://localhost:10300/config/compute_mode

# 切換到遠端運算
curl -X POST \
  -F "mode=remote" \
  http://localhost:10300/config/compute_mode

# 設定遠端伺服器
curl -X POST \
  -F "host=http://your-gpu-server:10300" \
  http://localhost:10300/config/remote_host
```

### 6. 檢查目前配置

```bash
curl http://localhost:10300/config
```

## 🌐 網頁界面使用

修改 `web-interface/index.html` 中的伺服器網址為：
```
http://your-server:10300
```

然後就可以透過網頁界面上傳音訊檔案進行轉錄。

## ⚙️ 進階設定

### 環境變數完整清單

```bash
# 基本設定
WHISPER_MODEL=base              # 模型大小: tiny, base, small, medium, large
WHISPER_LANG=zh                 # 預設語言: zh, en, ja, ko, auto
WHISPER_THREADS=4               # CPU 執行緒數

# 運算模式
COMPUTE_MODE=local              # local, remote, auto
REMOTE_WHISPER_HOST=            # 遠端伺服器網址

# 進階設定
PYTHONUNBUFFERED=1              # 即時輸出日誌
```

### Docker Compose 覆蓋設定

建立 `docker-compose.override.yml`：

```yaml
version: '3.8'
services:
  whisper-flexible:
    environment:
      - COMPUTE_MODE=auto
      - REMOTE_WHISPER_HOST=http://gpu-server:10300
      - WHISPER_MODEL=large
    deploy:
      resources:
        limits:
          memory: 8G
```

## 🔍 故障排除

### 1. 本地模型載入失敗

```bash
# 檢查模型快取
ls -la ~/.cache/whisper/

# 清理並重新下載
rm -rf ~/.cache/whisper/
docker-compose restart
```

### 2. 遠端連接失敗

```bash
# 測試遠端伺服器連通性
curl http://your-gpu-server:10300/health

# 檢查網路設定
docker-compose logs whisper-flexible
```

### 3. 記憶體不足

```bash
# 使用較小的模型
export WHISPER_MODEL=tiny

# 或限制 Docker 記憶體使用
docker-compose down
docker-compose up -d
```

## 🚀 效能建議

### 本地運算
- **CPU**: 建議 4 核心以上
- **記憶體**: 最少 4GB，推薦 8GB
- **模型選擇**: base（平衡）、large（高品質）

### 遠端運算
- **網路**: 穩定的內網連接
- **延遲**: < 100ms 為佳
- **頻寬**: 建議 100Mbps 以上

## 📊 模型比較

| 模型 | 大小 | 記憶體需求 | 轉錄速度 | 準確度 |
|------|------|-----------|----------|--------|
| tiny | 39MB | ~1GB | 最快 | 基本 |
| base | 142MB | ~2GB | 快 | 良好 |
| small | 244MB | ~3GB | 中等 | 很好 |
| medium | 769MB | ~5GB | 較慢 | 優秀 |
| large | 1550MB | ~10GB | 最慢 | 最佳 |

推薦：**base 模型** 在速度和準確度之間取得良好平衡。