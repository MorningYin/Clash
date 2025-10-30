#!/bin/bash
# Clash 安装逻辑
# 作者: Auto
# 日期: 2025-10-30

# 加载公共函数
INSTALLER_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$INSTALLER_LIB_DIR/common.sh"

# 安装 Clash 核心程序
install_clash_core() {
    log_info "开始安装 Clash 核心程序"
    
    local local_path=$(get_config_value "packages.clash.local_path" "")
    local download_url=$(get_config_value "packages.clash.download_url" "")
    local checksum=$(get_config_value "packages.clash.checksum" "")
    
    # 检查本地文件
    if [ -n "$local_path" ]; then
        local_path="$PROJECT_DIR/$local_path"
        if [ -f "$local_path" ]; then
            log_info "使用本地 Clash 安装包: $local_path"
            install_from_local "$local_path" "$CLASH_BIN_DIR/clash"
            return $?
        else
            log_warn "本地文件不存在: $local_path"
        fi
    fi
    
    # 从网络下载
    if [ -n "$download_url" ]; then
        log_info "从网络下载 Clash: $download_url"
        local temp_file="/tmp/clash-$(date +%s).gz"
        if download_file "$download_url" "$temp_file"; then
            install_from_local "$temp_file" "$CLASH_BIN_DIR/clash"
            local result=$?
            rm -f "$temp_file"
            return $result
        else
            error "下载 Clash 失败"
            return 1
        fi
    else
        error "没有可用的 Clash 安装包"
        return 1
    fi
}

# 从本地文件安装
install_from_local() {
    local source_file="$1"
    local target_file="$2"
    
    log_info "从本地文件安装: $source_file -> $target_file"
    
    # 如果是压缩文件，先解压
    if [[ "$source_file" == *.gz ]]; then
        local temp_file="/tmp/clash-$(date +%s)"
        if gunzip -c "$source_file" > "$temp_file"; then
            chmod +x "$temp_file"
            copy_file "$temp_file" "$target_file" "755"
            local result=$?
            rm -f "$temp_file"
            return $result
        else
            error "解压文件失败: $source_file"
            return 1
        fi
    else
        chmod +x "$source_file"
        copy_file "$source_file" "$target_file" "755"
        return $?
    fi
}

# 安装 Country.mmdb
install_country_mmdb() {
    log_info "开始安装 Country.mmdb"
    
    local local_path=$(get_config_value "packages.country_mmdb.local_path" "")
    local download_url=$(get_config_value "packages.country_mmdb.download_url" "")
    local checksum=$(get_config_value "packages.country_mmdb.checksum" "")
    
    local target_file="$CLASH_CONFIG_DIR/Country.mmdb"
    
    # 检查本地文件
    if [ -n "$local_path" ]; then
        local_path="$PROJECT_DIR/$local_path"
        if [ -f "$local_path" ]; then
            log_info "使用本地 Country.mmdb: $local_path"
            copy_file "$local_path" "$target_file" "644"
            return $?
        else
            log_warn "本地文件不存在: $local_path"
        fi
    fi
    
    # 从网络下载
    if [ -n "$download_url" ]; then
        log_info "从网络下载 Country.mmdb: $download_url"
        local temp_file="/tmp/country-$(date +%s).mmdb"
        if download_file "$download_url" "$temp_file"; then
            copy_file "$temp_file" "$target_file" "644"
            local result=$?
            rm -f "$temp_file"
            return $result
        else
            error "下载 Country.mmdb 失败"
            return 1
        fi
    else
        warn "没有可用的 Country.mmdb，Clash 将自动下载"
        return 0
    fi
}

# 生成 Clash 配置文件
generate_clash_config() {
    log_info "生成 Clash 配置文件"
    
    local config_file="$CLASH_CONFIG_DIR/config.yaml"
    local template_file="$PROJECT_DIR/templates/config.yaml.tpl"
    
    if [ ! -f "$template_file" ]; then
        error "配置文件模板不存在: $template_file"
        return 1
    fi
    
    # 获取配置值
    local http_port=$(get_config_value "install.http_port" "7890")
    local socks_port=$(get_config_value "install.socks_port" "7891")
    local api_port=$(get_config_value "install.api_port" "9090")
    local dns_port=$(get_config_value "install.dns_port" "53")
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # 替换模板变量
    sed -e "s/{{HTTP_PORT}}/$http_port/g" \
        -e "s/{{SOCKS_PORT}}/$socks_port/g" \
        -e "s/{{API_PORT}}/$api_port/g" \
        -e "s/{{DNS_PORT}}/$dns_port/g" \
        -e "s/{{TIMESTAMP}}/$timestamp/g" \
        "$template_file" > "$config_file"
    
    if [ $? -eq 0 ]; then
        success "配置文件生成成功: $config_file"
        return 0
    else
        error "配置文件生成失败"
        return 1
    fi
}

# 下载并转换订阅
download_subscription() {
    log_info "下载并转换订阅配置"
    
    local subscription_url=$(get_config_value "subscription.url" "")
    if [ -z "$subscription_url" ]; then
        warn "没有配置订阅链接，跳过订阅下载"
        return 0
    fi
    
    local config_file="$CLASH_CONFIG_DIR/config.yaml"
    local temp_file="/tmp/subscription-$(date +%s).tmp"
    
    # 下载订阅内容
    if download_file "$subscription_url" "$temp_file"; then
        # 检查是否为 Base64 编码
        if head -n 1 "$temp_file" | grep -Eq '^[A-Za-z0-9+/=]+$'; then
            log_info "检测到 Base64 编码，正在解码"
            base64 -d "$temp_file" > "${temp_file}.decoded"
            mv "${temp_file}.decoded" "$temp_file"
        fi
        
        # 检查是否为节点链接格式
        if head -n 1 "$temp_file" | grep -q "^ss://\|^trojan://\|^vmess://"; then
            log_info "检测到节点链接格式，正在转换为 Clash 配置"
            convert_subscription_to_clash "$temp_file" "$config_file"
        else
            # 直接使用下载的配置文件
            copy_file "$temp_file" "$config_file" "644"
        fi
        
        local result=$?
        rm -f "$temp_file"
        return $result
    else
        error "下载订阅失败"
        return 1
    fi
}

# 转换订阅为 Clash 配置
convert_subscription_to_clash() {
    local input_file="$1"
    local output_file="$2"
    
    log_info "转换订阅为 Clash 配置"
    
    # 使用 Python 脚本转换
    python3 -c "
import yaml
import base64
import urllib.parse

# 读取节点链接
with open('$input_file', 'r', encoding='utf-8') as f:
    lines = f.readlines()

proxies = []

# 解析节点链接
for line in lines:
    line = line.strip()
    if not line:
        continue
        
    if line.startswith('ss://'):
        # 解析 SS 链接
        try:
            url_part = line[5:]  # 去掉 ss://
            if '#' in url_part:
                url_part, name = url_part.split('#', 1)
                name = name.replace('%E2%9D%97', '❗')
                name = name.replace('%E6%82%A8%E5%BD%93%E5%89%8D%E5%AE%A2%E6%88%B7%E7%AB%AFv2rayN%E4%B8%8D%E6%94%AF%E6%8C%81hy%E5%8D%8F%E8%AE%AE', '您当前客户端v2rayN不支持hy协议')
                name = name.replace('%E8%AF%B7%E5%88%B0%E6%88%91%E4%BB%AC%E6%96%87%E6%A1%A3%E4%B8%AD%E4%B8%8B%E8%BD%BDClash%20Verge', '请到我们文档中下载Clash Verge')
                name = name.replace('%E6%96%87%E6%A1%A3%20https%3A%2F%2Fpanel.dg5.biz%2F%23%2Fknowledge', '文档 https://panel.dg5.biz/#/knowledge')
            else:
                name = 'SS节点'
            
            # 解码 Base64
            decoded = base64.b64decode(url_part + '==').decode('utf-8')
            method, server_info = decoded.split(':', 1)
            password, server_port = server_info.rsplit('@', 1)
            server, port = server_port.split(':')
            
            proxy = {
                'name': name,
                'type': 'ss',
                'server': server,
                'port': int(port),
                'cipher': method,
                'password': password
            }
            proxies.append(proxy)
        except:
            continue
            
    elif line.startswith('trojan://'):
        # 解析 Trojan 链接
        try:
            url_part = line[9:]  # 去掉 trojan://
            if '#' in url_part:
                url_part, name = url_part.split('#', 1)
                name = urllib.parse.unquote(name)
            else:
                name = 'Trojan节点'
            
            if '@' in url_part:
                password, server_info = url_part.split('@', 1)
            else:
                continue
                
            if '?' in server_info:
                server_part, params = server_info.split('?', 1)
            else:
                server_part = server_info
                params = ''
                
            if ':' in server_part:
                server, port = server_part.split(':')
            else:
                continue
                
            proxy = {
                'name': name,
                'type': 'trojan',
                'server': server,
                'port': int(port),
                'password': password,
                'sni': server,
                'udp': True,
                'network': 'ws',
                'ws-opts': {},
                'skip-cert-verify': True
            }
            proxies.append(proxy)
        except:
            continue

# 创建代理组
proxy_groups = [
    {
        'name': '自动选择',
        'type': 'url-test',
        'proxies': [p['name'] for p in proxies],
        'url': 'http://www.gstatic.com/generate_204',
        'interval': 300,
        'timeout': 3000
    },
    {
        'name': '节点选择',
        'type': 'select',
        'proxies': ['自动选择'] + [p['name'] for p in proxies]
    },
    {
        'name': '全球直连',
        'type': 'select',
        'proxies': ['DIRECT']
    }
]

# 创建规则
rules = [
    'DOMAIN-SUFFIX,local,DIRECT',
    'IP-CIDR,127.0.0.0/8,DIRECT',
    'IP-CIDR,172.16.0.0/12,DIRECT',
    'IP-CIDR,192.168.0.0/16,DIRECT',
    'IP-CIDR,10.0.0.0/8,DIRECT',
    'IP-CIDR,17.0.0.0/8,DIRECT',
    'IP-CIDR,100.64.0.0/10,DIRECT',
    'DOMAIN-SUFFIX,cn,DIRECT',
    'DOMAIN-KEYWORD,-cn,DIRECT',
    'GEOIP,CN,全球直连',
    'MATCH,节点选择'
]

# 读取现有配置
with open('$output_file', 'r', encoding='utf-8') as f:
    config = yaml.safe_load(f)

# 更新配置
config['proxies'] = proxies
config['proxy-groups'] = proxy_groups
config['rules'] = rules

# 写入配置文件
with open('$output_file', 'w', encoding='utf-8') as f:
    yaml.dump(config, f, default_flow_style=False, allow_unicode=True)

print(f'成功转换 {len(proxies)} 个节点')
" 2>/dev/null || {
        error "转换订阅失败，需要安装 PyYAML"
        return 1
    }
    
    success "订阅转换完成"
    return 0
}

# 创建更新脚本
create_update_script() {
    log_info "创建订阅更新脚本"
    
    local update_script="$CLASH_CONFIG_DIR/update-subscription.sh"
    local subscription_url=$(get_config_value "subscription.url" "")
    
    cat > "$update_script" << EOF
#!/bin/bash
# Clash 订阅更新脚本
# 由 Clash 安装程序自动生成

set -e

SUBSCRIPTION_URL="$subscription_url"
CONFIG_FILE="$CLASH_CONFIG_DIR/config.yaml"
BACKUP_FILE="$CLASH_CONFIG_DIR/config.yaml.backup"
LOG_FILE="$CLASH_CONFIG_DIR/update.log"

log() {
    echo "[\$(date '+%Y-%m-%d %H:%M:%S')] \$1" | tee -a "\$LOG_FILE"
}

# 环境检查
if ! python3 -c "import yaml" >/dev/null 2>&1; then
    log "错误: 需要 PyYAML 支持，请先安装 python3-yaml 或执行: python3 -m pip install PyYAML"
    exit 1
fi

# 备份当前配置
if [ -f "\$CONFIG_FILE" ]; then
    log "备份当前配置文件"
    cp "\$CONFIG_FILE" "\$BACKUP_FILE"
fi

# 下载新配置
log "开始下载订阅配置..."
if curl -s -L -o "\$CONFIG_FILE.tmp" "\$SUBSCRIPTION_URL"; then
    log "订阅配置下载成功"
    
    # 检查是否为 Base64 编码
    if head -n 1 "\$CONFIG_FILE.tmp" | grep -Eq '^[A-Za-z0-9+/=]+$'; then
        log "检测到 Base64 编码，正在解码..."
        base64 -d "\$CONFIG_FILE.tmp" > "\$CONFIG_FILE.tmp.decoded"
        mv "\$CONFIG_FILE.tmp.decoded" "\$CONFIG_FILE.tmp"
        log "Base64 解码完成"
    fi

    # 检查是否为节点链接格式
    if head -n 1 "\$CONFIG_FILE.tmp" | grep -q "^ss://\\|^trojan://\\|^vmess://"; then
        log "检测到节点链接格式，正在转换为 Clash 配置..."
        python3 -c "
import yaml
import base64
import urllib.parse

with open('\$CONFIG_FILE.tmp', 'r', encoding='utf-8') as f:
    lines = f.readlines()

proxies = []

for line in lines:
    line = line.strip()
    if not line:
        continue
        
    if line.startswith('ss://'):
        try:
            url_part = line[5:]
            if '#' in url_part:
                url_part, name = url_part.split('#', 1)
                name = name.replace('%E2%9D%97', '❗')
            else:
                name = 'SS节点'
            
            decoded = base64.b64decode(url_part + '==').decode('utf-8')
            method, server_info = decoded.split(':', 1)
            password, server_port = server_info.rsplit('@', 1)
            server, port = server_port.split(':')
            
            proxy = {
                'name': name,
                'type': 'ss',
                'server': server,
                'port': int(port),
                'cipher': method,
                'password': password
            }
            proxies.append(proxy)
        except:
            continue
            
    elif line.startswith('trojan://'):
        try:
            url_part = line[9:]
            if '#' in url_part:
                url_part, name = url_part.split('#', 1)
                name = urllib.parse.unquote(name)
            else:
                name = 'Trojan节点'
            
            if '@' in url_part:
                password, server_info = url_part.split('@', 1)
            else:
                continue
                
            if '?' in server_info:
                server_part, params = server_info.split('?', 1)
            else:
                server_part = server_info
                
            if ':' in server_part:
                server, port = server_part.split(':')
            else:
                continue
                
            proxy = {
                'name': name,
                'type': 'trojan',
                'server': server,
                'port': int(port),
                'password': password,
                'sni': server,
                'udp': True,
                'network': 'ws',
                'ws-opts': {},
                'skip-cert-verify': True
            }
            proxies.append(proxy)
        except:
            continue

proxy_groups = [
    {
        'name': '自动选择',
        'type': 'url-test',
        'proxies': [p['name'] for p in proxies],
        'url': 'http://www.gstatic.com/generate_204',
        'interval': 300,
        'timeout': 3000
    },
    {
        'name': '节点选择',
        'type': 'select',
        'proxies': ['自动选择'] + [p['name'] for p in proxies]
    },
    {
        'name': '全球直连',
        'type': 'select',
        'proxies': ['DIRECT']
    }
]

rules = [
    'DOMAIN-SUFFIX,local,DIRECT',
    'IP-CIDR,127.0.0.0/8,DIRECT',
    'IP-CIDR,172.16.0.0/12,DIRECT',
    'IP-CIDR,192.168.0.0/16,DIRECT',
    'IP-CIDR,10.0.0.0/8,DIRECT',
    'IP-CIDR,17.0.0.0/8,DIRECT',
    'IP-CIDR,100.64.0.0/10,DIRECT',
    'DOMAIN-SUFFIX,cn,DIRECT',
    'DOMAIN-KEYWORD,-cn,DIRECT',
    'GEOIP,CN,全球直连',
    'MATCH,节点选择'
]

with open('\$CONFIG_FILE.tmp', 'r', encoding='utf-8') as f:
    config = yaml.safe_load(f)

config['proxies'] = proxies
config['proxy-groups'] = proxy_groups
config['rules'] = rules

with open('\$CONFIG_FILE.tmp', 'w', encoding='utf-8') as f:
    yaml.dump(config, f, default_flow_style=False, allow_unicode=True)

print(f'成功转换 {len(proxies)} 个节点')
" 2>/dev/null || {
            log "错误: 无法转换节点链接格式"
            exit 1
        }
        log "节点链接转换完成"
    fi
    
    # 验证配置文件
    if $CLASH_BIN_DIR/clash -t -f "\$CONFIG_FILE.tmp" >/dev/null 2>&1; then
        log "配置文件验证通过"
        mv "\$CONFIG_FILE.tmp" "\$CONFIG_FILE"
        log "配置文件更新完成"
        
        # 重启 Clash 服务（如果正在运行）
        if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
            if systemctl is-active --quiet clash 2>/dev/null; then
                log "重启 Clash 服务"
                systemctl restart clash
                log "Clash 服务重启完成"
            fi
        else
            log "systemd 不可用，跳过服务重启"
        fi
        
        log "订阅更新成功完成"
        exit 0
    else
        log "错误: 配置文件验证失败"
        rm -f "\$CONFIG_FILE.tmp"
        if [ -f "\$BACKUP_FILE" ]; then
            log "恢复备份配置文件"
            mv "\$BACKUP_FILE" "\$CONFIG_FILE"
        fi
        exit 1
    fi
else
    log "错误: 无法下载订阅配置"
    rm -f "\$CONFIG_FILE.tmp"
    exit 1
fi
EOF
    
    chmod +x "$update_script"
    success "更新脚本创建成功: $update_script"
}

# 设置定时任务
setup_cron() {
    local auto_update=$(get_config_value "subscription.auto_update" "true")
    local update_interval=$(get_config_value "subscription.update_interval" "24")
    
    if [ "$auto_update" = "true" ]; then
        log_info "设置自动更新定时任务"

        if ! command_exists crontab; then
            log_warn "系统未安装 crontab，跳过自动更新任务，请手动配置 cron 服务"
            return 0
        fi

        local cron_job="0 */$update_interval * * * $CLASH_CONFIG_DIR/update-subscription.sh"

        # 检查是否已存在相同的定时任务
        if ! crontab -l 2>/dev/null | grep -q "update-subscription.sh"; then
            (crontab -l 2>/dev/null; echo "$cron_job") | crontab -
            success "定时任务设置成功: 每 $update_interval 小时更新一次"
        else
            log_info "定时任务已存在，跳过设置"
        fi
    else
        log_info "自动更新已禁用"
    fi
}

# 主安装函数
install_clash() {
    log_info "开始安装 Clash"
    
    # 创建目录
    create_directory "$CLASH_BIN_DIR" "755"
    create_directory "$CLASH_CONFIG_DIR" "755"
    
    # 若已存在可执行文件则跳过核心安装
    if command_exists clash || [ -x "$CLASH_BIN_DIR/clash" ]; then
        log_info "检测到已存在 Clash 可执行文件，跳过核心安装"
    else
        if ! install_clash_core; then
            error "安装 Clash 核心失败"
            return 1
        fi
    fi
    
    # 安装 Country.mmdb
    install_country_mmdb
    
    # 生成配置文件
    if ! generate_clash_config; then
        error "生成配置文件失败"
        return 1
    fi
    
    # 下载订阅
    download_subscription
    
    # 创建更新脚本
    create_update_script
    
    # 设置定时任务
    setup_cron
    
    success "Clash 安装完成"
    return 0
}
