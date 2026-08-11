# termux-help

Termux 常用工具的一键安装与帮助脚本集合。

## 目录

- [opencode/](opencode/) — OpenCode 官方版自动安装脚本（支持架构识别、版本检查、断点复用）

## 快速开始

### 安装 OpenCode

在 Termux 中粘贴以下命令一键安装：

```bash
curl -fsSL https://raw.githubusercontent.com/yzjdev/termux-help/main/opencode/install.sh | bash
```

安装完成后脚本会自动 source 对应的配置文件，然后使用 `ocrun` 启动 OpenCode。

> 提示：脚本不再自动更新软件源，首次安装请先手动执行 `apt update && apt upgrade`。

### 手动安装

```bash
git clone https://github.com/yzjdev/termux-help.git
bash termux-help/opencode/install.sh
```

### 卸载 OpenCode

在 Termux 中粘贴以下命令一键卸载：

```bash
curl -fsSL https://raw.githubusercontent.com/yzjdev/termux-help/main/opencode/uninstall.sh | bash
```

脚本会自动移除 rc 文件中的 PATH 配置、删除安装文件，并可选择是否卸载 glibc 依赖。

## 依赖

- `curl`、`wget`、`tar`：`pkg install curl wget tar`

## 脚本说明

| 脚本 | 说明 |
| --- | --- |
| `opencode/install.sh` | 原生 glibc（无 proot）一键安装：安装 glibc-repo/glibc（软件源更新改为手动执行）、获取最新版本、仅支持 arm64 架构、压缩包按版本号命名避免重复下载、新版本发布时自动清理旧版本、自动检测 bash/zsh 并 source 生效 |
| `opencode/uninstall.sh` | 一键卸载：自动移除 bash/zsh 的 rc 文件中的 PATH 配置、删除 opencode/ocrun 及全部版本压缩包，可选卸载 glibc/glibc-repo 依赖 |
