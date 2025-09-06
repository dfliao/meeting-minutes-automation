#!/bin/bash

# 快速部署腳本 - 使用 OpenAI API 而非本地 whisper.cpp

set -e

# 顏色定義
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🚀 快速部署 Whisper 服務（使用 OpenAI API）${NC}"
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

# 檢查 OpenAI API Key
if [ -z "$OPENAI_API_KEY" ]; then
    echo -e "${YELLOW}⚠️  請設定 OpenAI API Key:${NC}"
    echo "export OPENAI_API_KEY='your-api-key-here'"
    echo ""
    read -p "請輸入你的 OpenAI API Key: " api_key
    if [ -n "$api_key" ]; then
        export OPENAI_API_KEY="$api_key"
        echo "export OPENAI_API_KEY='$api_key'" >> ~/.bashrc
        echo -e "${GREEN}✅ API Key 已設定並儲存到 ~/.bashrc${NC}"
    else
        echo -e "${RED}❌ 需要 OpenAI API Key 才能使用快速版本${NC}"
        exit 1
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
echo "• 使用 OpenAI Whisper API 進行轉錄"
echo ""
echo -e "${BLUE}💡 測試指令:${NC}"
echo "curl -X POST -F \"audio_file=@your-audio.mp3\" http://localhost:10300/transcribe"
echo ""
echo -e "${YELLOW}📋 管理指令:${NC}"
echo "docker-compose logs -f    # 查看日誌"
echo "docker-compose down       # 停止服務"
echo "docker-compose up -d      # 啟動服務"