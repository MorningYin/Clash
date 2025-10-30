#!/bin/bash
# Clash 卸载逻辑
# 作者: Auto
# 日期: 2025-10-30

# 加载公共函数
UNINSTALLER_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$UNINSTALLER_LIB_DIR/common.sh"

# 卸载选项
UNINSTALL_MODE="full"  # full, config_only, keep_config

# 显示卸载选项
show_uninstall_options() {
    echo -e "${YELLOW}卸载选项:${NC}"
    echo "1. 完全卸载 (推荐)"
    echo "   - 停止并删除服务"
    echo "   - 删除所有文件"
    echo "   - 清理环境变量"
    echo "   - 删除定时任务"
    echo ""
    echo "2. 仅删除配置文件"
    echo "   - 保留 Clash 可执行文件"
    echo "   - 删除配置和日志"
    echo "   - 停止服务"
    echo ""
    echo "3. 保留配置文件"
    echo "   - 仅停止服务"
    echo "   - 保留所有文件"
    echo "   - 可重新启动"
    echo ""
}

# 停止服务
stop_clash_service() {
    log_info "停止 Clash 服务"
    
    # 停止 systemd 服务
    if is_root && command_exists systemctl; then
        local service_name=$(get_config_value "install.service_name" "clash")
        if systemctl is-active --quiet "$service_name" 2>/dev/null; then
            systemctl stop "$service_name"
            log_info "systemd 服务已停止"
        fi
    fi
    
    # 停止直接运行的服务
    local pid_file="$CLASH_CONFIG_DIR/clash.pid"
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if ps -p "$pid" > /dev/null 2>&1; then
            log_info "停止 Clash 进程 (PID: $pid)"
            kill "$pid" 2>/dev/null || true
            
            # 等待进程结束
            for i in {1..10}; do
                if ! ps -p "$pid" > /dev/null 2>&1; then
                    break
                fi
                sleep 1
            done
            
            # 强制停止
            if ps -p "$pid" > /dev/null 2>&1; then
                kill -9 "$pid" 2>/dev/null || true
            fi
        fi
        rm -f "$pid_file"
    fi
    
    success "Clash 服务已停止"
}

# 卸载 systemd 服务
uninstall_systemd_service() {
    if ! is_root; then
        log_info "非 root 用户，跳过 systemd 服务卸载"
        return 0
    fi
    
    if ! command_exists systemctl; then
        log_info "systemd 不可用，跳过服务卸载"
        return 0
    fi
    
    log_info "卸载 systemd 服务"
    
    local service_name=$(get_config_value "install.service_name" "clash")
    local service_file="/etc/systemd/system/${service_name}.service"
    
    # 停止并禁用服务
    systemctl stop "$service_name" 2>/dev/null || true
    systemctl disable "$service_name" 2>/dev/null || true
    
    # 删除服务文件
    if [ -f "$service_file" ]; then
        rm -f "$service_file"
        log_info "删除服务文件: $service_file"
    fi
    
    # 重新加载 systemd
    systemctl daemon-reload
    
    success "systemd 服务已卸载"
}

# 删除文件
remove_files() {
    log_info "删除 Clash 文件"
    
    # 删除可执行文件
    local clash_bin="$CLASH_BIN_DIR/clash"
    if [ -f "$clash_bin" ]; then
        rm -f "$clash_bin"
        log_info "删除可执行文件: $clash_bin"
    fi
    
    # 删除 CLI 工具
    local cli_tool="$CLASH_BIN_DIR/clash-cli"
    if [ -f "$cli_tool" ]; then
        rm -f "$cli_tool"
        log_info "删除 CLI 工具: $cli_tool"
    fi
    
    # 删除配置目录
    if [ -d "$CLASH_CONFIG_DIR" ]; then
        if [ "$UNINSTALL_MODE" = "full" ]; then
            rm -rf "$CLASH_CONFIG_DIR"
            log_info "删除配置目录: $CLASH_CONFIG_DIR"
        elif [ "$UNINSTALL_MODE" = "config_only" ]; then
            # 只删除配置文件，保留目录
            find "$CLASH_CONFIG_DIR" -name "*.yaml" -o -name "*.log" -o -name "*.pid" -o -name "*.sh" | xargs rm -f
            log_info "删除配置文件: $CLASH_CONFIG_DIR"
        fi
    fi
    
    success "文件删除完成"
}

# 清理环境变量
cleanup_environment() {
    log_info "清理环境变量"
    
    # 查找并清理 shell 配置文件
    local shell_configs=("$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile")
    
    for config_file in "${shell_configs[@]}"; do
        if [ -f "$config_file" ]; then
            # 备份原文件
            cp "$config_file" "${config_file}.clash-backup-$(date +%Y%m%d-%H%M%S)"
            
            # 删除 Clash 相关行
            sed -i '/clash/d' "$config_file" 2>/dev/null || true
            sed -i '/proxy-env.sh/d' "$config_file" 2>/dev/null || true
            
            log_info "清理配置文件: $config_file"
        fi
    done
    
    success "环境变量清理完成"
}

# 清理定时任务
cleanup_cron() {
    log_info "清理定时任务"
    
    # 删除包含 update-subscription.sh 的定时任务
    if crontab -l 2>/dev/null | grep -q "update-subscription.sh"; then
        crontab -l 2>/dev/null | grep -v "update-subscription.sh" | crontab -
        log_info "删除定时任务"
    fi
    
    success "定时任务清理完成"
}

# 清理日志文件
cleanup_logs() {
    log_info "清理日志文件"
    
    # 清理系统日志
    if is_root; then
        local log_file=$(get_config_value "logging.log_file" "/var/log/clash-installer.log")
        if [ -f "$log_file" ]; then
            rm -f "$log_file"
            log_info "删除系统日志: $log_file"
        fi
    fi
    
    # 清理用户日志
    local user_log_file=$(expand_path "$(get_config_value "logging.user_log_file" "~/.local/log/clash-installer.log")")
    if [ -f "$user_log_file" ]; then
        rm -f "$user_log_file"
        log_info "删除用户日志: $user_log_file"
    fi
    
    success "日志文件清理完成"
}

# 显示卸载摘要
show_uninstall_summary() {
    echo ""
    echo -e "${YELLOW}卸载摘要:${NC}"
    echo ""
    
    case "$UNINSTALL_MODE" in
        "full")
            echo -e "${GREEN}✓${NC} 完全卸载"
            echo "  - Clash 服务已停止"
            echo "  - 所有文件已删除"
            echo "  - 环境变量已清理"
            echo "  - 定时任务已清理"
            echo "  - 日志文件已清理"
            ;;
        "config_only")
            echo -e "${GREEN}✓${NC} 配置卸载"
            echo "  - Clash 服务已停止"
            echo "  - 配置文件已删除"
            echo "  - 可执行文件已保留"
            ;;
        "keep_config")
            echo -e "${GREEN}✓${NC} 服务停止"
            echo "  - Clash 服务已停止"
            echo "  - 所有文件已保留"
            echo "  - 可重新启动服务"
            ;;
    esac
    
    echo ""
    echo -e "${BLUE}如需重新安装，请运行:${NC}"
    echo "  $PROJECT_DIR/install.sh"
    echo ""
}

# 备份配置文件
backup_config() {
    if [ "$UNINSTALL_MODE" = "full" ] && [ -d "$CLASH_CONFIG_DIR" ]; then
        local backup_dir="$HOME/clash-backup-$(date +%Y%m%d-%H%M%S)"
        log_info "备份配置文件到: $backup_dir"
        
        mkdir -p "$backup_dir"
        cp -r "$CLASH_CONFIG_DIR"/* "$backup_dir/" 2>/dev/null || true
        
        success "配置文件已备份到: $backup_dir"
    fi
}

# 主卸载函数
uninstall_clash() {
    log_info "开始卸载 Clash"
    
    # 显示卸载选项
    show_uninstall_options
    
    # 选择卸载模式
    while true; do
        read -p "请选择卸载方式 [1-3]: " choice
        case $choice in
            1)
                UNINSTALL_MODE="full"
                break
                ;;
            2)
                UNINSTALL_MODE="config_only"
                break
                ;;
            3)
                UNINSTALL_MODE="keep_config"
                break
                ;;
            *)
                echo "无效选择，请重试"
                ;;
        esac
    done
    
    # 确认卸载
    local confirm_msg=""
    case "$UNINSTALL_MODE" in
        "full")
            confirm_msg="确定要完全卸载 Clash 吗？这将删除所有文件和数据"
            ;;
        "config_only")
            confirm_msg="确定要删除 Clash 配置吗？这将保留可执行文件"
            ;;
        "keep_config")
            confirm_msg="确定要停止 Clash 服务吗？这将保留所有文件"
            ;;
    esac
    
    if ! confirm "$confirm_msg" "n"; then
        info "卸载已取消"
        exit 0
    fi
    
    # 执行卸载步骤
    stop_clash_service
    
    if [ "$UNINSTALL_MODE" != "keep_config" ]; then
        backup_config
        uninstall_systemd_service
        remove_files
        cleanup_environment
        cleanup_cron
        cleanup_logs
    fi
    
    # 显示卸载摘要
    show_uninstall_summary
    
    success "Clash 卸载完成"
}

# 快速卸载（无交互）
quick_uninstall() {
    log_info "快速卸载 Clash"
    
    UNINSTALL_MODE="full"
    
    stop_clash_service
    uninstall_systemd_service
    remove_files
    cleanup_environment
    cleanup_cron
    cleanup_logs
    
    success "Clash 快速卸载完成"
}
