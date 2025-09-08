#!/bin/bash

# 快速更新與啟動腳本 - Whisper 語音轉文字系統

set -e

# 顏色定義
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}🚀 Whisper 語音轉文字系統 - 快速更新${NC}"
echo "================================================"

# 檢查是否在正確目錄
if [ ! -f "whisper-service/docker-compose.yaml" ]; then
    echo -e "${RED}❌ 請在專案根目錄執行此腳本${NC}"
    exit 1
fi

# 1. 更新程式碼
echo -e "${BLUE}📥 更新程式碼...${NC}"
git stash push -m "自動暫存本地修改 $(date)" || true
git pull origin main

# 2. 進入 whisper-service 目錄
cd whisper-service

# 3. 詢問使用哪個版本
echo -e "\n${CYAN}選擇要使用的服務版本：${NC}"
echo "1) 標準版本 (server-flexible.py) - 基本轉錄功能"
echo "2) 下載版本 (server-download.py) - 包含檔案下載功能"
echo "3) 保持當前版本 - 不修改 server.py"
echo ""
read -p "請選擇 (1-3, 預設為 2): " version_choice

case $version_choice in
    1)
        if [ -f "server-flexible.py" ]; then
            cp server-flexible.py server.py
            echo -e "${GREEN}✅ 使用標準版本${NC}"
        else
            echo -e "${YELLOW}⚠️  標準版本檔案不存在，保持當前版本${NC}"
        fi
        ;;
    3)
        echo -e "${YELLOW}ℹ️  保持當前 server.py 版本${NC}"
        ;;
    *)
        if [ -f "server-download.py" ]; then
            cp server-download.py server.py
            echo -e "${GREEN}✅ 使用下載版本${NC}"
        else
            echo -e "${YELLOW}⚠️  下載版本檔案不存在，保持當前版本${NC}"
        fi
        ;;
esac

# 4. 詢問是否要使用靈活配置
echo -e "\n${CYAN}選擇 Docker 配置：${NC}"
echo "1) 使用靈活配置 (docker-compose.flexible.yaml)"
echo "2) 保持當前配置"
echo ""
read -p "請選擇 (1-2, 預設為 1): " config_choice

if [ "$config_choice" != "2" ] && [ -f "docker-compose.flexible.yaml" ]; then
    cp docker-compose.flexible.yaml docker-compose.yaml
    echo -e "${GREEN}✅ 使用靈活配置${NC}"
fi

# 5. 設定環境變數
echo -e "\n${BLUE}⚙️  設定環境變數...${NC}"

# 檢查是否有現有的 .env 檔案
if [ -f ".env" ]; then
    echo -e "${YELLOW}發現現有 .env 配置：${NC}"
    cat .env
    echo ""
    read -p "是否要重新配置？ (y/N): " reconfig
    if [[ ! $reconfig =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}✅ 保持現有配置${NC}"
        source .env 2>/dev/null || true
    else
        rm .env
    fi
fi

# 如果沒有 .env 或選擇重新配置
if [ ! -f ".env" ]; then
    echo -e "${CYAN}請設定基本參數：${NC}"
    
    # 運算模式
    echo "運算模式："
    echo "1) local - 本地運算"
    echo "2) remote - 遠端運算"
    echo "3) auto - 自動選擇"
    read -p "選擇運算模式 (1-3, 預設為 1): " compute_mode_choice
    
    case $compute_mode_choice in
        2) COMPUTE_MODE="remote" ;;
        3) COMPUTE_MODE="auto" ;;
        *) COMPUTE_MODE="local" ;;
    esac
    
    # 如果選擇遠端，詢問遠端伺服器
    if [ "$COMPUTE_MODE" = "remote" ] || [ "$COMPUTE_MODE" = "auto" ]; then
        read -p "遠端 Whisper 伺服器網址 (例: http://gpu-server:10300): " remote_host
        REMOTE_WHISPER_HOST="$remote_host"
    else
        REMOTE_WHISPER_HOST=""
    fi
    
    # 模型大小
    echo -e "\nWhisper 模型："
    echo "1) tiny (快速，基本品質)"
    echo "2) base (平衡，推薦)"
    echo "3) small (較好品質)"
    echo "4) medium (高品質)"
    echo "5) large (最佳品質)"
    read -p "選擇模型 (1-5, 預設為 2): " model_choice
    
    case $model_choice in
        1) WHISPER_MODEL="tiny" ;;
        3) WHISPER_MODEL="small" ;;
        4) WHISPER_MODEL="medium" ;;
        5) WHISPER_MODEL="large" ;;
        *) WHISPER_MODEL="base" ;;
    esac
    
    # 語言
    echo -e "\n預設語言："
    echo "1) zh (中文)"
    echo "2) en (英文)"
    echo "3) ja (日文)"
    echo "4) auto (自動偵測)"
    read -p "選擇語言 (1-4, 預設為 1): " lang_choice
    
    case $lang_choice in
        2) WHISPER_LANG="en" ;;
        3) WHISPER_LANG="ja" ;;
        4) WHISPER_LANG="auto" ;;
        *) WHISPER_LANG="zh" ;;
    esac
    
    # 寫入 .env 檔案
    cat > .env << EOF
# Whisper 服務配置 - 生成時間: $(date)
COMPUTE_MODE=$COMPUTE_MODE
WHISPER_MODEL=$WHISPER_MODEL
WHISPER_LANG=$WHISPER_LANG
WHISPER_THREADS=4
REMOTE_WHISPER_HOST=$REMOTE_WHISPER_HOST
EOF
    
    echo -e "${GREEN}✅ 配置已儲存到 .env${NC}"
fi

# 6. 確保必要目錄存在
echo -e "\n${BLUE}📁 建立必要目錄...${NC}"
mkdir -p /volume3/ai-stack/audio/results
mkdir -p /volume3/ai-stack/models
sudo chmod 755 /volume3/ai-stack/audio /volume3/ai-stack/models 2>/dev/null || true

# 7. 停止現有服務
echo -e "\n${BLUE}⏹️  停止現有服務...${NC}"
sudo docker-compose down || docker-compose down

# 8. 重新建置並啟動
echo -e "\n${BLUE}🔨 重新建置服務...${NC}"
sudo docker-compose build --no-cache || docker-compose build --no-cache

echo -e "\n${BLUE}🚀 啟動服務...${NC}"
sudo docker-compose up -d || docker-compose up -d

# 9. 等待服務啟動
echo -e "\n${YELLOW}⏳ 等待服務啟動...${NC}"
sleep 20

# 10. 測試服務
echo -e "\n${BLUE}🔍 測試服務狀態...${NC}"
for i in {1..5}; do
    if curl -s http://localhost:10300/health &> /dev/null; then
        health_response=$(curl -s http://localhost:10300/health)
        echo -e "${GREEN}✅ 服務啟動成功！${NC}"
        echo -e "${CYAN}服務狀態:${NC}"
        echo "$health_response" | python3 -m json.tool 2>/dev/null || echo "$health_response"
        break
    else
        echo -e "${YELLOW}⏳ 等待服務啟動... ($i/5)${NC}"
        sleep 5
    fi
    
    if [ $i -eq 5 ]; then
        echo -e "${RED}❌ 服務啟動失敗${NC}"
        echo -e "${YELLOW}查看日誌：${NC}"
        sudo docker-compose logs --tail 20 || docker-compose logs --tail 20
        exit 1
    fi
done

# 11. 顯示完成訊息
echo -e "\n${GREEN}🎉 更新完成！${NC}"
echo "========================================"
echo -e "${BLUE}服務資訊:${NC}"
echo "• Whisper 服務: http://192.168.0.222:10300"
echo "• 健康檢查: http://192.168.0.222:10300/health"
echo "• API 文檔: http://192.168.0.222:10300/docs"

# 讀取配置顯示
if [ -f ".env" ]; then
    source .env
    echo "• 運算模式: $COMPUTE_MODE"
    echo "• 模型: $WHISPER_MODEL"  
    echo "• 語言: $WHISPER_LANG"
    if [ -n "$REMOTE_WHISPER_HOST" ]; then
        echo "• 遠端伺服器: $REMOTE_WHISPER_HOST"
    fi
fi

echo ""
echo -e "${CYAN}💡 使用方式:${NC}"
echo "1. 網頁界面: 執行 ./start-web.sh"
echo "2. 測試轉錄: curl -X POST -F \"audio_file=@test.mp3\" http://localhost:10300/transcribe"
echo "3. 查看結果: ls -la /volume3/ai-stack/audio/results/"
echo "4. 管理服務: sudo docker-compose logs -f"

echo ""
echo -e "${GREEN}✨ 系統已準備就緒！${NC}"