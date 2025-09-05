#!/bin/bash

# 會議紀錄自動化系統 - 部署腳本
# 使用方法: ./deploy.sh [環境] [訊息]
# 範例: ./deploy.sh production "修復轉錄bug"

set -e  # 遇到錯誤立即停止

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 預設值
ENVIRONMENT=${1:-"production"}
COMMIT_MESSAGE=${2:-"deploy: 更新系統配置"}
REMOTE_SERVER=${3:-"192.168.0.222"}

echo -e "${BLUE}🚀 會議紀錄自動化系統 - 部署腳本${NC}"
echo "================================="
echo -e "環境: ${YELLOW}$ENVIRONMENT${NC}"
echo -e "伺服器: ${YELLOW}$REMOTE_SERVER${NC}"
echo -e "提交訊息: ${YELLOW}$COMMIT_MESSAGE${NC}"
echo "================================="

# 函數：顯示步驟
show_step() {
    echo -e "\n${BLUE}📋 步驟 $1: $2${NC}"
}

# 函數：顯示成功訊息
show_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# 函數：顯示警告訊息
show_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# 函數：顯示錯誤訊息
show_error() {
    echo -e "${RED}❌ $1${NC}"
    exit 1
}

# 函數：確認使用者輸入
confirm() {
    read -p "是否繼續? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "取消部署"
        exit 1
    fi
}

# 步驟 1: 檢查 Git 狀態
show_step 1 "檢查 Git 狀態"
if [ -n "$(git status --porcelain)" ]; then
    show_warning "發現未提交的更改："
    git status --short
    echo
    confirm
fi

# 步驟 2: 拉取最新程式碼
show_step 2 "同步遠端程式碼"
git fetch origin
if [ $(git rev-list HEAD...origin/main --count) != 0 ]; then
    show_warning "遠端有新的提交，正在合併..."
    git pull origin main || show_error "合併失敗，請手動解決衝突"
fi
show_success "程式碼同步完成"

# 步驟 3: 執行測試（如果存在）
show_step 3 "執行測試"
if [ -f "tests/test.py" ]; then
    python tests/test.py || show_error "測試失敗"
    show_success "測試通過"
else
    show_warning "未發現測試檔案，跳過測試"
fi

# 步驟 4: 提交更改（如果有）
show_step 4 "提交本地更改"
if [ -n "$(git status --porcelain)" ]; then
    git add .
    git commit -m "$COMMIT_MESSAGE

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>" || show_error "提交失敗"
    show_success "本地更改已提交"
else
    show_warning "沒有需要提交的更改"
fi

# 步驟 5: 推送到遠端
show_step 5 "推送到 GitHub"
git push origin main || show_error "推送失敗"
show_success "程式碼已推送到 GitHub"

# 步驟 6: 部署到伺服器
show_step 6 "部署到遠端伺服器"

# 檢查是否可以連接到伺服器
if ping -c 1 $REMOTE_SERVER &> /dev/null; then
    show_success "伺服器 $REMOTE_SERVER 連線正常"
    
    # 建立部署指令
    cat << EOF > deploy_commands.sh
#!/bin/bash
echo "🔄 在伺服器上更新程式..."

# 進入專案目錄
cd /path/to/meeting-minutes-automation || { echo "專案目錄不存在"; exit 1; }

# 拉取最新程式碼
echo "📥 拉取最新程式碼..."
git pull origin main

# 重啟 Docker 服務
echo "🐳 重啟 Whisper 服務..."
cd whisper-service
docker-compose down
docker-compose up --build -d

# 檢查服務狀態
echo "🔍 檢查服務狀態..."
sleep 5
curl -f http://localhost:10300/health || echo "⚠️  Whisper 服務可能未正常啟動"

# 重啟 N8N（如果使用 systemd 管理）
if systemctl is-active --quiet n8n; then
    echo "🔄 重啟 N8N 服務..."
    sudo systemctl restart n8n
fi

echo "✅ 部署完成！"
EOF

    chmod +x deploy_commands.sh
    
    echo -e "${YELLOW}📤 將部署腳本上傳到伺服器並執行...${NC}"
    echo -e "${YELLOW}注意：請確保已設定 SSH 金鑰認證${NC}"
    
    # 這裡你需要替換成實際的使用者名稱
    # scp deploy_commands.sh user@$REMOTE_SERVER:/tmp/
    # ssh user@$REMOTE_SERVER "bash /tmp/deploy_commands.sh"
    
    echo -e "${BLUE}手動部署指令：${NC}"
    echo "scp deploy_commands.sh user@$REMOTE_SERVER:/tmp/"
    echo "ssh user@$REMOTE_SERVER 'bash /tmp/deploy_commands.sh'"
    
    # 清理臨時檔案
    rm -f deploy_commands.sh
    
else
    show_warning "無法連接到伺服器 $REMOTE_SERVER"
    show_warning "請手動在伺服器上執行以下指令："
    echo -e "${BLUE}"
    cat << 'EOF'
cd /path/to/meeting-minutes-automation
git pull origin main
cd whisper-service
docker-compose down && docker-compose up --build -d
systemctl restart n8n  # 如果使用 systemd 管理
EOF
    echo -e "${NC}"
fi

# 步驟 7: 驗證部署
show_step 7 "驗證部署"
echo -e "${BLUE}請檢查以下服務：${NC}"
echo "• N8N 管理界面: http://$REMOTE_SERVER:5678"
echo "• Whisper 服務健康檢查: http://$REMOTE_SERVER:10300/health"
echo "• 網頁上傳界面: 開啟 web-interface/index.html"

echo -e "\n${GREEN}🎉 部署腳本執行完成！${NC}"
echo -e "${YELLOW}💡 提示：下次使用可執行 ./deploy.sh production \"你的提交訊息\"${NC}"