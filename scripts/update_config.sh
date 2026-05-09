#!/bin/bash
set -e

# Ask for confirmation
read -p "你确定要强制覆盖本地 Yazi 配置吗? (y/n) " -n 1 -r
echo    # (optional) move to a new line
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    echo "操作已取消。"
    exit 1
fi

# Navigate to the Yazi configuration directory
cd ~/.config/yazi || exit

# Fetch all remotes
echo "正在获取所有远程更新..."
git fetch --all

# Hard reset to origin/main
echo "正在强制重置到 origin/main..."
git reset --hard origin/main

# Clean untracked files and directories
echo "正在清理未跟踪的文件和目录..."
git clean -fd

echo "Yazi 配置更新成功！"
read -p "按回车键继续..."
