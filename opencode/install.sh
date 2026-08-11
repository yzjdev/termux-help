#!/usr/bin/env bash
#=============================================================
# OpenCode 一键安装脚本（Termux 原生 glibc 版，无 proot）
#
# 特性：
#   1. 安装 glibc-repo / glibc（软件源更新改为手动执行）
#   2. 自动获取 OpenCode 最新版本（跳过已安装版本）
#   3. 仅支持 arm64 架构
#   4. 自动检测 bash / zsh 双 shell 环境，写入对应的 rc 文件并自动 source
#   5. 压缩包按版本号命名，避免重复下载，发布新版本时自动清理旧版本
#=============================================================

set -euo pipefail

BIN_DIR="$HOME/.bin"
OCRUN="$BIN_DIR/ocrun"
LD_SO="${PREFIX:-/data/data/com.termux/files/usr}/glibc/bin/ld.so"
REPO="anomalyco/opencode"

# ---------- 终端配色 ----------
RESET='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
CYAN='\033[36m'

# ---------- 输出函数 ----------
STEP=0
TOTAL_STEPS=8

step() {
    STEP=$((STEP + 1))
    echo
    printf "${BOLD}${CYAN}步骤 %s/%s：%s${RESET}\n" "$STEP" "$TOTAL_STEPS" "$1"
}

info() { printf "${CYAN}▸${RESET} %s\n" "$*"; }
ok()   { printf "${GREEN}✔${RESET} %s\n" "$*"; }
warn() { printf "${YELLOW}⚠${RESET} %s\n" "$*"; }
die()  { printf "${RED}✘${RESET} %s\n" "$*" >&2; exit 1; }

start_banner() {
    echo
    printf "${BOLD}${CYAN}✦ OpenCode 一键安装${RESET}\n"
    printf "${DIM}${CYAN}Termux 原生 glibc 版 · 仅支持 arm64${RESET}\n"
    echo
}

end_banner() {
    echo
    printf "${BOLD}${GREEN}✦ OpenCode 安装完成！${RESET}\n"
    printf "${GREEN}✔${RESET} 启动命令 : ${BOLD}ocrun${RESET}\n"
    printf "${GREEN}✔${RESET} 耗时     : ${BOLD}%ss${RESET}\n" "$SECONDS"
    echo
}

#-------------------------------------------------------------
# 自动检测当前 shell，确定要写入的 rc 配置文件
# 判断顺序：$SHELL 环境变量 → 已有 rc 文件兜底
#-------------------------------------------------------------
detect_shell_rc() {
    local sh_name
    sh_name="$(basename "${SHELL:-}")"

    case "$sh_name" in
        zsh)
            RC_FILE="$HOME/.zshrc"
            RC_NAME="zsh"
            ;;
        bash)
            RC_FILE="$HOME/.bashrc"
            RC_NAME="bash"
            ;;
        *)
            # $SHELL 无法判断时，按已安装的 shell / 已有配置文件兜底
            if command -v zsh >/dev/null 2>&1 && [ -f "$HOME/.zshrc" ]; then
                RC_FILE="$HOME/.zshrc"
                RC_NAME="zsh"
            else
                RC_FILE="$HOME/.bashrc"
                RC_NAME="bash"
            fi
            ;;
    esac
}

main() {
    SECONDS=0
    start_banner

    # ---------- 步骤 1：自动检测 shell ----------
    step "自动检测 shell 环境"
    detect_shell_rc
    ok "检测到 $RC_NAME（$RC_FILE）"

    # ---------- 步骤 2：安装系统依赖 ----------
    step "安装系统依赖"
    info "如需更新软件源，请先手动执行: apt update && apt upgrade"
    info "安装 glibc-repo / glibc"
    apt install -y glibc-repo
    apt install -y glibc

    # ---------- 步骤 3：创建 .bin 目录 ----------
    step "创建二进制目录"
    mkdir -p "$BIN_DIR"
    ok "目录: $BIN_DIR"

    # ---------- 步骤 4：检测架构 ----------
    step "检测 CPU 架构"
    local arch
    arch="$(uname -m)"
    case "$arch" in
        aarch64|arm64) PKG="opencode-linux-arm64.tar.gz" ;;
        *) die "不支持的架构: $arch（本脚本仅支持 arm64）" ;;
    esac
    ok "架构: $arch"

    # ---------- 步骤 5：获取最新版本并下载解压 ----------
    step "获取最新版本并下载解压"
    local latest tarball
    info "获取最新版本 ..."
    latest="$(curl -fsSIL "https://github.com/$REPO/releases/latest" \
        | grep -i '^location:' | tail -1 \
        | sed 's|.*/tag/||' | tr -d '\r' || true)"
    [ -n "$latest" ] || die "无法获取 OpenCode 最新版本，请检查网络"
    tarball="$BIN_DIR/opencode-$latest.tar.gz"
    info "最新版本: v$latest"

    if [ -f "$tarball" ] && [ -x "$BIN_DIR/opencode" ]; then
        info "已安装 v$latest，跳过"
    else
        if [ ! -f "$tarball" ]; then
            info "下载 $PKG ..."
            curl -fL --retry 3 -o "$tarball" \
                "https://github.com/$REPO/releases/download/$latest/$PKG"
        else
            info "复用本地 $tarball"
        fi

        info "解压 opencode 到 $BIN_DIR ..."
        tar -xzf "$tarball" -C "$BIN_DIR" opencode
        ok "OpenCode v$latest 安装完成"

        # 只保留当前版本，删除旧版本压缩包
        local old
        for old in "$BIN_DIR"/opencode-*.tar.gz; do
            [ -e "$old" ] || continue
            [ "$old" = "$tarball" ] && continue
            info "删除旧版本压缩包: $(basename "$old")"
            rm -f "$old"
        done
    fi

    # ---------- 步骤 6：生成 ocrun 启动脚本并赋权 ----------
    step "生成 ocrun 启动脚本"
    printf 'unset LD_PRELOAD && %s %s/opencode "$@"\n' "$LD_SO" "$BIN_DIR" > "$OCRUN"
    chmod 0755 "$BIN_DIR/opencode" "$OCRUN"
    ok "已生成 $OCRUN 并赋予可执行权限"

    # ---------- 步骤 7：写入 PATH ----------
    step "写入 PATH 配置"
    if grep -qF "export PATH=\"$BIN_DIR" "$RC_FILE" 2>/dev/null; then
        info "$RC_FILE 已包含 PATH 配置，跳过写入"
    else
        printf 'export PATH="%s:$PATH"\n' "$BIN_DIR" >> "$RC_FILE"
        ok "已写入 $RC_FILE"
    fi

    # ---------- 步骤 8：自动 source ----------
    step "自动 source 生效"
    export PATH="$BIN_DIR:$PATH"
    # 临时关闭严格模式；zsh 专属语法报错会被忽略，PATH 行仍可生效
    set +eu
    # shellcheck disable=SC1090
    source "$RC_FILE" 2>/dev/null || true
    set -eu
    ok "已 source $RC_FILE"

    end_banner
}

main "$@"
