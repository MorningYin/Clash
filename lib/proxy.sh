#!/bin/bash
# 系统/用户级 一键代理设置库
# 依赖: lib/common.sh

PROXY_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$PROXY_LIB_DIR/common.sh"

# ===== 常量定义 =====
PROXY_MARK_BEGIN="# >>> clash-installer proxy BEGIN"
PROXY_MARK_END="# <<< clash-installer proxy END"

# ===== 工具函数 =====
# 获取 HTTP 代理端口
# 返回值: 端口号（默认 7890）
get_http_port() {
    get_config_value "install.http_port" "7890"
}

# 获取 SOCKS5 代理端口
# 返回值: 端口号（默认 7891）
get_socks_port() {
    get_config_value "install.socks_port" "7891"
}

# 初始化代理值
# 设置 HTTP_PORT, SOCKS_PORT, HTTP_PROXY_VAL, SOCKS_PROXY_VAL, NO_PROXY_VAL
proxy_values_init() {
    HTTP_PORT="$(get_http_port)"
    SOCKS_PORT="$(get_socks_port)"
    HTTP_PROXY_VAL="http://127.0.0.1:${HTTP_PORT}"
    SOCKS_PROXY_VAL="socks5://127.0.0.1:${SOCKS_PORT}"
    NO_PROXY_VAL="localhost,127.0.0.1,::1"
}

# 追加代理配置块到文件（以标记包裹，便于回滚）
# 参数:
#   $1: 目标文件路径
#   $2: 配置内容
append_proxy_block() {
    local target_file="$1"
    local content="$2"
    
    # 备份原文件（如果存在）
    [ -f "$target_file" ] && cp "$target_file" "${target_file}.bak" || true
    
    # 删除旧块
    sed -i "/$PROXY_MARK_BEGIN/,/$PROXY_MARK_END/d" "$target_file" 2>/dev/null || true
    
    # 追加新块
    {
        echo "$PROXY_MARK_BEGIN"
        echo "$content"
        echo "$PROXY_MARK_END"
    } >> "$target_file"
}

# 移除文件中的代理配置块
# 参数:
#   $1: 目标文件路径
remove_proxy_block() {
    local target_file="$1"
    
    [ -f "$target_file" ] || return 0
    sed -i "/$PROXY_MARK_BEGIN/,/$PROXY_MARK_END/d" "$target_file"
}

# ===== 用户级代理配置 =====
# 启用用户级代理（shell 环境 + git + gsettings）
# 影响范围: 当前用户的所有 shell 会话、git、GNOME 桌面环境
user_proxy_on() {
    proxy_values_init
    local cfg_dir="$CLASH_CONFIG_DIR"
    local user_env_file="$cfg_dir/proxy-env.sh"
    
    create_directory "$cfg_dir" "755"
    
    # 创建用户级代理环境变量脚本
    cat > "$user_env_file" <<EOF
#!/bin/bash
# Clash 代理环境变量
# 由 Clash 安装程序自动生成

export http_proxy=${HTTP_PROXY_VAL}
export https_proxy=${HTTP_PROXY_VAL}
export HTTP_PROXY=${HTTP_PROXY_VAL}
export HTTPS_PROXY=${HTTP_PROXY_VAL}
export all_proxy=${SOCKS_PROXY_VAL}
export ALL_PROXY=${SOCKS_PROXY_VAL}
export no_proxy=${NO_PROXY_VAL}
export NO_PROXY=${NO_PROXY_VAL}
EOF
    chmod +x "$user_env_file"
    
    # 配置 shell 启动脚本
    for rc in "$HOME/.bashrc" "$HOME/.profile"; do
        [ -f "$rc" ] || touch "$rc"
        append_proxy_block "$rc" ". $user_env_file"
    done
    
    # 配置 Git 全局代理
    if command_exists git; then
        git config --global http.proxy "$HTTP_PROXY_VAL" || true
        git config --global https.proxy "$HTTP_PROXY_VAL" || true
    fi
    
    # 配置 GNOME 桌面代理
    if command_exists gsettings; then
        gsettings set org.gnome.system.proxy mode 'manual' || true
        gsettings set org.gnome.system.proxy.http host '127.0.0.1' || true
        gsettings set org.gnome.system.proxy.http port ${HTTP_PORT} || true
        gsettings set org.gnome.system.proxy.https host '127.0.0.1' || true
        gsettings set org.gnome.system.proxy.https port ${HTTP_PORT} || true
        gsettings set org.gnome.system.proxy.socks host '127.0.0.1' || true
        gsettings set org.gnome.system.proxy.socks port ${SOCKS_PORT} || true
    fi
    
    success "用户级系统代理已开启"
}

# 禁用用户级代理
# 清理: shell 配置、git 全局配置、GNOME 桌面代理
user_proxy_off() {
    # 移除 shell 配置
    for rc in "$HOME/.bashrc" "$HOME/.profile"; do
        [ -f "$rc" ] && remove_proxy_block "$rc"
    done
    
    # 清理 Git 全局代理
    if command_exists git; then
        git config --global --unset http.proxy 2>/dev/null || true
        git config --global --unset https.proxy 2>/dev/null || true
    fi
    
    # 清理 GNOME 桌面代理
    if command_exists gsettings; then
        gsettings set org.gnome.system.proxy mode 'none' || true
    fi
    
    success "用户级系统代理已关闭"
}

# ===== 系统级代理配置 =====
# 启用系统级代理（/etc/* + systemd + docker + git --system）
# 影响范围: 所有用户、所有应用程序、系统服务
# 需要 root 权限
system_proxy_on() {
    proxy_values_init
    
    if ! is_root; then
        error "需要 root 权限才能开启系统级代理"
        return 1
    fi
    
    # 配置 /etc/environment（系统环境变量）
    local env_file="/etc/environment"
    [ -f "$env_file" ] || touch "$env_file"
    append_proxy_block "$env_file" \
        "HTTP_PROXY=${HTTP_PROXY_VAL}\nHTTPS_PROXY=${HTTP_PROXY_VAL}\nhttp_proxy=${HTTP_PROXY_VAL}\nhttps_proxy=${HTTP_PROXY_VAL}\nALL_PROXY=${SOCKS_PROXY_VAL}\nall_proxy=${SOCKS_PROXY_VAL}\nNO_PROXY=${NO_PROXY_VAL}\nno_proxy=${NO_PROXY_VAL}"
    
    # 配置 APT 包管理器
    local apt_file="/etc/apt/apt.conf.d/95clash-proxy"
    mkdir -p "/etc/apt/apt.conf.d"
    cat > "$apt_file" <<EOF
Acquire::http::Proxy "${HTTP_PROXY_VAL}/";
Acquire::https::Proxy "${HTTP_PROXY_VAL}/";
EOF
    
    # 配置 YUM 包管理器
    if [ -f /etc/yum.conf ]; then
        append_proxy_block "/etc/yum.conf" "proxy=${HTTP_PROXY_VAL}"
    fi
    
    # 配置 DNF 包管理器
    if [ -f /etc/dnf/dnf.conf ]; then
        append_proxy_block "/etc/dnf/dnf.conf" "proxy=${HTTP_PROXY_VAL}"
    fi
    
    # 配置 systemd 全局环境变量
    if systemd_available; then
        mkdir -p /etc/systemd/system.conf.d
        cat > /etc/systemd/system.conf.d/proxy.conf <<EOF
[Manager]
DefaultEnvironment=HTTP_PROXY=${HTTP_PROXY_VAL} HTTPS_PROXY=${HTTP_PROXY_VAL} ALL_PROXY=${SOCKS_PROXY_VAL} NO_PROXY=${NO_PROXY_VAL}
EOF
        systemctl daemon-reload || true
    fi
    
    # 配置 Docker 守护进程代理
    if systemd_available && [ -d /etc/systemd/system ]; then
        mkdir -p /etc/systemd/system/docker.service.d
        cat > /etc/systemd/system/docker.service.d/proxy.conf <<EOF
[Service]
Environment=HTTP_PROXY=${HTTP_PROXY_VAL}
Environment=HTTPS_PROXY=${HTTP_PROXY_VAL}
Environment=NO_PROXY=${NO_PROXY_VAL}
EOF
        # 尝试重载并重启 docker
        systemctl daemon-reload || true
        systemctl restart docker 2>/dev/null || true
    fi
    
    # 配置 Git 系统级代理
    if command_exists git; then
        git config --system http.proxy "$HTTP_PROXY_VAL" 2>/dev/null || true
        git config --system https.proxy "$HTTP_PROXY_VAL" 2>/dev/null || true
    fi
    
    success "系统级系统代理已开启"
}

# 禁用系统级代理
# 清理: /etc/environment, APT/YUM/DNF, systemd, Docker, Git 系统级配置
# 需要 root 权限
system_proxy_off() {
    if ! is_root; then
        error "需要 root 权限才能关闭系统级代理"
        return 1
    fi
    
    log_info "开始清理系统级代理配置..."
    
    # 清理 /etc/environment（系统环境变量）
    if [ -f /etc/environment ]; then
        remove_proxy_block /etc/environment
        log_info "已清理 /etc/environment 中的代理配置"
    fi
    
    # 清理 APT 包管理器配置
    if [ -f /etc/apt/apt.conf.d/95clash-proxy ]; then
        rm -f /etc/apt/apt.conf.d/95clash-proxy 2>/dev/null || true
        log_info "已清理 APT 代理配置"
    fi
    
    # 清理 YUM 包管理器配置
    if [ -f /etc/yum.conf ]; then
        remove_proxy_block /etc/yum.conf
        log_info "已清理 YUM 代理配置"
    fi
    
    # 清理 DNF 包管理器配置
    if [ -f /etc/dnf/dnf.conf ]; then
        remove_proxy_block /etc/dnf/dnf.conf
        log_info "已清理 DNF 代理配置"
    fi
    
    # 清理 systemd 全局环境变量
    if systemd_available; then
        if [ -f /etc/systemd/system.conf.d/proxy.conf ]; then
            rm -f /etc/systemd/system.conf.d/proxy.conf 2>/dev/null || true
            log_info "已清理 systemd 全局环境变量"
        fi
        systemctl daemon-reload || true
    fi
    
    # 清理 Docker 服务代理配置
    if systemd_available && [ -d /etc/systemd/system/docker.service.d ]; then
        if [ -f /etc/systemd/system/docker.service.d/proxy.conf ]; then
            rm -f /etc/systemd/system/docker.service.d/proxy.conf 2>/dev/null || true
            log_info "已清理 Docker 服务代理配置"
            systemctl daemon-reload || true
            # 不强制重启 docker，避免打断业务
        fi
    fi
    
    # 清理 Git 系统级代理配置
    if command_exists git; then
        git config --system --unset http.proxy 2>/dev/null || true
        git config --system --unset https.proxy 2>/dev/null || true
        log_info "已清理 Git 系统级代理配置"
    fi
    
    # 清理可能的其他代理配置文件
    # 使用数组存储需要清理的文件，避免管道创建子shell的问题
    local files_to_clean=()
    if [ -d /etc/apt/apt.conf.d ]; then
        while IFS= read -r -d '' file; do
            if grep -q "clash-installer\|127.0.0.1:789" "$file" 2>/dev/null; then
                files_to_clean+=("$file")
            fi
        done < <(find /etc/apt/apt.conf.d/ -name "*proxy*" -type f -print0 2>/dev/null)
    fi
    
    # 清理找到的额外 APT 代理配置文件
    for file in "${files_to_clean[@]}"; do
        rm -f "$file" 2>/dev/null || true
        log_info "已清理额外的 APT 代理配置: $file"
    done
    
    success "系统级代理配置已完全清理，系统网络路径已恢复"
}

# ===== 公共 API =====
# 启用代理（自动判断使用系统级或用户级）
# 参数:
#   $1: 作用域（可选）: "--system" 或 "--user"
#       如果不提供，自动判断：root 用户使用系统级，普通用户使用用户级
proxy_on() {
    local scope="${1:-}"
    
    if [ "$scope" = "--system" ]; then
        system_proxy_on
    elif [ "$scope" = "--user" ]; then
        user_proxy_on
    else
        # 自动判断：root 用户使用系统级，普通用户使用用户级
        if is_root; then
            system_proxy_on
        else
            user_proxy_on
        fi
    fi
}

# 禁用代理（自动判断使用系统级或用户级）
# 参数:
#   $1: 作用域（可选）: "--system" 或 "--user"
#       如果不提供，自动判断：root 用户使用系统级，普通用户使用用户级
proxy_off() {
    local scope="${1:-}"
    
    if [ "$scope" = "--system" ]; then
        system_proxy_off
    elif [ "$scope" = "--user" ]; then
        user_proxy_off
    else
        # 自动判断：root 用户使用系统级，普通用户使用用户级
        if is_root; then
            system_proxy_off
        else
            user_proxy_off
        fi
    fi
}
