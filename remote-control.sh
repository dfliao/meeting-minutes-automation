#!/bin/bash

# 遠端容器控制腳本
# 使用方法: ./remote-control.sh [命令] [選項]

set -e

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 設定
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WHISPER_DIR="$SCRIPT_DIR/whisper-service"
LOG_FILE="/tmp/whisper-control.log"

# 函數：顯示使用說明
show_usage() {
    echo -e "${BLUE}🛠️  Whisper 容器控制腳本${NC}"
    echo "================================="
    echo "使用方法: $0 [命令] [選項]"
    echo ""
    echo "基本命令："
    echo "  start        啟動容器"
    echo "  stop         停止容器"
    echo "  restart      重啟容器"
    echo "  rebuild      重新建置並啟動"
    echo "  status       查看狀態"
    echo "  logs         查看日誌"
    echo "  health       健康檢查"
    echo "  update       更新程式碼並重建"
    echo ""
    echo "進階命令："
    echo "  clean        清理所有容器和鏡像"
    echo "  backup       備份當前配置"
    echo "  monitor      持續監控狀態"
    echo ""
    echo "範例："
    echo "  $0 update           # 更新程式碼並重建"
    echo "  $0 restart          # 重啟容器"
    echo "  $0 logs -f          # 持續查看日誌"
    echo "  $0 monitor          # 持續監控"
    echo ""
}

# 函數：記錄日誌
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" >> "$LOG_FILE"
}

# 函數：顯示狀態訊息
show_status() {
    echo -e "$1"
    log "$2"
}

# 函數：檢查 Docker 和目錄
check_prerequisites() {
    if ! command -v docker &> /dev/null; then
        show_status "${RED}❌ Docker 未安裝${NC}" "ERROR: Docker not found"
        exit 1
    fi

    if ! command -v docker-compose &> /dev/null; then
        show_status "${RED}❌ Docker Compose 未安裝${NC}" "ERROR: Docker Compose not found"
        exit 1
    fi

    if [ ! -d "$WHISPER_DIR" ]; then
        show_status "${RED}❌ Whisper 服務目錄不存在: $WHISPER_DIR${NC}" "ERROR: Whisper directory not found"
        exit 1
    fi

    cd "$WHISPER_DIR"
}

# 函數：獲取容器狀態
get_container_status() {
    if docker ps | grep -q whisper-nonavx; then
        echo "running"
    elif docker ps -a | grep -q whisper-nonavx; then
        echo "stopped"
    else
        echo "not_created"
    fi
}

# 函數：顯示詳細狀態
show_detailed_status() {
    local status=$(get_container_status)
    
    echo -e "${BLUE}📊 容器狀態報告${NC}"
    echo "================================="
    
    case $status in
        "running")
            echo -e "狀態: ${GREEN}✅ 運行中${NC}"
            docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(NAMES|whisper)"
            ;;
        "stopped")
            echo -e "狀態: ${YELLOW}⏸️  已停止${NC}"
            docker ps -a --format "table {{.Names}}\t{{.Status}}" | grep -E "(NAMES|whisper)"
            ;;
        "not_created")
            echo -e "狀態: ${RED}❌ 未建立${NC}"
            ;;
    esac
    
    echo ""
    echo "磁碟使用量:"
    docker system df | head -2
    echo ""
}

# 函數：健康檢查
health_check() {
    local retries=0
    local max_retries=5
    
    while [ $retries -lt $max_retries ]; do
        if curl -s http://localhost:10300/health &> /dev/null; then
            local response=$(curl -s http://localhost:10300/health)
            show_status "${GREEN}✅ 服務健康檢查通過${NC}" "Health check passed"
            echo "回應: $response"
            return 0
        else
            retries=$((retries + 1))
            if [ $retries -lt $max_retries ]; then
                show_status "${YELLOW}⏳ 等待服務啟動... ($retries/$max_retries)${NC}" "Waiting for service to start"
                sleep 3
            fi
        fi
    done
    
    show_status "${RED}❌ 健康檢查失敗${NC}" "Health check failed"
    return 1
}

# 函數：啟動容器
start_container() {
    show_status "${BLUE}🚀 啟動容器...${NC}" "Starting container"
    
    if [ "$(get_container_status)" == "running" ]; then
        show_status "${YELLOW}⚠️  容器已在運行${NC}" "Container already running"
        return 0
    fi
    
    sudo docker-compose up -d
    
    show_status "${BLUE}⏳ 等待服務啟動...${NC}" "Waiting for service to start"
    sleep 5
    health_check
}

# 函數：停止容器
stop_container() {
    show_status "${BLUE}⏹️  停止容器...${NC}" "Stopping container"
    
    if [ "$(get_container_status)" != "running" ]; then
        show_status "${YELLOW}⚠️  容器未在運行${NC}" "Container not running"
        return 0
    fi
    
    sudo docker-compose down
    show_status "${GREEN}✅ 容器已停止${NC}" "Container stopped"
}

# 函數：重啟容器
restart_container() {
    show_status "${BLUE}🔄 重啟容器...${NC}" "Restarting container"
    stop_container
    sleep 2
    start_container
}

# 函數：重新建置
rebuild_container() {
    show_status "${BLUE}🔨 重新建置容器...${NC}" "Rebuilding container"
    
    sudo docker-compose down
    show_status "${BLUE}📦 建置新鏡像...${NC}" "Building new image"
    sudo docker-compose build --no-cache
    
    show_status "${BLUE}🚀 啟動新容器...${NC}" "Starting new container"
    sudo docker-compose up -d
    
    sleep 8
    health_check
}

# 函數：更新程式碼並重建
update_and_rebuild() {
    show_status "${BLUE}📥 更新程式碼...${NC}" "Updating code"
    
    cd "$SCRIPT_DIR"
    
    # 檢查是否有未提交的更改
    if [ -n "$(git status --porcelain)" ]; then
        show_status "${YELLOW}⚠️  發現本地修改，正在暫存...${NC}" "Stashing local changes"
        git stash
    fi
    
    # 拉取最新程式碼
    git pull origin main
    
    cd "$WHISPER_DIR"
    rebuild_container
}

# 函數：查看日誌
show_logs() {
    local follow_flag=""
    if [ "$1" == "-f" ] || [ "$1" == "--follow" ]; then
        follow_flag="-f"
        show_status "${BLUE}📋 持續顯示日誌 (Ctrl+C 停止)...${NC}" "Following logs"
    else
        show_status "${BLUE}📋 顯示最近日誌...${NC}" "Showing recent logs"
    fi
    
    sudo docker-compose logs $follow_flag whisper-nonavx
}

# 函數：清理
clean_all() {
    show_status "${YELLOW}🧹 清理所有容器和鏡像...${NC}" "Cleaning all containers and images"
    
    echo -e "${RED}警告: 這將刪除所有相關的容器和鏡像${NC}"
    read -p "確定要繼續嗎? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo docker-compose down --remove-orphans
        sudo docker system prune -f
        sudo docker volume prune -f
        show_status "${GREEN}✅ 清理完成${NC}" "Cleanup completed"
    else
        show_status "${BLUE}ℹ️  取消清理${NC}" "Cleanup cancelled"
    fi
}

# 函數：備份配置
backup_config() {
    local backup_dir="/tmp/whisper-backup-$(date +%Y%m%d-%H%M%S)"
    show_status "${BLUE}📦 備份配置到 $backup_dir${NC}" "Backing up configuration"
    
    mkdir -p "$backup_dir"
    cp -r "$SCRIPT_DIR"/* "$backup_dir/"
    
    show_status "${GREEN}✅ 備份完成: $backup_dir${NC}" "Backup completed"
    echo "備份位置: $backup_dir"
}

# 函數：持續監控
monitor_service() {
    show_status "${BLUE}👁️  開始持續監控 (Ctrl+C 停止)...${NC}" "Starting continuous monitoring"
    
    while true; do
        clear
        echo -e "${CYAN}🔍 Whisper 服務監控 - $(date)${NC}"
        echo "================================="
        
        # 顯示容器狀態
        show_detailed_status
        
        # 健康檢查
        echo -e "${BLUE}健康檢查:${NC}"
        if health_check &> /dev/null; then
            echo -e "  ${GREEN}✅ 服務正常${NC}"
        else
            echo -e "  ${RED}❌ 服務異常${NC}"
        fi
        
        # 顯示最近的日誌
        echo -e "\n${BLUE}最近日誌:${NC}"
        sudo docker-compose logs --tail 3 whisper-nonavx 2>/dev/null || echo "無法獲取日誌"
        
        echo -e "\n按 Ctrl+C 停止監控"
        sleep 10
    done
}

# 主程式
main() {
    # 檢查參數
    if [ $# -eq 0 ]; then
        show_usage
        exit 0
    fi
    
    # 檢查先決條件
    check_prerequisites
    
    # 執行命令
    case "$1" in
        "start")
            start_container
            ;;
        "stop")
            stop_container
            ;;
        "restart")
            restart_container
            ;;
        "rebuild")
            rebuild_container
            ;;
        "status")
            show_detailed_status
            ;;
        "logs")
            show_logs "$2"
            ;;
        "health")
            health_check
            ;;
        "update")
            update_and_rebuild
            ;;
        "clean")
            clean_all
            ;;
        "backup")
            backup_config
            ;;
        "monitor")
            monitor_service
            ;;
        "help"|"-h"|"--help")
            show_usage
            ;;
        *)
            echo -e "${RED}❌ 未知命令: $1${NC}"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

# 捕捉 Ctrl+C
trap 'echo -e "\n${YELLOW}操作已取消${NC}"; exit 0' INT

# 執行主程式
main "$@"