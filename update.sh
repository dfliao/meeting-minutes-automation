#!/bin/bash

# 快速更新腳本 - 簡化版
# 使用方法: ./update.sh "修改說明"

set -e

# 顏色
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

MESSAGE=${1:-"feat: 更新系統配置"}

echo -e "${BLUE}🔄 快速更新程式到 GitHub${NC}"

# 1. 檢查狀態
if [ -n "$(git status --porcelain)" ]; then
    echo -e "${YELLOW}📝 發現更改，準備提交...${NC}"
    git status --short
else
    echo -e "${YELLOW}⚠️  沒有發現更改${NC}"
    exit 0
fi

# 2. 提交並推送
git add .
git commit -m "$MESSAGE

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>"

git push origin main

echo -e "${GREEN}✅ 更新完成！${NC}"
echo -e "${BLUE}📍 GitHub: https://github.com/dfliao/meeting-minutes-automation${NC}"