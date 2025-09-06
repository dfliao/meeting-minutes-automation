#!/bin/bash

# 快速部署腳本 - 使用 OpenAI API 而非本地 whisper.cpp

set -e

# 顏色定義
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🚀 快速部署 Whisper 服務（本地運算）${NC}"
echo "========================================="

# 檢查是否在正確目錄
if [ ! -f "whisper-service/docker-compose.yaml" ]; then
    echo -e "${RED}❌ 請在專案根目錄執行此腳本${NC}"
    exit 1
fi

# 進入 whisper-service 目錄
cd whisper-service

# 停止現有服務
echo -e "${YELLOW}⏹️  停止現有服務...${NC}"
docker-compose down || true

# 備份原始檔案
echo -e "${BLUE}📦 備份原始配置...${NC}"
cp server.py server.py.backup 2>/dev/null || true
cp docker-compose.yaml docker-compose.yaml.backup 2>/dev/null || true

# 使用快速版本
echo -e "${BLUE}🔄 切換到快速版本...${NC}"
cp server-fast.py server.py
cp docker-compose.fast.yaml docker-compose.yaml

# 檢查 Ollama 服務
echo -e "${BLUE}🔍 檢查本地服務...${NC}"

# 檢查 Ollama 是否運行
if curl -s http://localhost:11434/api/tags &> /dev/null; then
    echo -e "${GREEN}✅ Ollama 服務運行正常${NC}"
    export USE_OLLAMA=true
    export OLLAMA_HOST="http://host.docker.internal:11434"
else
    echo -e "${YELLOW}⚠️  Ollama 服務未運行，將嘗試使用預編譯 Whisper${NC}"
    export USE_OLLAMA=false
fi

# 詢問是否要下載 Whisper 模型（如果不使用 Ollama）
if [ "$USE_OLLAMA" != "true" ]; then
    echo -e "${YELLOW}📥 需要下載 Whisper 模型檔案嗎？ (約 142MB)${NC}"
    read -p "下載 base 模型? (y/N): " download_model
    if [[ $download_model =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}📥 下載模型中...${NC}"
        mkdir -p /volume3/ai-stack/models
        cd /volume3/ai-stack/models
        if [ ! -f "ggml-base.bin" ]; then
            wget -q --show-progress https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin
            echo -e "${GREEN}✅ 模型下載完成${NC}"
        else
            echo -e "${GREEN}✅ 模型已存在${NC}"
        fi
        cd - > /dev/null
    fi
fi

# 建置並啟動服務
echo -e "${BLUE}🔨 建置快速版本...${NC}"
docker-compose build

echo -e "${BLUE}🚀 啟動服務...${NC}"
docker-compose up -d

# 等待服務啟動
echo -e "${YELLOW}⏳ 等待服務啟動...${NC}"
sleep 10

# 健康檢查
echo -e "${BLUE}🔍 健康檢查...${NC}"
for i in {1..5}; do
    if curl -s http://localhost:10300/health &> /dev/null; then
        response=$(curl -s http://localhost:10300/health)
        echo -e "${GREEN}✅ 服務啟動成功！${NC}"
        echo "回應: $response"
        break
    else
        echo -e "${YELLOW}⏳ 等待服務啟動... ($i/5)${NC}"
        sleep 3
    fi
    
    if [ $i -eq 5 ]; then
        echo -e "${RED}❌ 服務啟動失敗，請檢查日誌${NC}"
        docker-compose logs
        exit 1
    fi
done

echo ""
echo -e "${GREEN}🎉 快速部署完成！${NC}"
echo "========================================="
echo "• 服務網址: http://localhost:10300"
echo "• 健康檢查: http://localhost:10300/health"
echo "• 使用本地 Ollama 或預編譯 Whisper 進行轉錄"
echo ""
echo -e "${BLUE}💡 測試指令:${NC}"
echo "curl -X POST -F \"audio_file=@your-audio.mp3\" http://localhost:10300/transcribe"
echo ""
echo -e "${YELLOW}📋 管理指令:${NC}"
echo "docker-compose logs -f    # 查看日誌"
echo "docker-compose down       # 停止服務"
echo "docker-compose up -d      # 啟動服務"