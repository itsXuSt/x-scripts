# Linux 实用脚本集合

一个包含多个 Linux 实用脚本的工具集，主要面向 Deepin/UOS 系统，提供各种自动化和便捷功能。

---

## 📑 目录

- [系统要求](#系统要求)
- [脚本模块](#脚本模块)
  - [AppImage 管理工具](#1-appimage-管理工具)
- [贡献指南](#贡献指南)
- [许可证](#许可证)

---

## 🖥️ 系统要求

**主要支持的操作系统：**
- Deepin 20/23/25
- UOS（统信操作系统）

> ⚠️ **注意**：大部分脚本针对 Deepin/UOS 系统进行了优化，部分功能依赖于这些系统的特定机制。

---

## 📦 脚本模块

### 1. AppImage 管理工具

> **目录：** `00.add-appimage-to-launcher/`
> **适用系统：** Deepin/UOS
> **功能：** 一键安装 AppImage 应用到系统启动器

#### ✨ 功能特性

- 📦 一键将 AppImage 添加到应用启动器
- 🖱️ 支持文件管理器右键菜单快速安装
- 🖼️ 自动利用文件管理器生成的缩略图作为应用图标
- 🎯 自动创建桌面快捷方式
- 🔄 智能检测重复安装
- 🗑️ 完善的卸载功能，支持批量清理
- 📢 桌面通知反馈安装/卸载状态

#### 📥 快速开始

**安装工具（普通用户）：**
```bash
cd 00.add-appimage-to-launcher
./install.sh
```

**安装工具（系统级）：**
```bash
cd 00.add-appimage-to-launcher
sudo ./install.sh
```

**使用方法：**

方式一：命令行
```bash
install-appimage.sh /path/to/your-app.AppImage
```

方式二：右键菜单（推荐）
1. 在文件管理器中右键点击 AppImage 文件
2. 选择"添加到启动器"
3. 等待安装完成通知

#### 🗑️ 卸载

**卸载工具（保留已安装的应用）：**
```bash
cd 00.add-appimage-to-launcher
./uninstall.sh
# 询问时输入 n
```

**完全卸载（移除所有已安装的应用）：**
```bash
cd 00.add-appimage-to-launcher
./uninstall.sh
# 询问时输入 y
```

#### 📁 安装后的文件结构

```
~/.local/
├── bin/
│   └── install-appimage.sh              # 安装脚本
├── appimages/                            # AppImage 存放目录
│   ├── App1.AppImage
│   └── App2.AppImage
└── share/
    ├── applications/                     # 桌面入口文件
    │   ├── App1.desktop
    │   └── App2.desktop
    └── deepin/
        └── dde-file-manager/
            └── context-menus/
                └── 00.install-appimage.conf  # 右键菜单配置
```

#### 🔧 工作原理

1. **检查文件**：验证 AppImage 文件是否存在和有效
2. **移动文件**：将 AppImage 移动到 `~/.local/appimages/` 目录
3. **提取图标**：利用 Deepin 文件管理器的缩略图算法计算图标路径
   ```bash
   FILE_URL="file://<appimage-path>"
   THUMB_MD5=$(echo -n "$FILE_URL" | md5sum)
   ICON_PATH="$HOME/.cache/thumbnails/large/${THUMB_MD5}.png"
   ```
4. **创建 Desktop 文件**：在 `~/.local/share/applications/` 创建启动器条目
5. **创建桌面快捷方式**：软链接到桌面目录
6. **更新数据库**：刷新应用启动器索引
7. **发送通知**：告知用户安装完成

#### ❓ 常见问题

<details>
<summary><b>Q: 右键菜单没有显示"添加到启动器"选项？</b></summary>

**A:** 尝试以下方法：
1. 重启文件管理器和桌面（或者直接重启系统）
2. 检查配置文件是否存在且格式正确
3. 确认 AppImage 文件的 MIME 类型是否正确
</details>

<details>
<summary><b>Q: 安装后应用图标显示不正确？</b></summary>

**A:** 可能的原因：
1. 文件管理器还未生成缩略图 - 脚本会等待 2 秒，但可能不够（建议等 appimage 文件已有缩略图之后再操作）
2. AppImage 文件本身不包含图标
3. 解决方法：可以手动编辑 `~/.local/share/applications/<app>.desktop` 文件，修改 `Icon=` 字段
</details>

<details>
<summary><b>Q: 可以在其他 Linux 发行版上使用吗？</b></summary>

**A:** 目前不支持。本工具依赖于 Deepin/UOS 特有的：
- 文件管理器右键菜单配置路径
- 缩略图生成算法
- 如需支持其他发行版，需要适配相应的配置路径和机制
</details>

<details>
<summary><b>Q: 卸载后 AppImage 文件在哪里？</b></summary>

**A:** 如果选择清理已安装的应用，AppImage 文件会被移动到 `~/Downloads/appimages/` 或 `~/Downloads/appimages_<时间戳>/`（如果目录已存在）。文件不会被删除，可以随时找回。
</details>

<details>
<summary><b>Q: 如何手动删除某个已安装的应用？</b></summary>

**A:** 手动清理步骤：
```bash
# 1. 删除 desktop 文件
rm ~/.local/share/applications/<app-name>.desktop

# 2. 删除桌面快捷方式
rm ~/Desktop/<app-name>.desktop

# 3. 删除 AppImage 文件
rm ~/.local/appimages/<app-name>.AppImage

# 4. 更新数据库
update-desktop-database ~/.local/share/applications
```
</details>

#### 📝 技术细节

- **开发语言**：Bash Shell
- **依赖工具**：
  - `md5sum` - 计算缩略图路径
  - `notify-send` - 发送桌面通知
  - `update-desktop-database` - 更新应用数据库
- **兼容性**：Deepin 20/23, UOS v20

---

## 🤝 贡献指南

欢迎提交 Issue 和 Pull Request！

### 贡献流程

1. Fork 本仓库
2. 创建你的功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交你的更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启一个 Pull Request

### 添加新模块

如果你想添加新的脚本模块，请遵循以下规范：

1. **目录命名**：使用 `XX.module-name/` 格式，其中 XX 为两位数字编号
2. **必需文件**：
   - `install.sh` - 安装脚本（如适用）
   - `uninstall.sh` - 卸载脚本（如适用）
   - 其他功能脚本
3. **文档**：在本 README 的"脚本模块"章节添加模块说明
4. **代码规范**：
   - 使用清晰的变量命名
   - 添加必要的注释
   - 提供友好的错误提示
   - 使用颜色输出增强可读性

---

## 📄 许可证

本项目采用开源许可证，具体请查看 LICENSE 文件。

---

## 🔗 相关链接

- [Deepin 官网](https://www.deepin.org/)
- [UOS 官网](https://www.chinauos.com/)
- [AppImage 官网](https://appimage.org/)

---

<p align="center">
  <b>祝你使用愉快！</b> 🎉
</p>
