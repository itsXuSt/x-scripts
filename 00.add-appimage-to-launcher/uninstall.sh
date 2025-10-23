#!/bin/bash

# 卸载 AppImage 管理工具
# 用法: ./uninstall.sh

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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
    exit 1
}

echo "开始卸载 AppImage 管理工具..."

# 获取真实用户的家目录（处理 sudo 情况）
if [ "$EUID" -eq 0 ] && [ -n "$SUDO_USER" ]; then
    # 通过 sudo 执行，获取真实用户的家目录
    REAL_USER="$SUDO_USER"
    REAL_HOME=$(eval echo ~$SUDO_USER)
else
    # 普通用户执行
    REAL_USER="$USER"
    REAL_HOME="$HOME"
fi

# 根据是否以 root 权限运行来决定卸载路径
if [ "$EUID" -eq 0 ]; then
    # 以 root 权限运行（sudo 执行）
    echo -e "${YELLOW}检测到以 root 权限运行，将从系统目录卸载${NC}"
    echo -e "${YELLOW}同时也会清理用户 $REAL_USER 的 AppImage 应用数据${NC}"
    TARGET_BIN_DIR="/usr/local/bin"
    TARGET_SCRIPT="$TARGET_BIN_DIR/install-appimage.sh"
    CONF_DIR="/etc/deepin/context-menus"
    TARGET_CONF="$CONF_DIR/00.install-appimage.conf"
else
    # 普通用户运行
    echo -e "${YELLOW}以普通用户权限运行，将从用户目录卸载${NC}"
    TARGET_BIN_DIR="$REAL_HOME/.local/bin"
    TARGET_SCRIPT="$TARGET_BIN_DIR/install-appimage.sh"
    CONF_DIR="$REAL_HOME/.local/share/deepin/dde-file-manager/context-menus"
    TARGET_CONF="$CONF_DIR/00.install-appimage.conf"
fi

# 1. 移除脚本文件
if [ -f "$TARGET_SCRIPT" ]; then
    echo "移除脚本文件: $TARGET_SCRIPT"
    rm "$TARGET_SCRIPT" || error_exit "无法删除脚本文件 $TARGET_SCRIPT"
    echo -e "${GREEN}✓ 脚本文件已移除${NC}"
else
    echo -e "${YELLOW}脚本文件不存在，跳过: $TARGET_SCRIPT${NC}"
fi

# 2. 移除配置文件
if [ -f "$TARGET_CONF" ]; then
    echo "移除配置文件: $TARGET_CONF"
    rm "$TARGET_CONF" || error_exit "无法删除配置文件 $TARGET_CONF"
    echo -e "${GREEN}✓ 配置文件已移除${NC}"
else
    echo -e "${YELLOW}配置文件不存在，跳过: $TARGET_CONF${NC}"
fi

# 3. 询问用户是否移除已创建的 desktop 文件
# 使用真实用户的家目录（sudo 执行时也能正确定位到执行 sudo 的用户目录）
APPIMAGE_DIR="$REAL_HOME/.local/appimages"
APPLICATIONS_DIR="$REAL_HOME/.local/share/applications"
DESKTOP_DIR="$REAL_HOME/Desktop"

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}检测到已安装的 AppImage 应用${NC}"
echo -e "${BLUE}========================================${NC}"

# 查找所有符合条件的 desktop 文件
# 条件：在 ~/.local/share/applications/ 下存在，且在 ~/.local/appimages/ 下有对应的 appimage 文件
declare -a DESKTOP_FILES_TO_REMOVE
declare -a DESKTOP_LINKS_TO_REMOVE

if [ -d "$APPLICATIONS_DIR" ] && [ -d "$APPIMAGE_DIR" ]; then
    for desktop_file in "$APPLICATIONS_DIR"/*.desktop; do
        # 检查文件是否存在
        [ -f "$desktop_file" ] || continue

        # 提取 Exec 字段的值
        exec_line=$(grep "^Exec=" "$desktop_file" | head -n 1)
        exec_path="${exec_line#Exec=}"
        # 去掉可能的参数
        exec_path="${exec_path%% *}"

        # 检查 Exec 路径是否指向 ~/.local/appimages/ 目录
        if [[ "$exec_path" == "$APPIMAGE_DIR"* ]] && [ -f "$exec_path" ]; then
            DESKTOP_FILES_TO_REMOVE+=("$desktop_file")

            # 检查桌面上是否有对应的链接
            app_name=$(basename "$desktop_file")
            desktop_link="$DESKTOP_DIR/$app_name"
            if [ -L "$desktop_link" ] || [ -f "$desktop_link" ]; then
                DESKTOP_LINKS_TO_REMOVE+=("$desktop_link")
            fi
        fi
    done
fi

# 如果找到了需要移除的文件，询问用户
if [ ${#DESKTOP_FILES_TO_REMOVE[@]} -gt 0 ]; then
    echo "找到以下已安装的 AppImage 应用："
    echo ""
    for desktop_file in "${DESKTOP_FILES_TO_REMOVE[@]}"; do
        app_name=$(grep "^Name=" "$desktop_file" | head -n 1 | cut -d'=' -f2)
        echo "  • $app_name ($(basename "$desktop_file"))"
    done
    echo ""
    echo -e "${YELLOW}是否要移除这些应用的启动器条目？${NC}"
    echo "（AppImage 文件会被移动到 ~/Downloads/appimages 目录，不会删除）"
    echo ""
    read -p "请输入 [y/N]: " -r
    echo ""

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # 用户选择是，开始移除
        REMOVED_COUNT=0
        FAILED_COUNT=0

        # 移除 desktop 文件
        for desktop_file in "${DESKTOP_FILES_TO_REMOVE[@]}"; do
            if rm "$desktop_file" 2>/dev/null; then
                echo -e "${GREEN}✓ 已移除: $(basename "$desktop_file")${NC}"
                ((REMOVED_COUNT++))
            else
                echo -e "${RED}✗ 移除失败: $(basename "$desktop_file")${NC}"
                ((FAILED_COUNT++))
            fi
        done

        # 移除桌面链接
        for desktop_link in "${DESKTOP_LINKS_TO_REMOVE[@]}"; do
            if [ -L "$desktop_link" ] || [ -f "$desktop_link" ]; then
                rm "$desktop_link" 2>/dev/null
                echo -e "${GREEN}✓ 已移除桌面快捷方式: $(basename "$desktop_link")${NC}"
            fi
        done

        # 更新桌面数据库
        if command -v update-desktop-database &> /dev/null; then
            echo "更新桌面数据库..."
            update-desktop-database "$APPLICATIONS_DIR" 2>/dev/null
            echo -e "${GREEN}✓ 数据库更新成功${NC}"
        fi

        # 移动 appimages 目录到 Downloads
        if [ -d "$APPIMAGE_DIR" ]; then
            TARGET_BACKUP_DIR="$REAL_HOME/Downloads/appimages"

            # 如果目标已存在，添加时间戳后缀
            if [ -d "$TARGET_BACKUP_DIR" ]; then
                TIMESTAMP=$(date +%Y%m%d_%H%M%S)
                TARGET_BACKUP_DIR="$REAL_HOME/Downloads/appimages_$TIMESTAMP"
            fi

            echo "移动 AppImage 文件到: $TARGET_BACKUP_DIR"
            mkdir -p "$REAL_HOME/Downloads"
            mv "$APPIMAGE_DIR" "$TARGET_BACKUP_DIR" || error_exit "无法移动 appimages 目录"
            echo -e "${GREEN}✓ AppImage 文件已移动到: $TARGET_BACKUP_DIR${NC}"

            # 发送通知（需要以真实用户身份发送）
            notification_msg="已移除 $REMOVED_COUNT 个应用启动器条目\nAppImage 文件已移动到:\n$TARGET_BACKUP_DIR"
            if [ "$EUID" -eq 0 ] && [ -n "$SUDO_USER" ]; then
                # sudo 执行时，以真实用户身份发送通知
                sudo -u "$SUDO_USER" DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u "$SUDO_USER")/bus notify-send -u "normal" "AppImage 应用已移除" "$notification_msg"
            else
                send_notification "AppImage 应用已移除" "$notification_msg" "normal"
            fi
        fi

        echo ""
        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}已移除 $REMOVED_COUNT 个应用启动器条目${NC}"
        [ $FAILED_COUNT -gt 0 ] && echo -e "${RED}失败: $FAILED_COUNT 个${NC}"
        echo -e "${GREEN}AppImage 文件保存在: $TARGET_BACKUP_DIR${NC}"
        echo -e "${GREEN}========================================${NC}"
    else
        echo -e "${BLUE}已取消移除 AppImage 应用启动器条目${NC}"
    fi
else
    echo -e "${BLUE}未找到需要移除的 AppImage 应用${NC}"
fi

# 完成
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}卸载完成！${NC}"
echo -e "${GREEN}========================================${NC}"
echo "已卸载的组件："
echo "  • 脚本文件: $TARGET_SCRIPT"
echo "  • 配置文件: $TARGET_CONF"
[ ${#DESKTOP_FILES_TO_REMOVE[@]} -gt 0 ] && [[ $REPLY =~ ^[Yy]$ ]] && echo "  • AppImage 应用启动器条目: ${#DESKTOP_FILES_TO_REMOVE[@]} 个"
echo ""
echo -e "${YELLOW}提示: 如需使右键菜单变更生效，可能需要重启文件管理器${NC}"
echo -e "${GREEN}========================================${NC}"

exit 0
