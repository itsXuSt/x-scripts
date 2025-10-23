#!/bin/bash

# AppImage 安装脚本
# 用法: ./install-appimage.sh <appimage文件>

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 发送系统通知
send_notification() {
    local title="$1"
    local message="$2"
    local urgency="${3:-normal}"
    notify-send -u "$urgency" "$title" "$message"
}

# 错误退出
error_exit() {
    echo -e "${RED}错误: $1${NC}" >&2
    send_notification "AppImage 安装失败" "$1" "critical"
    exit 1
}

# 检查参数
if [ $# -ne 1 ]; then
    error_exit "请提供一个 AppImage 文件作为参数\n用法: $0 <appimage文件>"
fi

APPIMAGE_FILE="$1"

# 检查文件是否存在
if [ ! -f "$APPIMAGE_FILE" ]; then
    error_exit "文件不存在: $APPIMAGE_FILE"
fi

# 检查是否为 AppImage 文件
if [[ ! "$APPIMAGE_FILE" =~ \.appimage$ ]] && [[ ! "$APPIMAGE_FILE" =~ \.AppImage$ ]]; then
    echo -e "${YELLOW}警告: 文件扩展名不是 .appimage 或 .AppImage${NC}"
fi

# 获取文件绝对路径和文件名
APPIMAGE_FILE="$(realpath "$APPIMAGE_FILE")"
FILENAME="$(basename "$APPIMAGE_FILE")"
APPNAME="${FILENAME%.*}"  # 去掉扩展名作为应用名

# 定义目标目录
APPIMAGE_DIR="$HOME/.local/appimages"
ICONS_DIR="$HOME/.local/appimages/.icons"
APPLICATIONS_DIR="$HOME/.local/share/applications"
DESKTOP_DIR="$HOME/Desktop"

# 检查文件是否已经在安装目录中
APPIMAGE_DIR_REAL="$(realpath "$APPIMAGE_DIR" 2>/dev/null || echo "$APPIMAGE_DIR")"
APPIMAGE_FILE_DIR="$(dirname "$APPIMAGE_FILE")"

if [ "$APPIMAGE_FILE_DIR" = "$APPIMAGE_DIR_REAL" ]; then
    echo -e "${YELLOW}文件已位于安装目录中，无需移动${NC}"
#    send_notification "AppImage 已在安装目录" "$FILENAME 已经位于 $APPIMAGE_DIR 中" "normal"
    exit 0
fi

echo "开始安装 AppImage: $FILENAME"

# 1. 创建 appimages 目录和图标目录
if [ ! -d "$APPIMAGE_DIR" ]; then
    echo "创建目录: $APPIMAGE_DIR"
    mkdir -p "$APPIMAGE_DIR" || error_exit "无法创建目录 $APPIMAGE_DIR"
fi

if [ ! -d "$ICONS_DIR" ]; then
    echo "创建图标目录: $ICONS_DIR"
    mkdir -p "$ICONS_DIR" || error_exit "无法创建目录 $ICONS_DIR"
fi

chmod +x "$APPIMAGE_FILE" || error_exit "无法设置文件可执行权限"

# 2. 检查目标文件是否已存在
TARGET_FILE="$APPIMAGE_DIR/$FILENAME"
if [ -f "$TARGET_FILE" ]; then
    send_notification "AppImage 已存在" "$FILENAME 已经安装过了！" "normal"
    error_exit "$FILENAME 已存在于 $APPIMAGE_DIR\n如需重新安装，请先删除已有文件"
fi

# 2.1 移动文件到目标目录
echo "移动文件到: $APPIMAGE_DIR"
mv "$APPIMAGE_FILE" "$TARGET_FILE" || error_exit "无法移动文件到 $TARGET_FILE"

# 设置可执行权限
chmod +x "$TARGET_FILE" || error_exit "无法设置文件可执行权限"

echo -e "${GREEN}文件已移动并设置可执行权限${NC}"

# 3. 提取图标
echo "开始提取应用图标..."

# 目标图标路径
ICON_PATH="$ICONS_DIR/${APPNAME}.png"
ICON_FOUND=false

# 方案1: 从 AppImage 解压提取 PNG 图标
echo "尝试从 AppImage 提取图标..."
TEMP_EXTRACT_DIR=$(mktemp -d)

# 使用 --appimage-extract 解压到临时目录
cd "$TEMP_EXTRACT_DIR" || error_exit "无法进入临时目录"

# 尝试提取文件（重定向错误输出，避免干扰）
if "$TARGET_FILE" --appimage-extract 2>/dev/null 1>/dev/null; then
    # 在解压的 squashfs-root 顶层目录中查找 PNG 图标
    if [ -d "squashfs-root" ]; then
        # 只在顶层目录查找 PNG 文件（不递归），优先选择尺寸较大的图标
        FOUND_PNG=$(find squashfs-root -maxdepth 1 -type f -name "*.png" 2>/dev/null | while read png_file; do
            # 获取文件大小
            size=$(stat -c%s "$png_file" 2>/dev/null || echo 0)
            echo "$size $png_file"
        done | sort -rn | head -1 | cut -d' ' -f2-)

        if [ -n "$FOUND_PNG" ] && [ -f "$FOUND_PNG" ]; then
            echo "找到图标: $FOUND_PNG"
            cp "$FOUND_PNG" "$ICON_PATH" && ICON_FOUND=true
            echo -e "${GREEN}成功从 AppImage 提取图标${NC}"
        fi
    fi
fi

# 清理临时目录
cd - > /dev/null
rm -rf "$TEMP_EXTRACT_DIR"

# 方案2: 如果没有找到 PNG，尝试使用文管缩略图
if [ "$ICON_FOUND" = false ]; then
    echo "未找到 PNG 图标，尝试使用文管缩略图..."

    # 构造缩略图路径（基于原始文件路径）
    FILE_URL="file://${APPIMAGE_FILE}"

    if command -v md5sum &> /dev/null; then
        THUMB_MD5=$(echo -n "$FILE_URL" | md5sum | cut -d' ' -f1)
        THUMB_PATH="$HOME/.cache/thumbnails/large/${THUMB_MD5}.png"

        if [ -f "$THUMB_PATH" ]; then
            echo "找到文管缩略图: $THUMB_PATH"
            cp "$THUMB_PATH" "$ICON_PATH" && ICON_FOUND=true
            echo -e "${GREEN}成功使用文管缩略图${NC}"
        else
            echo "文管缩略图不存在"
        fi
    fi
fi

# 方案3: 使用默认图标
if [ "$ICON_FOUND" = false ]; then
    echo -e "${YELLOW}未找到图标文件，使用系统默认图标${NC}"
    ICON_PATH="application-x-executable"
fi

# 4. 创建 .desktop 文件
echo "创建桌面入口文件..."

# 确保 applications 目录存在
mkdir -p "$APPLICATIONS_DIR" || error_exit "无法创建目录 $APPLICATIONS_DIR"

DESKTOP_FILE="$APPLICATIONS_DIR/${APPNAME}.desktop"

# 生成 .desktop 文件内容
cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Exec=$TARGET_FILE
GenericName=$APPNAME
Icon=$ICON_PATH
Name=$APPNAME
Terminal=false
Type=Application
Categories=Utility;
EOF

if [ $? -ne 0 ]; then
    error_exit "无法创建 .desktop 文件"
fi

echo -e "${GREEN}已创建 .desktop 文件: $DESKTOP_FILE${NC}"

# 更新桌面数据库
echo "更新桌面数据库..."
if command -v update-desktop-database &> /dev/null; then
    update-desktop-database "$APPLICATIONS_DIR" 2>/dev/null
    echo -e "${GREEN}数据库更新成功${NC}"
else
    echo -e "${YELLOW}警告: update-desktop-database 命令未找到${NC}"
fi

# 创建桌面快捷方式（软链接）
if [ -d "$DESKTOP_DIR" ]; then
    echo "创建桌面快捷方式..."
    DESKTOP_LINK="$DESKTOP_DIR/${APPNAME}.desktop"

    # 如果桌面上已有同名快捷方式，先删除
    [ -L "$DESKTOP_LINK" ] && rm "$DESKTOP_LINK"

    ln -s "$DESKTOP_FILE" "$DESKTOP_LINK" || echo -e "${YELLOW}警告: 无法创建桌面快捷方式${NC}"

    # 设置桌面文件为可信任（某些桌面环境需要）
    if command -v gio &> /dev/null; then
        gio set "$DESKTOP_LINK" metadata::trusted true 2>/dev/null
    fi

    echo -e "${GREEN}桌面快捷方式已创建${NC}"
else
    echo -e "${YELLOW}桌面目录不存在，跳过创建桌面快捷方式${NC}"
fi

# 4. 发送成功通知
send_notification "AppImage 已添加到启动器" "$APPNAME 可以从应用菜单或桌面快捷方式启动" "normal"

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}安装完成！${NC}"
echo -e "${GREEN}========================================${NC}"
echo "应用名称: $APPNAME"
echo "安装位置: $TARGET_FILE"
echo "桌面文件: $DESKTOP_FILE"
echo "启动方式: 从应用菜单搜索 '$APPNAME' 或点击桌面快捷方式"
echo -e "${GREEN}========================================${NC}"

exit 0
