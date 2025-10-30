#!/bin/bash
# Clash 卸载程序
# 作者: Auto
# 日期: 2025-10-30

set -e

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"

# 加载公共函数
source "$SCRIPT_DIR/lib/common.sh"

# 程序信息
PROGRAM_NAME="Clash 卸载程序"
VERSION="1.0.0"

# 显示欢迎信息
show_welcome() {
    clear
    echo -e "${RED}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║                                                              ║${NC}"
    echo -e "${RED}║                    ${WHITE}$PROGRAM_NAME${RED}                    ║${NC}"
    echo -e "${RED}║                        ${WHITE}版本 $VERSION${RED}                        ║${NC}"
    echo -e "${RED}║                                                              ║${NC}"
    echo -e "${RED}║  ${YELLOW}警告: 此操作将删除 Clash 及其相关文件${RED}                    ║${NC}"
    echo -e "${RED}║  ${YELLOW}请确保您已备份重要数据${RED}                                ║${NC}"
    echo -e "${RED}║                                                              ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# 检查安装状态
check_installation_status() {
    local clash_bin="$CLASH_BIN_DIR/clash"
    local config_file="$CLASH_CONFIG_DIR/config.yaml"
    local installed=false
    
    if [ -f "$clash_bin" ]; then
        echo -e "${GREEN}✓${NC} Clash 可执行文件: $clash_bin"
        installed=true
    fi
    
    if [ -f "$config_file" ]; then
        echo -e "${GREEN}✓${NC} 配置文件: $config_file"
        installed=true
    fi
    
    if [ -d "$CLASH_CONFIG_DIR" ]; then
        echo -e "${GREEN}✓${NC} 配置目录: $CLASH_CONFIG_DIR"
        installed=true
    fi
    
    # 检查 systemd 服务
    if is_root && command_exists systemctl; then
        local service_name=$(get_config_value "install.service_name" "clash")
        if systemctl list-unit-files | grep -q "$service_name.service"; then
            echo -e "${GREEN}✓${NC} systemd 服务: $service_name.service"
            installed=true
        fi
    fi
    
    if [ "$installed" = false ]; then
        warn "未检测到 Clash 安装"
        echo "可能的原因:"
        echo "  - Clash 未安装"
        echo "  - 安装在其他位置"
        echo "  - 配置文件损坏"
        echo ""
        if ! confirm "是否继续卸载？" "n"; then
            exit 0
        fi
    fi
    
    echo ""
}

# 显示系统信息
show_system_info() {
    info "系统信息:"
    echo "  操作系统: $(uname -s) $(uname -r)"
    echo "  架构: $(uname -m)"
    echo "  用户: $(whoami)"
    echo "  权限: $(is_root && echo "root" || echo "普通用户")"
    echo "  检测到的安装目录: $CLASH_BIN_DIR"
    echo "  检测到的配置目录: $CLASH_CONFIG_DIR"
    echo ""
}

# 主函数
main() {
    # 初始化
    init
    
    # 显示欢迎信息
    show_welcome
    
    # 显示系统信息
    show_system_info
    
    # 检查安装状态
    check_installation_status
    
    # 加载卸载逻辑
    source "$SCRIPT_DIR/lib/uninstaller.sh"
    
    # 执行卸载
    uninstall_clash
}

# 处理命令行参数
case "${1:-}" in
    --help|-h)
        echo "Clash 卸载程序"
        echo ""
        echo "用法: $0 [选项]"
        echo ""
        echo "选项:"
        echo "  --help, -h     显示此帮助信息"
        echo "  --quick, -q    快速卸载（无交互）"
        echo "  --version, -v  显示版本信息"
        echo ""
        exit 0
        ;;
    --version|-v)
        echo "$PROGRAM_NAME 版本 $VERSION"
        exit 0
        ;;
    --quick|-q)
        # 快速卸载模式
        init
        source "$SCRIPT_DIR/lib/uninstaller.sh"
        quick_uninstall
        exit 0
        ;;
    "")
        # 交互式卸载
        main
        ;;
    *)
        echo "未知选项: $1"
        echo "使用 --help 查看帮助信息"
        exit 1
        ;;
esac
