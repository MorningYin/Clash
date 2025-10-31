#!/bin/bash
# Clash 一键安装程序
# 作者: Auto
# 日期: 2025-10-30

set -e

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"

# 加载公共函数
source "$SCRIPT_DIR/lib/common.sh"

# 程序信息
PROGRAM_NAME="Clash 一键安装程序"
VERSION="1.0.0"

# 显示欢迎信息
show_welcome() {
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                                                              ║${NC}"
    echo -e "${BLUE}║                    ${WHITE}$PROGRAM_NAME${BLUE}                    ║${NC}"
    echo -e "${BLUE}║                        ${WHITE}版本 $VERSION${BLUE}                        ║${NC}"
    echo -e "${BLUE}║                                                              ║${NC}"
    echo -e "${BLUE}║  ${CYAN}功能特性:${BLUE}                                                ║${NC}"
    echo -e "${BLUE}║  ${WHITE}• 一键安装 Clash Premium (Mihomo)${BLUE}                        ║${NC}"
    echo -e "${BLUE}║  ${WHITE}• 支持本地安装包和网络下载${BLUE}                              ║${NC}"
    echo -e "${BLUE}║  ${WHITE}• 自动订阅更新和节点转换${BLUE}                                ║${NC}"
    echo -e "${BLUE}║  ${WHITE}• 支持 root 用户和普通用户${BLUE}                              ║${NC}"
    echo -e "${BLUE}║  ${WHITE}• 提供完整的管理工具${BLUE}                                    ║${NC}"
    echo -e "${BLUE}║                                                              ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# 显示系统信息
show_system_info() {
    info "系统信息:"
    echo "  操作系统: $(uname -s) $(uname -r)"
    echo "  架构: $(uname -m)"
    echo "  用户: $(whoami)"
    echo "  权限: $(is_root && echo "root" || echo "普通用户")"
    echo "  安装目录: $CLASH_BIN_DIR"
    echo "  配置目录: $CLASH_CONFIG_DIR"
    echo ""
}

# 检查安装状态
check_installation_status() {
    local clash_bin="$CLASH_BIN_DIR/clash"
    local config_file="$CLASH_CONFIG_DIR/config.yaml"
    
    if [ -f "$clash_bin" ] && [ -f "$config_file" ]; then
        warn "检测到 Clash 已安装"
        echo "  Clash 可执行文件: $clash_bin"
        echo "  配置文件: $config_file"
        echo ""
        
        if confirm "是否要重新安装？这将覆盖现有配置" "n"; then
            return 0
        else
            info "安装已取消"
            exit 0
        fi
    fi
}

# 显示安装选项
show_install_options() {
    echo -e "${YELLOW}安装选项:${NC}"
    echo "1. 完整安装 (推荐)"
    echo "   - 安装 Clash 核心程序"
    echo "   - 下载订阅并转换配置"
    echo "   - 设置自动更新"
    echo "   - 安装管理工具"
    echo "   - 配置环境变量"
    echo ""
    echo "2. 仅安装核心程序"
    echo "   - 只安装 Clash 可执行文件"
    echo "   - 不下载订阅"
    echo ""
    echo "3. 自定义安装"
    echo "   - 手动选择安装组件"
    echo ""
}

# 执行完整安装
do_full_install() {
    log_info "开始完整安装"
    
    # 加载安装逻辑
    source "$SCRIPT_DIR/lib/installer.sh"
    
    # 执行安装
    if install_clash; then
        success "Clash 核心程序安装完成"
    else
        error "Clash 核心程序安装失败"
        return 1
    fi
    
    # 安装 systemd 服务
    source "$SCRIPT_DIR/lib/manager.sh"
    install_systemd_service
    
    # 设置代理环境变量
    setup_proxy_env
    
    # 安装管理工具
    install_cli_tools
    
    success "完整安装完成"
}

# 仅安装核心程序
do_core_only_install() {
    log_info "开始核心程序安装"
    
    # 创建目录
    create_directory "$CLASH_BIN_DIR" "755"
    create_directory "$CLASH_CONFIG_DIR" "755"
    
    # 加载安装逻辑
    source "$SCRIPT_DIR/lib/installer.sh"
    
    # 安装 Clash 核心
    if install_clash_core; then
        success "Clash 核心程序安装完成"
    else
        error "Clash 核心程序安装失败"
        return 1
    fi
    
    # 安装 Country.mmdb
    install_country_mmdb
    
    # 生成配置文件
    generate_clash_config
    
    success "核心程序安装完成"
}

# 自定义安装
do_custom_install() {
    log_info "开始自定义安装"
    
    local components=()
    
    # 选择安装组件
    echo -e "${YELLOW}请选择要安装的组件:${NC}"
    echo ""
    
    if confirm "安装 Clash 核心程序？" "y"; then
        components+=("core")
    fi
    
    if confirm "下载并转换订阅配置？" "y"; then
        components+=("subscription")
    fi
    
    if confirm "设置自动更新？" "y"; then
        components+=("cron")
    fi
    
    if confirm "安装 systemd 服务？" "y"; then
        components+=("service")
    fi
    
    if confirm "设置代理环境变量？" "y"; then
        components+=("env")
    fi
    
    if confirm "安装管理工具？" "y"; then
        components+=("cli")
    fi
    
    if [ ${#components[@]} -eq 0 ]; then
        warn "没有选择任何组件，安装取消"
        return 0
    fi
    
    # 创建目录
    create_directory "$CLASH_BIN_DIR" "755"
    create_directory "$CLASH_CONFIG_DIR" "755"
    
    # 加载安装逻辑
    source "$SCRIPT_DIR/lib/installer.sh"
    source "$SCRIPT_DIR/lib/manager.sh"
    
    # 安装选定的组件
    for component in "${components[@]}"; do
        case "$component" in
            "core")
                install_clash_core
                install_country_mmdb
                generate_clash_config
                ;;
            "subscription")
                download_subscription
                create_update_script
                ;;
            "cron")
                setup_cron
                ;;
            "service")
                install_systemd_service
                ;;
            "env")
                setup_proxy_env
                ;;
            "cli")
                install_cli_tools
                ;;
        esac
    done
    
    success "自定义安装完成"
}

# 安装 CLI 工具
install_cli_tools() {
    log_info "安装 CLI 管理工具"
    
    local cli_tool="$CLASH_BIN_DIR/clash-cli"
    local share_dir="/usr/local/share/clash-installer"
    local share_lib_dir="$share_dir/lib"
    
    # 安装共享库，供 CLI 在任何工作目录下引用
    mkdir -p "$share_lib_dir"
    cp -r "$SCRIPT_DIR/lib/"* "$share_lib_dir/" 2>/dev/null || true
    chmod -R 755 "$share_lib_dir" 2>/dev/null || true
    
    # 若项目中已有增强版 CLI，则直接安装；否则生成基础版
    if [ -f "$SCRIPT_DIR/bin/clash-cli" ]; then
        cp "$SCRIPT_DIR/bin/clash-cli" "$cli_tool"
        sed -i "1i LIB_DIR=\"$share_lib_dir\"" "$cli_tool" 2>/dev/null || true
    else
        # 创建基础版 CLI 工具（无系统代理菜单）
        cat > "$cli_tool" << 'EOF'
#!/bin/bash
# Clash CLI 管理工具
# 由 Clash 安装程序自动生成

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLASH_CONFIG_DIR=""

# 检测配置目录
if [ -d "/etc/clash" ]; then
    CLASH_CONFIG_DIR="/etc/clash"
elif [ -d "$HOME/.config/clash" ]; then
    CLASH_CONFIG_DIR="$HOME/.config/clash"
else
    echo "错误: 找不到 Clash 配置目录"
    exit 1
fi

# 加载管理函数
if [ -n "$LIB_DIR" ] && [ -f "$LIB_DIR/manager.sh" ]; then
    source "$LIB_DIR/manager.sh"
else
    # 默认共享库路径
    if [ -f "/usr/local/share/clash-installer/lib/manager.sh" ]; then
        source "/usr/local/share/clash-installer/lib/manager.sh"
    else
    echo "错误: 找不到管理函数库"
    exit 1
    fi
fi

# 显示主菜单
show_menu() {
    clear
    echo -e "\033[0;34m╔══════════════════════════════════════════════════════════════╗\033[0m"
    echo -e "\033[0;34m║                    Clash 管理面板                           ║\033[0m"
    echo -e "\033[0;34m╚══════════════════════════════════════════════════════════════╝\033[0m"
    echo ""
    echo "1. 启动服务"
    echo "2. 停止服务"
    echo "3. 重启服务"
    echo "4. 查看状态"
    echo "5. 更新订阅"
    echo "6. 查看日志"
    echo "7. 测试连接"
    echo "8. 代理设置"
    echo "9. 节点管理"
    echo "10. 系统代理 (开/关)"
    echo "0. 退出"
    echo ""
}

# 主循环
main() {
    while true; do
        show_menu
        read -p "请选择操作 [0-10]: " choice
        
        case $choice in
            1)
                start_service
                read -p "按回车键继续..."
                ;;
            2)
                stop_service
                read -p "按回车键继续..."
                ;;
            3)
                restart_service
                read -p "按回车键继续..."
                ;;
            4)
                show_service_info
                read -p "按回车键继续..."
                ;;
            5)
                update_subscription
                read -p "按回车键继续..."
                ;;
            6)
                view_logs
                read -p "按回车键继续..."
                ;;
            7)
                test_connection
                read -p "按回车键继续..."
                ;;
            8)
                setup_proxy_env
                read -p "按回车键继续..."
                ;;
            9)
                echo "节点管理功能开发中..."
                read -p "按回车键继续..."
                ;;
            10)
                if type enable_system_proxy >/dev/null 2>&1; then
                    clear; echo "1. 开启（自动）  2. 关闭（自动）  3. 仅用户开  4. 仅用户关  5. 仅系统开  6. 仅系统关  0. 返回"; read -p "选择: " op;
                    case "$op" in
                        1) enable_system_proxy;;
                        2) disable_system_proxy;;
                        3) proxy_on --user;;
                        4) proxy_off --user;;
                        5) proxy_on --system;;
                        6) proxy_off --system;;
                        0) :;;
                        *) echo "无效选择";;
                    esac
                    read -p "按回车键继续..."
                else
                    echo "系统代理功能不可用"; read -p "按回车键继续..."
                fi
                ;;
            0)
                echo "再见！"
                exit 0
                ;;
            *)
                echo "无效选择，请重试"
                sleep 1
                ;;
        esac
    done
}

# 运行主程序
main "$@"
EOF
    fi
    
    chmod +x "$cli_tool"
    success "CLI 工具安装成功: $cli_tool"
}

# 显示安装结果
show_install_result() {
    echo ""
    success "安装完成！"
    echo ""
    
    # 显示服务信息
    source "$SCRIPT_DIR/lib/manager.sh"
    show_service_info
    
    # 显示使用说明
    echo -e "${YELLOW}使用说明:${NC}"
    echo ""
    echo "1. 启动服务:"
    echo "   clash-cli"
    echo "   或直接运行: $CLASH_BIN_DIR/clash -d $CLASH_CONFIG_DIR"
    echo ""
    echo "2. 管理服务:"
    echo "   clash-cli start    # 启动代理"
    echo "   clash-cli stop     # 停止代理"
    echo "   clash-cli status   # 查看状态"
    echo "   clash-cli          # 交互式管理界面"
    echo ""
    
    # 显示配置文件位置
    echo -e "${YELLOW}配置文件:${NC}"
    echo "  主配置: $CLASH_CONFIG_DIR/config.yaml"
    echo "  日志文件: $CLASH_CONFIG_DIR/clash.log"
    echo ""
    
    # 显示代理信息
    local http_port=$(get_config_value "install.http_port" "7890")
    local socks_port=$(get_config_value "install.socks_port" "7891")
    local api_port=$(get_config_value "install.api_port" "9090")
    
    echo -e "${YELLOW}代理信息:${NC}"
    echo "  HTTP 代理: http://127.0.0.1:$http_port"
    echo "  SOCKS5 代理: socks5://127.0.0.1:$socks_port"
    echo "  管理面板: http://127.0.0.1:$api_port"
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
    
    # 显示安装选项
    show_install_options
    
    # 选择安装方式
    while true; do
        read -p "请选择安装方式 [1-3]: " choice
        case $choice in
            1)
                do_full_install
                break
                ;;
            2)
                do_core_only_install
                break
                ;;
            3)
                do_custom_install
                break
                ;;
            *)
                echo "无效选择，请重试"
                ;;
        esac
    done
    
    # 显示安装结果
    show_install_result
}

# 运行主程序
main "$@"
