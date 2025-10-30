#!/bin/bash
# 系统/用户级 一键代理设置库
# 依赖: lib/common.sh

source "$(dirname "$0")/common.sh"

# 常量与工具
PROXY_MARK_BEGIN="# >>> clash-installer proxy BEGIN"
PROXY_MARK_END="# <<< clash-installer proxy END"

get_http_port() { get_config_value "install.http_port" "7890"; }
get_socks_port() { get_config_value "install.socks_port" "7891"; }

proxy_values_init() {
	HTTP_PORT="$(get_http_port)"
	SOCKS_PORT="$(get_socks_port)"
	HTTP_PROXY_VAL="http://127.0.0.1:${HTTP_PORT}"
	SOCKS_PROXY_VAL="socks5://127.0.0.1:${SOCKS_PORT}"
	NO_PROXY_VAL="localhost,127.0.0.1,::1"
}

# 文件写入: 以标记包裹，便于回滚
append_proxy_block() {
	local target_file="$1"
	local content="$2"
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

remove_proxy_block() {
	local target_file="$1"
	[ -f "$target_file" ] || return 0
	sed -i "/$PROXY_MARK_BEGIN/,/$PROXY_MARK_END/d" "$target_file"
}

# 用户级: shell 环境 + git + gsettings
user_proxy_on() {
	proxy_values_init
	local cfg_dir="$CLASH_CONFIG_DIR"
	local user_env_file="$cfg_dir/proxy-env.sh"
	create_directory "$cfg_dir" "755"
	cat > "$user_env_file" <<EOF
#!/bin/bash
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
	# shell 配置
	for rc in "$HOME/.bashrc" "$HOME/.profile"; do
		[ -f "$rc" ] || touch "$rc"
		append_proxy_block "$rc" ". $user_env_file"
	done
	# git 全局
	if command_exists git; then
		git config --global http.proxy "$HTTP_PROXY_VAL" || true
		git config --global https.proxy "$HTTP_PROXY_VAL" || true
	fi
	# GNOME 桌面代理
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

user_proxy_off() {
	# 移除 shell 配置
	for rc in "$HOME/.bashrc" "$HOME/.profile"; do
		[ -f "$rc" ] && remove_proxy_block "$rc"
	done
	# git 全局
	if command_exists git; then
		git config --global --unset http.proxy 2>/dev/null || true
		git config --global --unset https.proxy 2>/dev/null || true
	fi
	# GNOME 桌面代理
	if command_exists gsettings; then
		gsettings set org.gnome.system.proxy mode 'none' || true
	fi
	success "用户级系统代理已关闭"
}

# 系统级: /etc/* + systemd + docker + git --system
system_proxy_on() {
	proxy_values_init
	if ! is_root; then
		error "需要 root 权限才能开启系统级代理"
		return 1
	fi
	# /etc/environment
	local env_file="/etc/environment"
	[ -f "$env_file" ] || touch "$env_file"
	append_proxy_block "$env_file" "HTTP_PROXY=${HTTP_PROXY_VAL}\nHTTPS_PROXY=${HTTP_PROXY_VAL}\nhttp_proxy=${HTTP_PROXY_VAL}\nhttps_proxy=${HTTP_PROXY_VAL}\nALL_PROXY=${SOCKS_PROXY_VAL}\nall_proxy=${SOCKS_PROXY_VAL}\nNO_PROXY=${NO_PROXY_VAL}\nno_proxy=${NO_PROXY_VAL}"
	# apt
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
	if command_exists systemctl; then
		mkdir -p /etc/systemd/system.conf.d
		cat > /etc/systemd/system.conf.d/proxy.conf <<EOF
[Manager]
DefaultEnvironment=HTTP_PROXY=${HTTP_PROXY_VAL} HTTPS_PROXY=${HTTP_PROXY_VAL} ALL_PROXY=${SOCKS_PROXY_VAL} NO_PROXY=${NO_PROXY_VAL}
EOF
		systemctl daemon-reload || true
	fi
	# Docker 守护进程
	if command_exists systemctl && [ -d /etc/systemd/system ]; then
		mkdir -p /etc/systemd/system/docker.service.d
		cat > /etc/systemd/system/docker.service.d/proxy.conf <<EOF
[Service]
Environment=HTTP_PROXY=${HTTP_PROXY_VAL}
Environment=HTTPS_PROXY=${HTTP_PROXY_VAL}
Environment=NO_PROXY=${NO_PROXY_VAL}
EOF
		# 尝试重载 docker
		systemctl daemon-reload || true
		systemctl restart docker 2>/dev/null || true
	fi
	# git system/global
	if command_exists git; then
		git config --system http.proxy "$HTTP_PROXY_VAL" 2>/dev/null || true
		git config --system https.proxy "$HTTP_PROXY_VAL" 2>/dev/null || true
	fi
	success "系统级系统代理已开启"
}

system_proxy_off() {
	if ! is_root; then
		error "需要 root 权限才能关闭系统级代理"
		return 1
	fi
	# /etc/environment
	[ -f /etc/environment ] && remove_proxy_block /etc/environment
	# apt
	rm -f /etc/apt/apt.conf.d/95clash-proxy 2>/dev/null || true
	# yum/dnf
	[ -f /etc/yum.conf ] && remove_proxy_block /etc/yum.conf
	[ -f /etc/dnf/dnf.conf ] && remove_proxy_block /etc/dnf/dnf.conf
	# systemd 全局
	if command_exists systemctl; then
		rm -f /etc/systemd/system.conf.d/proxy.conf 2>/dev/null || true
		systemctl daemon-reload || true
	fi
	# docker
	if command_exists systemctl; then
		rm -f /etc/systemd/system/docker.service.d/proxy.conf 2>/dev/null || true
		systemctl daemon-reload || true
		# 不强制重启 docker，避免打断业务
	fi
	# git system/global
	if command_exists git; then
		git config --system --unset http.proxy 2>/dev/null || true
		git config --system --unset https.proxy 2>/dev/null || true
	fi
	success "系统级系统代理已关闭"
}

# 入口 API：proxy_on/off [--system|--user]
proxy_on() {
	local scope="$1"
	if [ "$scope" = "--system" ]; then
		system_proxy_on
	elif [ "$scope" = "--user" ]; then
		user_proxy_on
	else
		if is_root; then system_proxy_on; else user_proxy_on; fi
	fi
}

proxy_off() {
	local scope="$1"
	if [ "$scope" = "--system" ]; then
		system_proxy_off
	elif [ "$scope" = "--user" ]; then
		user_proxy_off
	else
		if is_root; then system_proxy_off; else user_proxy_off; fi
	fi
}
