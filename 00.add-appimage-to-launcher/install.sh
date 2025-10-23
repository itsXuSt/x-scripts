#!/bin/bash

# 安装 AppImage 管理工具
# 用法: ./install.sh

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 错误退出
error_exit() {
    echo -e "${RED}错误: $1${NC}" >&2
    exit 1
}

echo "开始安装 AppImage 管理工具..."

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 定义源文件和目标路径
SOURCE_SCRIPT="$SCRIPT_DIR/install-appimage.sh"
TARGET_BIN_DIR="$HOME/.local/bin"
TARGET_SCRIPT="$TARGET_BIN_DIR/install-appimage.sh"

CONF_DIR="$HOME/.local/share/deepin/dde-file-manager/context-menus"
TARGET_CONF="$CONF_DIR/00.install-appimage.conf"

# 检查源脚本是否存在
if [ ! -f "$SOURCE_SCRIPT" ]; then
    error_exit "找不到 install-appimage.sh 文件，请确保它在当前目录下"
fi

# 1. 安装脚本到 ~/.local/bin/
echo "安装脚本到 $TARGET_BIN_DIR..."

# 创建目标目录（如果不存在）
if [ ! -d "$TARGET_BIN_DIR" ]; then
    echo "创建目录: $TARGET_BIN_DIR"
    mkdir -p "$TARGET_BIN_DIR" || error_exit "无法创建目录 $TARGET_BIN_DIR"
fi

# 复制脚本文件
cp "$SOURCE_SCRIPT" "$TARGET_SCRIPT" || error_exit "无法复制脚本到 $TARGET_SCRIPT"

# 设置可执行权限
chmod +x "$TARGET_SCRIPT" || error_exit "无法设置可执行权限"

echo -e "${GREEN}✓ 脚本已安装到: $TARGET_SCRIPT${NC}"

# 2. 创建配置文件到文件管理器上下文菜单目录
echo "创建文件管理器右键菜单配置..."

# 创建目标目录（如果不存在）
if [ ! -d "$CONF_DIR" ]; then
    echo "创建目录: $CONF_DIR"
    mkdir -p "$CONF_DIR" || error_exit "无法创建目录 $CONF_DIR"
fi

# 写入配置文件
cat > "$TARGET_CONF" <<EOF
[Menu Entry]
Version=1.0
Actions=A1

[Menu Action A1]
Exec=$TARGET_SCRIPT %F
Name=Add to launchpad
Name[zh_CN]=添加到启动器
MimeType=application/vnd.appimage
X-DFM-MenuTypes=SingleFile
X-DFM-SupportSchemes=file
PosNum=1
Separator=Bottom
EOF

if [ $? -ne 0 ]; then
    error_exit "无法创建配置文件 $TARGET_CONF"
fi

echo -e "${GREEN}✓ 配置文件已创建: $TARGET_CONF${NC}"

# 检查 ~/.local/bin 是否在 PATH 中
if [[ ":$PATH:" != *":$TARGET_BIN_DIR:"* ]]; then
    echo ""
    echo -e "${YELLOW}注意: $TARGET_BIN_DIR 不在 PATH 环境变量中${NC}"
    echo "建议将以下内容添加到 ~/.bashrc 或 ~/.zshrc 中："
    echo ""
    echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo ""
    echo "然后执行: source ~/.bashrc (或 source ~/.zshrc)"
fi

# 完成
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}安装完成！${NC}"
echo -e "${GREEN}========================================${NC}"
echo "脚本位置: $TARGET_SCRIPT"
echo "配置位置: $TARGET_CONF"
echo ""
echo "使用方法："
echo "  1. 命令行: install-appimage.sh <appimage文件>"
echo "  2. 文件管理器: 右键 AppImage 文件 → 添加到启动器"
echo ""
echo -e "${YELLOW}提示: 如需使右键菜单生效，可能需要重启文件管理器${NC}"
echo -e "${GREEN}========================================${NC}"

exit 0
