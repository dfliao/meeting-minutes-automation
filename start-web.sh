#!/bin/bash

# 啟動 Web 服務腳本 - Whisper 語音轉文字系統

set -e

# 顏色定義
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}🌐 啟動 Whisper Web 服務${NC}"
echo "================================"

# 檢查是否在正確目錄
if [ ! -f "web-interface/index.html" ]; then
    echo -e "${RED}❌ 請在專案根目錄執行此腳本${NC}"
    exit 1
fi

# 檢查 Whisper 服務是否運行
echo -e "${BLUE}🔍 檢查 Whisper 服務狀態...${NC}"
if curl -s http://localhost:10300/health &> /dev/null; then
    health_response=$(curl -s http://localhost:10300/health)
    echo -e "${GREEN}✅ Whisper 服務正常運行${NC}"
    
    # 顯示服務資訊
    version=$(echo "$health_response" | python3 -c "import json,sys; print(json.load(sys.stdin).get('version', '1.0.0'))" 2>/dev/null || echo "1.0.0")
    compute_mode=$(echo "$health_response" | python3 -c "import json,sys; print(json.load(sys.stdin).get('current_compute_mode', 'unknown'))" 2>/dev/null || echo "unknown")
    model=$(echo "$health_response" | python3 -c "import json,sys; print(json.load(sys.stdin).get('model', 'base'))" 2>/dev/null || echo "base")
    
    echo -e "${CYAN}服務版本: $version, 模式: $compute_mode, 模型: $model${NC}"
else
    echo -e "${RED}❌ Whisper 服務未運行${NC}"
    echo -e "${YELLOW}請先執行: ./quick-update.sh${NC}"
    exit 1
fi

# 檢查 N8N 服務狀態
echo -e "\n${BLUE}🔍 檢查 N8N 服務狀態...${NC}"
N8N_AVAILABLE=false
if curl -s http://localhost:5678/healthz &> /dev/null || curl -s http://localhost:5678 &> /dev/null; then
    echo -e "${GREEN}✅ N8N 服務正常運行${NC}"
    N8N_AVAILABLE=true
else
    echo -e "${YELLOW}⚠️  N8N 服務未運行（可選）${NC}"
fi

# 獲取本機 IP
echo -e "\n${BLUE}🔍 偵測網路設定...${NC}"
LOCAL_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || ip route get 1 | awk '{print $7; exit}' 2>/dev/null || echo "192.168.0.222")
echo -e "${CYAN}本機 IP: $LOCAL_IP${NC}"

# 選擇啟動模式
echo -e "\n${CYAN}選擇 Web 服務啟動模式：${NC}"
echo "1) 簡易 HTTP 伺服器 (推薦) - 任何裝置可存取"
echo "2) 本機檔案開啟 - 僅本機可用"
echo "3) 顯示使用說明 - 手動設定"

if [ "$N8N_AVAILABLE" = true ]; then
    echo ""
    echo -e "${YELLOW}可用的後端服務：${NC}"
    echo "• Whisper 直接轉錄: http://$LOCAL_IP:10300"
    echo "• N8N 完整會議處理: http://$LOCAL_IP:5678/webhook/audio-transcription"
fi

echo ""
read -p "請選擇模式 (1-3, 預設為 1): " mode_choice

case $mode_choice in
    2)
        echo -e "\n${BLUE}📂 開啟本機檔案...${NC}"
        if command -v open &> /dev/null; then
            open web-interface/index.html
        elif command -v xdg-open &> /dev/null; then
            xdg-open web-interface/index.html
        else
            echo -e "${YELLOW}請手動開啟: $(pwd)/web-interface/index.html${NC}"
        fi
        
        echo -e "\n${CYAN}💡 設定提示：${NC}"
        echo "在網頁中設定伺服器網址為："
        echo "• 直接轉錄: http://localhost:10300"
        if [ "$N8N_AVAILABLE" = true ]; then
            echo "• 完整處理: http://localhost:5678/webhook/audio-transcription"
        fi
        ;;
        
    3)
        echo -e "\n${CYAN}📋 使用說明：${NC}"
        echo "1. 手動開啟檔案: web-interface/index.html"
        echo "2. 或啟動 HTTP 伺服器:"
        echo "   cd web-interface && python3 -m http.server 8080"
        echo "3. 在瀏覽器中開啟: http://$LOCAL_IP:8080"
        echo ""
        echo -e "${CYAN}伺服器網址設定：${NC}"
        echo "• Whisper 直接轉錄: http://$LOCAL_IP:10300"
        if [ "$N8N_AVAILABLE" = true ]; then
            echo "• N8N 完整處理: http://$LOCAL_IP:5678/webhook/audio-transcription"
        fi
        ;;
        
    *)
        # 預設：啟動 HTTP 伺服器
        echo -e "\n${BLUE}🚀 啟動 HTTP 伺服器...${NC}"
        
        # 檢查埠號是否可用
        HTTP_PORT=8080
        while netstat -tuln 2>/dev/null | grep -q ":$HTTP_PORT "; do
            HTTP_PORT=$((HTTP_PORT + 1))
            if [ $HTTP_PORT -gt 8090 ]; then
                echo -e "${RED}❌ 找不到可用埠號${NC}"
                exit 1
            fi
        done
        
        echo -e "${GREEN}✅ 使用埠號: $HTTP_PORT${NC}"
        
        # 建立臨時的 index 頁面（包含設定說明）
        cat > web-interface/setup.html << EOF
<!DOCTYPE html>
<html lang="zh-TW">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Whisper 語音轉文字 - 設定指南</title>
    <style>
        body { font-family: Arial, sans-serif; max-width: 800px; margin: 50px auto; padding: 20px; }
        .service-option { background: #f5f5f5; padding: 20px; margin: 15px 0; border-radius: 10px; }
        .recommended { border-left: 5px solid #4CAF50; }
        .btn { display: inline-block; padding: 10px 20px; margin: 10px 5px; background: #007cba; color: white; text-decoration: none; border-radius: 5px; }
        .btn:hover { background: #005a87; }
        .status { padding: 10px; border-radius: 5px; margin: 10px 0; }
        .status.ok { background: #d4edda; color: #155724; }
        .status.warn { background: #fff3cd; color: #856404; }
    </style>
</head>
<body>
    <h1>🎙️ Whisper 語音轉文字系統</h1>
    
    <div class="status ok">
        ✅ Whisper 服務正常運行 (版本: $version, 模式: $compute_mode)
    </div>
    
EOF

        if [ "$N8N_AVAILABLE" = true ]; then
            echo '    <div class="status ok">✅ N8N 服務正常運行</div>' >> web-interface/setup.html
        else
            echo '    <div class="status warn">⚠️ N8N 服務未運行（可選功能）</div>' >> web-interface/setup.html
        fi

        cat >> web-interface/setup.html << EOF
    
    <h2>選擇使用方式</h2>
    
    <div class="service-option recommended">
        <h3>🚀 Whisper 直接轉錄</h3>
        <p>快速語音轉文字，適合一般使用</p>
        <p><strong>伺服器網址:</strong> <code>http://$LOCAL_IP:10300</code></p>
        <a href="index.html?server=http://$LOCAL_IP:10300" class="btn">開始使用</a>
    </div>
    
EOF

        if [ "$N8N_AVAILABLE" = true ]; then
            cat >> web-interface/setup.html << EOF
    <div class="service-option">
        <h3>📋 N8N 完整會議處理</h3>
        <p>包含 AI 生成結構化會議紀錄</p>
        <p><strong>伺服器網址:</strong> <code>http://$LOCAL_IP:5678/webhook/audio-transcription</code></p>
        <a href="index.html?server=http://$LOCAL_IP:5678/webhook/audio-transcription" class="btn">開始使用</a>
    </div>
EOF
        fi

        cat >> web-interface/setup.html << EOF
    
    <h2>📱 存取方式</h2>
    <ul>
        <li><strong>本機存取:</strong> <a href="http://localhost:$HTTP_PORT">http://localhost:$HTTP_PORT</a></li>
        <li><strong>區網存取:</strong> <a href="http://$LOCAL_IP:$HTTP_PORT">http://$LOCAL_IP:$HTTP_PORT</a></li>
        <li><strong>手機存取:</strong> 在手機瀏覽器輸入 http://$LOCAL_IP:$HTTP_PORT</li>
    </ul>
    
    <h2>📊 檔案儲存</h2>
    <p>轉錄結果將儲存在: <code>/volume3/ai-stack/audio/results/</code></p>
    
    <h2>🔧 管理指令</h2>
    <pre>
# 檢查服務狀態
curl http://$LOCAL_IP:10300/health

# 重新啟動服務
./quick-update.sh

# 查看服務日誌  
sudo docker-compose logs -f
    </pre>
    
</body>
</html>
EOF
        
        cd web-interface
        
        echo -e "\n${GREEN}🌐 Web 服務已啟動！${NC}"
        echo "================================"
        echo -e "${CYAN}存取網址：${NC}"
        echo "• 本機: http://localhost:$HTTP_PORT"
        echo "• 區網: http://$LOCAL_IP:$HTTP_PORT"
        echo "• 手機: http://$LOCAL_IP:$HTTP_PORT"
        echo ""
        echo -e "${CYAN}可用服務：${NC}"
        echo "• Whisper 轉錄: http://$LOCAL_IP:10300"
        if [ "$N8N_AVAILABLE" = true ]; then
            echo "• N8N 會議處理: http://$LOCAL_IP:5678/webhook/audio-transcription"
        fi
        echo ""
        echo -e "${YELLOW}按 Ctrl+C 停止服務${NC}"
        echo "================================"
        
        # 自動開啟瀏覽器（如果可能）
        if command -v open &> /dev/null; then
            sleep 2 && open "http://localhost:$HTTP_PORT" &
        elif command -v xdg-open &> /dev/null; then
            sleep 2 && xdg-open "http://localhost:$HTTP_PORT" &
        fi
        
        # 啟動 HTTP 伺服器
        python3 -m http.server $HTTP_PORT
        ;;
esac