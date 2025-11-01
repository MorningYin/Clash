#!/bin/bash
# 系统/用户级 一键代理设置库
# 依赖: lib/common.sh

PROXY_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$PROXY_LIB_DIR/common.sh"

# ===== 常量定义 =====
PROXY_MARK_BEGIN="# >>> clash-installer proxy BEGIN"
PROXY_MARK_END="# <<< clash-installer proxy END"

# ===== 备份和恢复功能 =====
# 获取备份目录路径
get_backup_dir() {
    echo "$CLASH_CONFIG_DIR/.proxy-backup"
}

# 备份原始代理设置（系统级）
backup_system_proxy_settings() {
    local backup_dir="$(get_backup_dir)"
    
    if ! mkdir -p "$backup_dir/etc" 2>/dev/null; then
        log_warn "无法创建备份目录，跳过备份"
        return 1
    fi
    
    log_info "备份原始系统代理设置..."
    
    # 备份 /etc/environment（如果存在且包含代理相关配置）
    if [ -f /etc/environment ]; then
        # 检查是否包含代理相关配置（但不是 Clash 的标记块）
        if grep -qv "$PROXY_MARK_BEGIN" /etc/environment 2>/dev/null && \
           (grep -qiE "(proxy|PROXY)" /etc/environment 2>/dev/null || \
            grep -qiE "(http_proxy|https_proxy|HTTP_PROXY|HTTPS_PROXY|all_proxy|ALL_PROXY)" /etc/environment 2>/dev/null); then
            mkdir -p "$backup_dir/etc"
            cp /etc/environment "$backup_dir/etc/environment" 2>/dev/null && \
                log_info "备份: /etc/environment" || \
                log_warn "备份失败: /etc/environment"
        fi
    fi
    
    # 备份 Git 系统级配置
    if [ -f /etc/gitconfig ]; then
        if git config --system --get http.proxy >/dev/null 2>&1 || \
           git config --system --get https.proxy >/dev/null 2>&1; then
            mkdir -p "$backup_dir/etc"
            cp /etc/gitconfig "$backup_dir/etc/gitconfig" 2>/dev/null && \
                log_info "备份: /etc/gitconfig" || \
                log_warn "备份失败: /etc/gitconfig"
        fi
    fi
    
    # 备份 APT 代理配置（如果存在且不是 Clash 创建的）
    if [ -f /etc/apt/apt.conf.d/95clash-proxy ]; then
        # 如果是 Clash 创建的，跳过备份
        if ! grep -q "clash" /etc/apt/apt.conf.d/95clash-proxy 2>/dev/null; then
            mkdir -p "$backup_dir/etc/apt/apt.conf.d"
            cp /etc/apt/apt.conf.d/95clash-proxy "$backup_dir/etc/apt/apt.conf.d/95clash-proxy" 2>/dev/null && \
                log_info "备份: /etc/apt/apt.conf.d/95clash-proxy" || \
                log_warn "备份失败: /etc/apt/apt.conf.d/95clash-proxy"
        fi
    fi
    
    # 备份 YUM 配置（如果存在且包含代理配置）
    if [ -f /etc/yum.conf ]; then
        if grep -qiE "proxy\s*=" /etc/yum.conf 2>/dev/null && \
           ! grep -q "$PROXY_MARK_BEGIN" /etc/yum.conf 2>/dev/null; then
            mkdir -p "$backup_dir/etc"
            cp /etc/yum.conf "$backup_dir/etc/yum.conf" 2>/dev/null && \
                log_info "备份: /etc/yum.conf" || \
                log_warn "备份失败: /etc/yum.conf"
        fi
    fi
    
    # 备份 DNF 配置（如果存在且包含代理配置）
    if [ -f /etc/dnf/dnf.conf ]; then
        if grep -qiE "proxy\s*=" /etc/dnf/dnf.conf 2>/dev/null && \
           ! grep -q "$PROXY_MARK_BEGIN" /etc/dnf/dnf.conf 2>/dev/null; then
            mkdir -p "$backup_dir/etc/dnf"
            cp /etc/dnf/dnf.conf "$backup_dir/etc/dnf/dnf.conf" 2>/dev/null && \
                log_info "备份: /etc/dnf/dnf.conf" || \
                log_warn "备份失败: /etc/dnf/dnf.conf"
        fi
    fi
    
    # 备份 systemd 代理配置（如果存在且不是 Clash 创建的）
    if [ -f /etc/systemd/system.conf.d/proxy.conf ]; then
        # 如果是 Clash 创建的，跳过备份
        if ! grep -q "clash" /etc/systemd/system.conf.d/proxy.conf 2>/dev/null; then
            mkdir -p "$backup_dir/etc/systemd/system.conf.d"
            cp /etc/systemd/system.conf.d/proxy.conf "$backup_dir/etc/systemd/system.conf.d/proxy.conf" 2>/dev/null && \
                log_info "备份: /etc/systemd/system.conf.d/proxy.conf" || \
                log_warn "备份失败: /etc/systemd/system.conf.d/proxy.conf"
        fi
    fi
    
    # 备份 Docker 代理配置（如果存在且不是 Clash 创建的）
    if [ -f /etc/systemd/system/docker.service.d/proxy.conf ]; then
        # 如果是 Clash 创建的，跳过备份
        if ! grep -q "clash" /etc/systemd/system/docker.service.d/proxy.conf 2>/dev/null; then
            mkdir -p "$backup_dir/etc/systemd/system/docker.service.d"
            cp /etc/systemd/system/docker.service.d/proxy.conf "$backup_dir/etc/systemd/system/docker.service.d/proxy.conf" 2>/dev/null && \
                log_info "备份: /etc/systemd/system/docker.service.d/proxy.conf" || \
                log_warn "备份失败: /etc/systemd/system/docker.service.d/proxy.conf"
        fi
    fi
    
    # 记录备份时间戳
    echo "$(date '+%Y-%m-%d %H:%M:%S')" > "$backup_dir/backup_timestamp.txt" 2>/dev/null || true
    
    return 0
}

# 恢复原始代理设置（系统级）
restore_system_proxy_settings() {
    local backup_dir="$(get_backup_dir)"
    
    if [ ! -d "$backup_dir" ]; then
        # 没有备份，只删除 Clash 标记块（兼容现有行为）
        return 0
    fi
    
    log_info "恢复原始系统代理设置..."
    
    # 恢复 /etc/environment
    if [ -f "$backup_dir/etc/environment" ]; then
        # 先删除 Clash 标记块
        [ -f /etc/environment ] && remove_proxy_block /etc/environment
        # 恢复备份
        cp "$backup_dir/etc/environment" /etc/environment 2>/dev/null && \
            log_info "恢复: /etc/environment" || \
            log_warn "恢复失败: /etc/environment"
    else
        # 没有备份，只删除 Clash 标记块
        [ -f /etc/environment ] && remove_proxy_block /etc/environment
    fi
    
    # 恢复 Git 系统级配置
    if [ -f "$backup_dir/etc/gitconfig" ]; then
        cp "$backup_dir/etc/gitconfig" /etc/gitconfig 2>/dev/null && \
            log_info "恢复: /etc/gitconfig" || \
            log_warn "恢复失败: /etc/gitconfig"
    else
        # 没有备份，清除 Git 系统级代理
        if command_exists git; then
            git config --system --unset http.proxy 2>/dev/null || true
            git config --system --unset https.proxy 2>/dev/null || true
        fi
    fi
    
    # 恢复 APT 代理配置（如果备份存在且不是 Clash 创建的）
    if [ -f "$backup_dir/etc/apt/apt.conf.d/95clash-proxy" ]; then
        mkdir -p /etc/apt/apt.conf.d
        cp "$backup_dir/etc/apt/apt.conf.d/95clash-proxy" /etc/apt/apt.conf.d/95clash-proxy 2>/dev/null && \
            log_info "恢复: /etc/apt/apt.conf.d/95clash-proxy" || \
            log_warn "恢复失败: /etc/apt/apt.conf.d/95clash-proxy"
    else
        # 删除 Clash 创建的 APT 代理配置
        rm -f /etc/apt/apt.conf.d/95clash-proxy 2>/dev/null || true
    fi
    
    # 恢复 YUM 配置
    if [ -f "$backup_dir/etc/yum.conf" ]; then
        # 先删除 Clash 标记块
        [ -f /etc/yum.conf ] && remove_proxy_block /etc/yum.conf
        # 恢复备份
        cp "$backup_dir/etc/yum.conf" /etc/yum.conf 2>/dev/null && \
            log_info "恢复: /etc/yum.conf" || \
            log_warn "恢复失败: /etc/yum.conf"
    else
        # 没有备份，只删除 Clash 标记块
        [ -f /etc/yum.conf ] && remove_proxy_block /etc/yum.conf
    fi
    
    # 恢复 DNF 配置
    if [ -f "$backup_dir/etc/dnf/dnf.conf" ]; then
        # 先删除 Clash 标记块
        [ -f /etc/dnf/dnf.conf ] && remove_proxy_block /etc/dnf/dnf.conf
        # 恢复备份
        mkdir -p /etc/dnf
        cp "$backup_dir/etc/dnf/dnf.conf" /etc/dnf/dnf.conf 2>/dev/null && \
            log_info "恢复: /etc/dnf/dnf.conf" || \
            log_warn "恢复失败: /etc/dnf/dnf.conf"
    else
        # 没有备份，只删除 Clash 标记块
        [ -f /etc/dnf/dnf.conf ] && remove_proxy_block /etc/dnf/dnf.conf
    fi
    
    # 恢复 systemd 代理配置（如果备份存在且不是 Clash 创建的）
    if [ -f "$backup_dir/etc/systemd/system.conf.d/proxy.conf" ]; then
        mkdir -p /etc/systemd/system.conf.d
        cp "$backup_dir/etc/systemd/system.conf.d/proxy.conf" /etc/systemd/system.conf.d/proxy.conf 2>/dev/null && \
            log_info "恢复: /etc/systemd/system.conf.d/proxy.conf" || \
            log_warn "恢复失败: /etc/systemd/system.conf.d/proxy.conf"
        systemctl daemon-reload || true
    else
        # 删除 Clash 创建的 systemd 代理配置
        rm -f /etc/systemd/system.conf.d/proxy.conf 2>/dev/null || true
        systemctl daemon-reload || true
    fi
    
    # 恢复 Docker 代理配置（如果备份存在且不是 Clash 创建的）
    if [ -f "$backup_dir/etc/systemd/system/docker.service.d/proxy.conf" ]; then
        mkdir -p /etc/systemd/system/docker.service.d
        cp "$backup_dir/etc/systemd/system/docker.service.d/proxy.conf" /etc/systemd/system/docker.service.d/proxy.conf 2>/dev/null && \
            log_info "恢复: /etc/systemd/system/docker.service.d/proxy.conf" || \
            log_warn "恢复失败: /etc/systemd/system/docker.service.d/proxy.conf"
        systemctl daemon-reload || true
    else
        # 删除 Clash 创建的 Docker 代理配置
        rm -f /etc/systemd/system/docker.service.d/proxy.conf 2>/dev/null || true
        systemctl daemon-reload || true
    fi
    
    return 0
}

# 备份原始代理设置（用户级）
backup_user_proxy_settings() {
    local backup_dir="$(get_backup_dir)"
    
    if ! mkdir -p "$backup_dir" 2>/dev/null; then
        log_warn "无法创建备份目录，跳过备份"
        return 1
    fi
    
    log_info "备份原始用户代理设置..."
    
    # 备份 shell 配置文件
    for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
        if [ -f "$rc" ]; then
            # 检查是否包含代理相关配置（但不是 Clash 的标记块）
            if grep -qv "$PROXY_MARK_BEGIN" "$rc" 2>/dev/null && \
               (grep -qiE "(proxy|PROXY)" "$rc" 2>/dev/null || \
                grep -qiE "(http_proxy|https_proxy|HTTP_PROXY|HTTPS_PROXY|all_proxy|ALL_PROXY)" "$rc" 2>/dev/null || \
                grep -qiE "(\.\s+.*proxy|source.*proxy)" "$rc" 2>/dev/null); then
                local basename_rc="$(basename "$rc")"
                cp "$rc" "$backup_dir/$basename_rc" 2>/dev/null && \
                    log_info "备份: $rc" || \
                    log_warn "备份失败: $rc"
            fi
        fi
    done
    
    # 备份 Git 用户级配置（如果包含代理设置）
    if [ -f "$HOME/.gitconfig" ]; then
        if git config --global --get http.proxy >/dev/null 2>&1 || \
           git config --global --get https.proxy >/dev/null 2>&1; then
            cp "$HOME/.gitconfig" "$backup_dir/.gitconfig" 2>/dev/null && \
                log_info "备份: $HOME/.gitconfig" || \
                log_warn "备份失败: $HOME/.gitconfig"
        fi
    fi
    
    # 备份 GNOME 桌面代理设置（如果可用）
    if command_exists gsettings; then
        local gsettings_backup="$backup_dir/gsettings.txt"
        {
            echo "# GNOME 桌面代理设置备份 - $(date '+%Y-%m-%d %H:%M:%S')"
            gsettings get org.gnome.system.proxy mode 2>/dev/null || echo "none"
            gsettings get org.gnome.system.proxy.http host 2>/dev/null || echo ""
            gsettings get org.gnome.system.proxy.http port 2>/dev/null || echo "0"
            gsettings get org.gnome.system.proxy.https host 2>/dev/null || echo ""
            gsettings get org.gnome.system.proxy.https port 2>/dev/null || echo "0"
            gsettings get org.gnome.system.proxy.socks host 2>/dev/null || echo ""
            gsettings get org.gnome.system.proxy.socks port 2>/dev/null || echo "0"
        } > "$gsettings_backup" 2>/dev/null && \
            log_info "备份: GNOME 桌面代理设置" || \
            log_warn "备份失败: GNOME 桌面代理设置"
    fi
    
    # 记录备份时间戳
    echo "$(date '+%Y-%m-%d %H:%M:%S')" > "$backup_dir/backup_timestamp.txt" 2>/dev/null || true
    
    return 0
}

# 恢复原始代理设置（用户级）
restore_user_proxy_settings() {
    local backup_dir="$(get_backup_dir)"
    
    if [ ! -d "$backup_dir" ]; then
        # 没有备份，只删除 Clash 标记块（兼容现有行为）
        return 0
    fi
    
    log_info "恢复原始用户代理设置..."
    
    # 恢复 shell 配置文件
    for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
        local basename_rc="$(basename "$rc")"
        if [ -f "$backup_dir/$basename_rc" ]; then
            # 先删除 Clash 标记块
            [ -f "$rc" ] && remove_proxy_block "$rc"
            # 恢复备份
            cp "$backup_dir/$basename_rc" "$rc" 2>/dev/null && \
                log_info "恢复: $rc" || \
                log_warn "恢复失败: $rc"
        else
            # 没有备份，只删除 Clash 标记块
            [ -f "$rc" ] && remove_proxy_block "$rc"
        fi
    done
    
    # 恢复 Git 用户级配置
    if [ -f "$backup_dir/.gitconfig" ]; then
        cp "$backup_dir/.gitconfig" "$HOME/.gitconfig" 2>/dev/null && \
            log_info "恢复: $HOME/.gitconfig" || \
            log_warn "恢复失败: $HOME/.gitconfig"
    else
        # 没有备份，清除 Git 用户级代理
        if command_exists git; then
            git config --global --unset http.proxy 2>/dev/null || true
            git config --global --unset https.proxy 2>/dev/null || true
        fi
    fi
    
    # 恢复 GNOME 桌面代理设置（如果备份存在）
    if command_exists gsettings && [ -f "$backup_dir/gsettings.txt" ]; then
        # 读取备份的 gsettings 值（跳过注释行和时间戳行）
        local proxy_mode=$(grep -v "^#" "$backup_dir/gsettings.txt" | head -n 1 | tr -d "'\"")
        if [ "$proxy_mode" != "none" ] && [ -n "$proxy_mode" ]; then
            # 这里简化处理：如果有备份且有非 none 的设置，提示用户手动恢复
            # 因为 gsettings 设置比较复杂，需要多个命令
            log_info "检测到 GNOME 桌面代理设置备份，请手动检查恢复"
        else
            gsettings set org.gnome.system.proxy mode 'none' 2>/dev/null || true
        fi
    else
        # 没有备份，清除 GNOME 桌面代理
        if command_exists gsettings; then
            gsettings set org.gnome.system.proxy mode 'none' 2>/dev/null || true
        fi
    fi
    
    return 0
}

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
    
    # 备份原始代理设置
    backup_user_proxy_settings || log_warn "备份失败，继续启用代理..."
    
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
    for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
        if [ -f "$rc" ] || [ "$rc" = "$HOME/.bashrc" ] || [ "$rc" = "$HOME/.profile" ]; then
            [ -f "$rc" ] || touch "$rc"
            append_proxy_block "$rc" ". $user_env_file"
        fi
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
    # 先移除 Clash 标记块，然后恢复原始代理设置
    restore_user_proxy_settings || log_warn "恢复失败，继续清理..."
    
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
    
    # 备份原始代理设置
    backup_system_proxy_settings || log_warn "备份失败，继续启用代理..."
    
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
	# yum/dnf
	if [ -f /etc/yum.conf ]; then
		append_proxy_block "/etc/yum.conf" "proxy=${HTTP_PROXY_VAL}"
	fi
	if [ -f /etc/dnf/dnf.conf ]; then
		append_proxy_block "/etc/dnf/dnf.conf" "proxy=${HTTP_PROXY_VAL}"
	fi
	# systemd 全局环境
        if systemd_available; then
                mkdir -p /etc/systemd/system.conf.d
                cat > /etc/systemd/system.conf.d/proxy.conf <<EOF
[Manager]
DefaultEnvironment=HTTP_PROXY=${HTTP_PROXY_VAL} HTTPS_PROXY=${HTTP_PROXY_VAL} ALL_PROXY=${SOCKS_PROXY_VAL} NO_PROXY=${NO_PROXY_VAL}
EOF
                systemctl daemon-reload || true
        fi
        # Docker 守护进程
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
	
	# 恢复原始代理设置
	restore_system_proxy_settings || log_warn "恢复失败，继续清理..."
	
	success "系统级系统代理已关闭"
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
