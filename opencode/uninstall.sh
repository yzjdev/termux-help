#!/usr/bin/env bash
#=============================================================
# OpenCode 一键卸载脚本（Termux 原生 glibc 版）
#
# 功能：
#   1. 自动检测 bash / zsh 双 shell 环境，移除 PATH 配置
#   2. 删除 opencode / ocrun 及全部版本压缩包
#   3. 可选卸载 glibc / glibc-repo 系统依赖
#=============================================================

set -euo pipefail

BIN_DIR="$HOME/.bin"
OCRUN="$BIN_DIR/ocrun"

# ---------- 终端配色 ----------
RESET='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
CYAN='\033[36m'

# ---------- 输出函数 ----------
step() {
    echo
    printf "${BOLD}${CYAN}%s${RESET}\n" "$1"
}

info() { printf "${CYAN}▸${RESET} %s\n" "$*"; }
ok()   { printf "${GREEN}✔${RESET} %s\n" "$*"; }
warn() { printf "${YELLOW}⚠${RESET} %s\n" "$*"; }
die()  { printf "${RED}✘${RESET} %s\n" "$*" >&2; exit 1; }

start_banner() {
    echo
    printf "${BOLD}${CYAN}✦ OpenCode 一键卸载${RESET}\n"
    printf "${DIM}${CYAN}Termux 原生 glibc 版${RESET}\n"
    echo
}

end_banner() {
    echo
    printf "${BOLD}${GREEN}✦ OpenCode 已卸载！${RESET}\n"
    printf "${GREEN}✔${RESET} 重启 Termux 后 PATH 变更完全生效\n"
    echo
}

#-------------------------------------------------------------
# 从 .bashrc / .zshrc 中移除 OpenCode 的 PATH 配置
#-------------------------------------------------------------
remove_path_entries() {
    local rc removed=0
    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
        [ -f "$rc" ] || continue
        if grep -qF "export PATH=\"$BIN_DIR" "$rc" 2>/dev/null; then
            sed -i "\|export PATH=\"$BIN_DIR:\$PATH\"|d" "$rc"
            ok "已从 $rc 移除 PATH 配置"
            removed=1
            # rc 文件已空则一并删除
            if [ ! -s "$rc" ]; then
                rm -f "$rc"
            fi
        fi
    done
    [ "$removed" -eq 1 ] || info ".bashrc / .zshrc 中未找到 OpenCode 的 PATH 配置"
}

main() {
    start_banner

    step "移除 PATH 配置"
    remove_path_entries
    # 当前会话立即生效（移除 PATH 中的 $BIN_DIR）
    PATH="${PATH//$BIN_DIR:/}"
    PATH="${PATH//:$BIN_DIR/}"
    export PATH

    step "删除安装文件"
    rm -f "$OCRUN" "$BIN_DIR/opencode" "$BIN_DIR"/opencode-*.tar.gz
    if rmdir "$BIN_DIR" 2>/dev/null; then
        ok "已删除 $BIN_DIR"
    else
        info "$BIN_DIR 非空，保留该目录"
    fi

    step "清理系统依赖（可选）"
    if [ -t 0 ]; then
        local ans
        read -r -p "是否同时卸载 glibc / glibc-repo？[y/N] " ans < /dev/tty || ans=""
        case "$ans" in
            y|Y|yes|YES)
                apt remove -y glibc 2>/dev/null || true
                apt remove -y glibc-repo 2>/dev/null || true
                ok "已卸载 glibc / glibc-repo"
                ;;
            *)
                info "跳过依赖清理"
                ;;
        esac
    else
        info "非交互式运行，跳过依赖清理"
    fi

    end_banner
}

main "$@"
