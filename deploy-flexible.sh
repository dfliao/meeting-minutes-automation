#!/bin/bash

# Whisper 靈活運算服務部署腳本

set -e

# 顏色定義
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}🚀 部署 Whisper 靈活運算服務${NC}"
echo "========================================"
echo "支援本地和遠端 Whisper 運算的切換"
echo ""

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

# 使用靈活版本
echo -e "${BLUE}🔄 切換到靈活版本...${NC}"
cp server-flexible.py server.py
cp docker-compose.flexible.yaml docker-compose.yaml

# 互動式設定
echo -e "${CYAN}⚙️  請選擇運算模式:${NC}"
echo "1) 本地運算 (使用本機 CPU)"
echo "2) 遠端運算 (使用專用運算伺服器)" 
echo "3) 自動選擇 (智能切換)"
echo ""
read -p "請選擇 (1-3): " mode_choice

case $mode_choice in
    1)
        export COMPUTE_MODE=local
        echo -e "${GREEN}✅ 設定為本地運算模式${NC}"
        ;;
    2)
        export COMPUTE_MODE=remote
        echo -e "${YELLOW}請輸入遠端運算伺服器網址:${NC}"
        read -p "網址 (如: http://gpu-server:10300): " remote_host
        if [ -n "$remote_host" ]; then
            export REMOTE_WHISPER_HOST="$remote_host"
            echo -e "${GREEN}✅ 設定為遠端運算模式: $remote_host${NC}"
        else
            echo -e "${RED}❌ 未輸入遠端伺服器網址${NC}"
            exit 1
        fi
        ;;
    3)
        export COMPUTE_MODE=auto
        echo -e "${YELLOW}請輸入遠端運算伺服器網址 (可選):${NC}"
        read -p "網址 (如: http://gpu-server:10300，按 Enter 跳過): " remote_host
        if [ -n "$remote_host" ]; then
            export REMOTE_WHISPER_HOST="$remote_host"
        fi
        echo -e "${GREEN}✅ 設定為自動選擇模式${NC}"
        ;;
    *)
        echo -e "${RED}❌ 無效選擇${NC}"
        exit 1
        ;;
esac

# 選擇 Whisper 模型
echo -e "\n${CYAN}🤖 請選擇 Whisper 模型:${NC}"
echo "1) tiny (39MB, 快速, 基本品質)"
echo "2) base (142MB, 平衡, 推薦) [預設]"
echo "3) small (244MB, 較好品質)"
echo "4) medium (769MB, 高品質)"
echo "5) large (1550MB, 最佳品質)"
echo ""
read -p "請選擇 (1-5, 預設為 2): " model_choice

case $model_choice in
    1) export WHISPER_MODEL=tiny ;;
    3) export WHISPER_MODEL=small ;;
    4) export WHISPER_MODEL=medium ;;
    5) export WHISPER_MODEL=large ;;
    *) export WHISPER_MODEL=base ;;
esac

echo -e "${GREEN}✅ 選擇模型: $WHISPER_MODEL${NC}"

# 設定語言
echo -e "\n${CYAN}🌍 請選擇預設語言:${NC}"
echo "1) 中文 [預設]"
echo "2) 英文"
echo "3) 日文"
echo "4) 韓文"
echo "5) 自動偵測"
echo ""
read -p "請選擇 (1-5, 預設為 1): " lang_choice

case $lang_choice in
    2) export WHISPER_LANG=en ;;
    3) export WHISPER_LANG=ja ;;
    4) export WHISPER_LANG=ko ;;
    5) export WHISPER_LANG=auto ;;
    *) export WHISPER_LANG=zh ;;
esac

echo -e "${GREEN}✅ 設定語言: $WHISPER_LANG${NC}"

# 儲存設定到環境檔案
echo -e "\n${BLUE}💾 儲存設定...${NC}"
cat > .env << EOF
# Whisper 靈活運算服務設定
COMPUTE_MODE=$COMPUTE_MODE
WHISPER_MODEL=$WHISPER_MODEL
WHISPER_LANG=$WHISPER_LANG
WHISPER_THREADS=4
REMOTE_WHISPER_HOST=$REMOTE_WHISPER_HOST
EOF

echo -e "${GREEN}✅ 設定已儲存到 .env 檔案${NC}"

# 建置並啟動服務
echo -e "\n${BLUE}🔨 建置服務...${NC}"
docker-compose build

echo -e "${BLUE}🚀 啟動服務...${NC}"
docker-compose up -d

# 等待服務啟動
echo -e "${YELLOW}⏳ 等待服務啟動...${NC}"
sleep 15

# 健康檢查
echo -e "${BLUE}🔍 檢查服務狀態...${NC}"
for i in {1..5}; do
    if curl -s http://localhost:10300/health &> /dev/null; then
        response=$(curl -s http://localhost:10300/health | jq '.' 2>/dev/null || curl -s http://localhost:10300/health)
        echo -e "${GREEN}✅ 服務啟動成功！${NC}"
        echo -e "${CYAN}服務狀態:${NC}"
        echo "$response"
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

# 顯示完成訊息
echo -e "\n${GREEN}🎉 Whisper 靈活運算服務部署完成！${NC}"
echo "========================================"
echo -e "${BLUE}服務資訊:${NC}"
echo "• 服務網址: http://localhost:10300"
echo "• 健康檢查: http://localhost:10300/health"
echo "• API 文檔: http://localhost:10300/docs"
echo "• 運算模式: $COMPUTE_MODE"
echo "• Whisper 模型: $WHISPER_MODEL"
echo "• 預設語言: $WHISPER_LANG"

if [ -n "$REMOTE_WHISPER_HOST" ]; then
    echo "• 遠端伺服器: $REMOTE_WHISPER_HOST"
fi

echo ""
echo -e "${CYAN}💡 測試指令:${NC}"
echo "curl -X POST -F \"audio_file=@your-audio.mp3\" http://localhost:10300/transcribe"
echo ""
echo -e "${CYAN}📋 管理指令:${NC}"
echo "docker-compose logs -f    # 查看日誌"
echo "docker-compose down       # 停止服務"
echo "docker-compose up -d      # 啟動服務"
echo ""
echo -e "${CYAN}📚 使用指南:${NC}"
echo "請參考 whisper-usage-guide.md 了解詳細使用方法"
echo ""

# 顯示網頁界面資訊
if [ -f "../web-interface/index.html" ]; then
    echo -e "${BLUE}🌐 網頁界面:${NC}"
    echo "請開啟 web-interface/index.html"
    echo "並確認伺服器網址設定為: http://localhost:10300"
fi