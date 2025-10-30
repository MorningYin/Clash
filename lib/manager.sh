#!/bin/bash
# Clash 服务管理逻辑
# 作者: Auto
# 日期: 2025-10-30

# 加载公共函数
source "$(dirname "$0")/common.sh"
# 加载系统代理函数
if [ -f "$(dirname "$0")/proxy.sh" ]; then
	source "$(dirname "$0")/proxy.sh"
fi

# 服务相关变量
SERVICE_NAME=$(get_config_value "install.service_name" "clash")
SERVICE_USER=$(get_config_value "install.service_user" "root")
PID_FILE="$CLASH_CONFIG_DIR/clash.pid"
LOG_FILE="$CLASH_CONFIG_DIR/clash.log"

# 检查 systemd 服务是否可用
systemd_unit_exists() {
    if ! command_exists systemctl; then
        return 1
    fi

    if systemctl show "${SERVICE_NAME}.service" >/dev/null 2>&1; then
        return 0
    fi

    if [ -f "/etc/systemd/system/${SERVICE_NAME}.service" ] || [ -f "/lib/systemd/system/${SERVICE_NAME}.service" ]; then
        return 0
    fi

    return 1
}

# 检查服务是否运行
is_running() {
    if is_root && systemd_unit_exists && systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        return 0
    fi

    if [ -f "$PID_FILE" ]; then
        local pid
        pid=$(cat "$PID_FILE" 2>/dev/null)
        if [ -n "$pid" ] && ps -p "$pid" > /dev/null 2>&1; then
            return 0
        else
            rm -f "$PID_FILE"
        fi
    fi
    return 1
}

# 获取服务状态
get_status() {
    if is_root && systemd_unit_exists && systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        local main_pid
        main_pid=$(systemctl show -p MainPID --value "$SERVICE_NAME" 2>/dev/null)
        if [ -n "$main_pid" ] && [ "$main_pid" != "0" ]; then
            echo "运行中 (PID: $main_pid)"
        else
            echo "运行中"
        fi
        return 0
    fi

    if [ -f "$PID_FILE" ]; then
        local pid
        pid=$(cat "$PID_FILE" 2>/dev/null)
        if [ -n "$pid" ] && ps -p "$pid" > /dev/null 2>&1; then
            echo "运行中 (PID: $pid)"
            return 0
        fi
    fi

    echo "未运行"
    return 1
}

# 检查端口监听
check_ports() {
    local http_port=$(get_config_value "install.http_port" "7890")
    local socks_port=$(get_config_value "install.socks_port" "7891")
    local api_port=$(get_config_value "install.api_port" "9090")

    local ports_status=()
    local inspector=""
    if command_exists ss; then
        inspector="ss -tlnp"
    elif command_exists netstat; then
        inspector="netstat -tln"
    fi

    if [ -n "$inspector" ]; then
        if eval "$inspector" 2>/dev/null | grep -Eq "[.:]$http_port\\b"; then
            ports_status+=("HTTP代理($http_port): ✓")
        else
            ports_status+=("HTTP代理($http_port): ✗")
        fi

        if eval "$inspector" 2>/dev/null | grep -Eq "[.:]$socks_port\\b"; then
            ports_status+=("SOCKS5代理($socks_port): ✓")
        else
            ports_status+=("SOCKS5代理($socks_port): ✗")
        fi

        if eval "$inspector" 2>/dev/null | grep -Eq "[.:]$api_port\\b"; then
            ports_status+=("管理面板($api_port): ✓")
        else
            ports_status+=("管理面板($api_port): ✗")
        fi
    else
        ports_status+=("HTTP代理($http_port): 未检测 (缺少 ss/netstat)")
        ports_status+=("SOCKS5代理($socks_port): 未检测 (缺少 ss/netstat)")
        ports_status+=("管理面板($api_port): 未检测 (缺少 ss/netstat)")
    fi

    printf '%s\n' "${ports_status[@]}"
}

# 启动服务
start_service() {
    log_info "启动 Clash 服务"
    
    if is_running; then
        warn "Clash 服务已在运行"
        return 0
    fi
    
    # 检查配置文件
    if [ ! -f "$CLASH_CONFIG_DIR/config.yaml" ]; then
        error "配置文件不存在: $CLASH_CONFIG_DIR/config.yaml"
        return 1
    fi
    
    # 验证配置文件
    if ! "$CLASH_BIN_DIR/clash" -t -f "$CLASH_CONFIG_DIR/config.yaml" >/dev/null 2>&1; then
        error "配置文件验证失败"
        return 1
    fi
    
    # 启动服务
    local started_via_systemd=false

    if is_root && systemd_unit_exists; then
        if systemctl start "$SERVICE_NAME" 2>/dev/null; then
            started_via_systemd=true
            sleep 1
            local main_pid
            main_pid=$(systemctl show -p MainPID --value "$SERVICE_NAME" 2>/dev/null)
            if [ -n "$main_pid" ] && [ "$main_pid" != "0" ]; then
                echo "$main_pid" > "$PID_FILE"
            fi
        else
            log_warn "systemd 启动失败，尝试直接启动"
        fi
    fi

    if [ "$started_via_systemd" = false ]; then
        start_direct
    fi

    sleep 2

    if is_running; then
        success "Clash 服务启动成功"
        show_service_info
    else
        error "Clash 服务启动失败"
        return 1
    fi
}

# 直接启动服务
start_direct() {
    log_info "直接启动 Clash 服务"

    # 启动 Clash
    nohup "$CLASH_BIN_DIR/clash" -d "$CLASH_CONFIG_DIR" > "$LOG_FILE" 2>&1 &
    local clash_pid=$!

    # 保存 PID
    mkdir -p "$(dirname "$PID_FILE")" 2>/dev/null || true
    echo "$clash_pid" > "$PID_FILE"

    log_info "Clash 进程启动 (PID: $clash_pid)"
}

# 停止服务
stop_service() {
    log_info "停止 Clash 服务"
    
    if ! is_running; then
        warn "Clash 服务未运行"
        return 0
    fi
    
    local stopped_via_systemd=false

    if is_root && systemd_unit_exists; then
        if systemctl stop "$SERVICE_NAME" 2>/dev/null; then
            stopped_via_systemd=true
        else
            log_warn "systemd 停止失败，尝试直接停止"
        fi
    fi

    if [ "$stopped_via_systemd" = true ]; then
        rm -f "$PID_FILE"
    else
        stop_direct
    fi

    sleep 2

    if ! is_running; then
        success "Clash 服务已停止"
    else
        error "Clash 服务停止失败"
        return 1
    fi
}

# 直接停止服务
stop_direct() {
    if [ ! -f "$PID_FILE" ]; then
        log_warn "未找到 PID 文件，尝试通过进程名停止"
        if command_exists pkill; then
            pkill -f "$CLASH_BIN_DIR/clash" 2>/dev/null || true
        else
            log_warn "系统缺少 pkill 命令，请手动检查 Clash 进程"
        fi
        return 0
    fi

    local pid
    pid=$(cat "$PID_FILE" 2>/dev/null)
    if [ -z "$pid" ]; then
        rm -f "$PID_FILE"
        return 0
    fi

    log_info "停止 Clash 进程 (PID: $pid)"

    kill "$pid" 2>/dev/null || true

    for _ in {1..10}; do
        if ! ps -p "$pid" > /dev/null 2>&1; then
            rm -f "$PID_FILE"
            return 0
        fi
        sleep 1
    done

    log_warn "强制停止 Clash 进程"
    kill -9 "$pid" 2>/dev/null || true
    rm -f "$PID_FILE"
}

# 重启服务
restart_service() {
    log_info "重启 Clash 服务"
    stop_service
    sleep 1
    start_service
}

# 显示服务信息
show_service_info() {
    local http_port=$(get_config_value "install.http_port" "7890")
    local socks_port=$(get_config_value "install.socks_port" "7891")
    local api_port=$(get_config_value "install.api_port" "9090")
    
    echo ""
    info "服务信息:"
    echo "  状态: $(get_status)"
    echo "  HTTP 代理: http://127.0.0.1:$http_port"
    echo "  SOCKS5 代理: socks5://127.0.0.1:$socks_port"
    echo "  管理面板: http://127.0.0.1:$api_port"
    echo "  日志文件: $LOG_FILE"
    echo ""
    
    info "端口状态:"
    check_ports | sed 's/^/  /'
    echo ""
}

# 查看日志
view_logs() {
    local lines="${1:-50}"
    
    if [ -f "$LOG_FILE" ]; then
        log_info "显示最近的 $lines 行日志:"
        echo ""
        tail -n "$lines" "$LOG_FILE"
    else
        warn "日志文件不存在: $LOG_FILE"
    fi
}

# 实时查看日志
follow_logs() {
    if [ -f "$LOG_FILE" ]; then
        log_info "实时查看日志 (按 Ctrl+C 退出):"
        echo ""
        tail -f "$LOG_FILE"
    else
        warn "日志文件不存在: $LOG_FILE"
    fi
}

# 更新订阅
update_subscription() {
    log_info "更新订阅配置"
    
    local update_script="$CLASH_CONFIG_DIR/update-subscription.sh"
    if [ -f "$update_script" ]; then
        if "$update_script"; then
            success "订阅更新成功"
            # 重启服务以应用新配置
            if confirm "是否重启服务以应用新配置？" "y"; then
                restart_service
            fi
        else
            error "订阅更新失败"
            return 1
        fi
    else
        error "更新脚本不存在: $update_script"
        return 1
    fi
}

# 测试连接
test_connection() {
    local http_port=$(get_config_value "install.http_port" "7890")
    
    log_info "测试代理连接"
    
    # 测试 HTTP 代理
    local test_url="http://www.google.com"
    local proxy_url="http://127.0.0.1:$http_port"
    
    echo "测试 HTTP 代理连接..."
    if curl -x "$proxy_url" -s -o /dev/null -w "HTTP 状态码: %{http_code}\n" "$test_url"; then
        success "HTTP 代理连接正常"
    else
        error "HTTP 代理连接失败"
        return 1
    fi
    
    # 测试响应时间
    echo "测试响应时间..."
    local response_time=$(curl -x "$proxy_url" -s -o /dev/null -w "%{time_total}" "$test_url")
    echo "响应时间: ${response_time}秒"
    
    return 0
}

# 设置代理环境变量
setup_proxy_env() {
    local http_port=$(get_config_value "install.http_port" "7890")
    local socks_port=$(get_config_value "install.socks_port" "7891")
    
    log_info "设置代理环境变量"
    
    local proxy_file="$CLASH_CONFIG_DIR/proxy-env.sh"
    
    cat > "$proxy_file" << EOF
#!/bin/bash
# Clash 代理环境变量
# 由 Clash 安装程序自动生成

# 设置代理环境变量
export http_proxy=http://127.0.0.1:$http_port
export https_proxy=http://127.0.0.1:$http_port
export HTTP_PROXY=http://127.0.0.1:$http_port
export HTTPS_PROXY=http://127.0.0.1:$http_port
export all_proxy=socks5://127.0.0.1:$socks_port
export ALL_PROXY=socks5://127.0.0.1:$socks_port

# 设置不走代理的地址
export no_proxy="localhost,127.0.0.1,::1"
export NO_PROXY="localhost,127.0.0.1,::1"

# 便捷函数
clash_on() {
    echo "启用 Clash 代理..."
    export http_proxy=http://127.0.0.1:$http_port
    export https_proxy=http://127.0.0.1:$http_port
    export HTTP_PROXY=http://127.0.0.1:$http_port
    export HTTPS_PROXY=http://127.0.0.1:$http_port
    export all_proxy=socks5://127.0.0.1:$socks_port
    export ALL_PROXY=socks5://127.0.0.1:$socks_port
    echo "代理已启用"
}

clash_off() {
    echo "禁用 Clash 代理..."
    unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY all_proxy ALL_PROXY
    echo "代理已禁用"
}

clash_test() {
    echo "测试代理连接..."
    if curl -x http://127.0.0.1:$http_port -s -o /dev/null -w "HTTP 代理测试: %{http_code}\n" http://www.google.com; then
        echo "代理连接正常"
    else
        echo "代理连接失败"
    fi
}

echo "Clash 代理环境变量已加载"
echo "使用 clash_on 启用代理，clash_off 禁用代理，clash_test 测试连接"
EOF
    
    chmod +x "$proxy_file"
    success "代理环境变量脚本创建成功: $proxy_file"
    
    # 添加到用户的 shell 配置文件
    local shell_rc=""
    if [ -n "$ZSH_VERSION" ]; then
        shell_rc="$HOME/.zshrc"
    elif [ -n "$BASH_VERSION" ]; then
        shell_rc="$HOME/.bashrc"
    fi
    
    if [ -n "$shell_rc" ] && [ -f "$shell_rc" ]; then
        if ! grep -q "proxy-env.sh" "$shell_rc"; then
            echo "source $proxy_file" >> "$shell_rc"
            success "已添加到 $shell_rc"
        fi
    fi
}

# 一键系统代理开关（自动判断 root -> system，否则 user）
enable_system_proxy() {
    if command_exists proxy_on; then
        if is_root; then proxy_on --system; else proxy_on --user; fi
    else
        error "proxy_on 函数不可用"
        return 1
    fi
}

disable_system_proxy() {
    if command_exists proxy_off; then
        if is_root; then proxy_off --system; else proxy_off --user; fi
    else
        error "proxy_off 函数不可用"
        return 1
    fi
}

# 安装 systemd 服务
install_systemd_service() {
    if ! is_root; then
        log_info "非 root 用户，跳过 systemd 服务安装"
        return 0
    fi
    
    if ! command_exists systemctl; then
        log_info "systemd 不可用，跳过服务安装"
        return 0
    fi
    
    log_info "安装 systemd 服务"
    
    local service_file="/etc/systemd/system/${SERVICE_NAME}.service"
    local template_file="$PROJECT_DIR/templates/clash.service.tpl"
    
    if [ ! -f "$template_file" ]; then
        error "服务模板文件不存在: $template_file"
        return 1
    fi
    
    # 替换模板变量
    sed -e "s/{{USER}}/$SERVICE_USER/g" \
        -e "s/{{GROUP}}/$SERVICE_USER/g" \
        -e "s|{{CLASH_BIN}}|$CLASH_BIN_DIR/clash|g" \
        -e "s|{{CLASH_CONFIG_DIR}}|$CLASH_CONFIG_DIR|g" \
        "$template_file" > "$service_file"
    
    # 重新加载 systemd
    systemctl daemon-reload
    
    # 启用服务
    systemctl enable "$SERVICE_NAME"
    
    success "systemd 服务安装成功"
}

# 卸载 systemd 服务
uninstall_systemd_service() {
    if ! is_root; then
        return 0
    fi
    
    if ! command_exists systemctl; then
        return 0
    fi
    
    log_info "卸载 systemd 服务"
    
    # 停止并禁用服务
    systemctl stop "$SERVICE_NAME" 2>/dev/null || true
    systemctl disable "$SERVICE_NAME" 2>/dev/null || true
    
    # 删除服务文件
    rm -f "/etc/systemd/system/${SERVICE_NAME}.service"
    
    # 重新加载 systemd
    systemctl daemon-reload
    
    success "systemd 服务已卸载"
}
