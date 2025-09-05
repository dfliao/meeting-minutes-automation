#!/bin/bash

# 伺服器端更新腳本
# 在遠端伺服器上使用此腳本來拉取和部署最新程式碼

set -e

# 顏色定義
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 設定
PROJECT_DIR="/opt/meeting-minutes-automation"  # 修改為你的實際路徑
SERVICE_NAME="n8n"
LOG_FILE="/var/log/meeting-minutes-update.log"

echo -e "${BLUE}🔄 伺服器端更新程式${NC}"
echo "$(date): 開始更新" >> $LOG_FILE

# 函數：記錄並顯示訊息
log_and_show() {
    echo -e "$1"
    echo "$(date): $2" >> $LOG_FILE
}

# 檢查是否以 root 執行（某些操作可能需要）
check_sudo() {
    if [ "$EUID" -ne 0 ] && [ "$1" = "required" ]; then
        echo -e "${RED}此腳本需要 sudo 權限來重啟服務${NC}"
        exit 1
    fi
}

# 1. 檢查專案目錄
if [ ! -d "$PROJECT_DIR" ]; then
    log_and_show "${RED}❌ 專案目錄不存在: $PROJECT_DIR${NC}" "ERROR: Project directory not found"
    exit 1
fi

cd "$PROJECT_DIR"

# 2. 備份當前狀態
log_and_show "${YELLOW}📦 備份當前狀態...${NC}" "Backing up current state"
BACKUP_DIR="/tmp/meeting-minutes-backup-$(date +%Y%m%d-%H%M%S)"
cp -r . "$BACKUP_DIR"
log_and_show "${GREEN}✅ 備份完成: $BACKUP_DIR${NC}" "Backup completed"

# 3. 拉取最新程式碼
log_and_show "${BLUE}📥 拉取最新程式碼...${NC}" "Pulling latest code"
git stash  # 暫存本地修改
git pull origin main || {
    log_and_show "${RED}❌ Git pull 失敗${NC}" "ERROR: Git pull failed"
    exit 1
}
log_and_show "${GREEN}✅ 程式碼更新完成${NC}" "Code update completed"

# 4. 更新 Whisper 服務
log_and_show "${BLUE}🐳 更新 Whisper 服務...${NC}" "Updating Whisper service"
cd whisper-service

# 停止服務
docker-compose down || true

# 重新建置並啟動
docker-compose up --build -d

# 等待服務啟動
sleep 10

# 檢查服務健康狀態
if curl -f http://localhost:10300/health &> /dev/null; then
    log_and_show "${GREEN}✅ Whisper 服務運行正常${NC}" "Whisper service is healthy"
else
    log_and_show "${YELLOW}⚠️  Whisper 服務可能需要更多時間啟動${NC}" "Whisper service may need more time to start"
fi

cd ..

# 5. 重啟 N8N 服務
log_and_show "${BLUE}🔄 重啟 N8N 服務...${NC}" "Restarting N8N service"

# 檢查 N8N 是否作為 systemd 服務運行
if systemctl is-active --quiet $SERVICE_NAME 2>/dev/null; then
    systemctl restart $SERVICE_NAME
    log_and_show "${GREEN}✅ N8N 服務已重啟${NC}" "N8N service restarted"
elif pgrep -f "n8n" > /dev/null; then
    # 如果是以 process 方式運行
    pkill -f "n8n" || true
    sleep 5
    # 這裡你可能需要調整啟動 N8N 的方式
    nohup n8n start > /var/log/n8n.log 2>&1 &
    log_and_show "${GREEN}✅ N8N 已重啟（process 模式）${NC}" "N8N restarted (process mode)"
else
    log_and_show "${YELLOW}⚠️  N8N 服務狀態未知，請手動檢查${NC}" "N8N service status unknown"
fi

# 6. 驗證服務
log_and_show "${BLUE}🔍 驗證服務狀態...${NC}" "Verifying service status"

# 檢查 N8N
if curl -f http://localhost:5678 &> /dev/null; then
    log_and_show "${GREEN}✅ N8N 運行正常${NC}" "N8N is running normally"
else
    log_and_show "${YELLOW}⚠️  N8N 可能需要更多時間啟動${NC}" "N8N may need more time to start"
fi

# 檢查 Whisper
if curl -f http://localhost:10300/health &> /dev/null; then
    log_and_show "${GREEN}✅ Whisper 服務運行正常${NC}" "Whisper service is running normally"
else
    log_and_show "${YELLOW}⚠️  Whisper 服務狀態檢查失敗${NC}" "Whisper service health check failed"
fi

# 7. 清理舊的備份（保留最近 5 個）
log_and_show "${BLUE}🧹 清理舊備份...${NC}" "Cleaning old backups"
find /tmp -name "meeting-minutes-backup-*" -type d | sort | head -n -5 | xargs rm -rf 2>/dev/null || true

# 完成
log_and_show "${GREEN}🎉 更新完成！${NC}" "Update completed successfully"
echo "$(date): Update completed successfully" >> $LOG_FILE

echo -e "\n${BLUE}📋 服務狀態檢查：${NC}"
echo "• N8N: http://localhost:5678"
echo "• Whisper: http://localhost:10300/health"
echo -e "• 備份位置: ${YELLOW}$BACKUP_DIR${NC}"
echo -e "• 日誌位置: ${YELLOW}$LOG_FILE${NC}"

echo -e "\n${YELLOW}💡 提示：${NC}"
echo "如果服務有問題，可以從備份恢復："
echo "  sudo cp -r $BACKUP_DIR/* $PROJECT_DIR/"