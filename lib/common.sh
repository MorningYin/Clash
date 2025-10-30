#!/bin/bash
# Clash 安装程序公共函数库
# 作者: Auto
# 日期: 2025-10-30

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$PROJECT_DIR/config.yaml"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# 日志级别
LOG_LEVEL_DEBUG=0
LOG_LEVEL_INFO=1
LOG_LEVEL_WARN=2
LOG_LEVEL_ERROR=3

# 当前日志级别
CURRENT_LOG_LEVEL=$LOG_LEVEL_INFO

# 是否启用颜色输出
ENABLE_COLORS=true

# 日志文件路径
LOG_FILE=""

# 初始化日志系统
init_logging() {
    local log_level=$(get_config_value "logging.level" "info")
    case "$log_level" in
        "debug") CURRENT_LOG_LEVEL=$LOG_LEVEL_DEBUG ;;
        "info") CURRENT_LOG_LEVEL=$LOG_LEVEL_INFO ;;
        "warn") CURRENT_LOG_LEVEL=$LOG_LEVEL_WARN ;;
        "error") CURRENT_LOG_LEVEL=$LOG_LEVEL_ERROR ;;
        *) CURRENT_LOG_LEVEL=$LOG_LEVEL_INFO ;;
    esac
    
    # 设置日志文件
    if is_root; then
        LOG_FILE=$(get_config_value "logging.log_file" "/var/log/clash-installer.log")
    else
        LOG_FILE=$(expand_path "$(get_config_value "logging.user_log_file" "~/.local/log/clash-installer.log")")
    fi
    
    # 创建日志目录
    mkdir -p "$(dirname "$LOG_FILE")"
}

# 检查是否为 root 用户
is_root() {
    [ "$EUID" -eq 0 ]
}

# 获取用户主目录
get_home_dir() {
    if [ -n "$SUDO_USER" ]; then
        getent passwd "$SUDO_USER" | cut -d: -f6
    else
        echo "$HOME"
    fi
}

# 展开路径（处理 ~ 符号）
expand_path() {
    local path="$1"
    if [[ "$path" == ~* ]]; then
        path="${path/#\~/$HOME}"
    fi
    echo "$path"
}

# 简单的 YAML 解析函数
get_config_value() {
    local key="$1"
    local default="$2"
    local value
    
    if [ -f "$CONFIG_FILE" ]; then
        value=$(grep "^[[:space:]]*${key}:" "$CONFIG_FILE" | head -1 | sed 's/.*:[[:space:]]*//' | sed 's/[[:space:]]*$//' | sed 's/^"//' | sed 's/"$//')
    fi
    
    if [ -n "$value" ] && [ "$value" != "null" ]; then
        echo "$value"
    else
        echo "${default:-}"
    fi
}

# 日志输出函数
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_entry="[$timestamp] [$level] $message"
    
    # 输出到控制台
    case "$level" in
        "DEBUG")
            if [ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_DEBUG ]; then
                if [ "$ENABLE_COLORS" = true ]; then
                    echo -e "${PURPLE}[DEBUG]${NC} $message"
                else
                    echo "[DEBUG] $message"
                fi
            fi
            ;;
        "INFO")
            if [ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_INFO ]; then
                if [ "$ENABLE_COLORS" = true ]; then
                    echo -e "${BLUE}[INFO]${NC} $message"
                else
                    echo "[INFO] $message"
                fi
            fi
            ;;
        "WARN")
            if [ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_WARN ]; then
                if [ "$ENABLE_COLORS" = true ]; then
                    echo -e "${YELLOW}[WARN]${NC} $message"
                else
                    echo "[WARN] $message"
                fi
            fi
            ;;
        "ERROR")
            if [ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_ERROR ]; then
                if [ "$ENABLE_COLORS" = true ]; then
                    echo -e "${RED}[ERROR]${NC} $message"
                else
                    echo "[ERROR] $message"
                fi
            fi
            ;;
    esac
    
    # 输出到日志文件
    if [ -n "$LOG_FILE" ]; then
        echo "$log_entry" >> "$LOG_FILE"
    fi
}

# 便捷日志函数
log_debug() { log "DEBUG" "$1"; }
log_info() { log "INFO" "$1"; }
log_warn() { log "WARN" "$1"; }
log_error() { log "ERROR" "$1"; }

# 成功消息
success() {
    if [ "$ENABLE_COLORS" = true ]; then
        echo -e "${GREEN}✓${NC} $1"
    else
        echo "✓ $1"
    fi
    log_info "$1"
}

# 错误消息
error() {
    if [ "$ENABLE_COLORS" = true ]; then
        echo -e "${RED}✗${NC} $1"
    else
        echo "✗ $1"
    fi
    log_error "$1"
}

# 警告消息
warn() {
    if [ "$ENABLE_COLORS" = true ]; then
        echo -e "${YELLOW}⚠${NC} $1"
    else
        echo "⚠ $1"
    fi
    log_warn "$1"
}

# 信息消息
info() {
    if [ "$ENABLE_COLORS" = true ]; then
        echo -e "${BLUE}ℹ${NC} $1"
    else
        echo "ℹ $1"
    fi
    log_info "$1"
}

# 用户确认函数
confirm() {
    local prompt="$1"
    local default="${2:-n}"
    local response
    
    if [ "$default" = "y" ]; then
        prompt="$prompt [Y/n]: "
    else
        prompt="$prompt [y/N]: "
    fi
    
    while true; do
        read -p "$prompt" response
        response=${response:-$default}
        case $response in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "请输入 y 或 n";;
        esac
    done
}

# 进度条显示
show_progress() {
    local current="$1"
    local total="$2"
    local width=50
    local percentage=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    
    printf "\r["
    printf "%${filled}s" | tr ' ' '='
    printf "%${empty}s" | tr ' ' ' '
    printf "] %d%% (%d/%d)" "$percentage" "$current" "$total"
}

# 检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 检查依赖
check_dependencies() {
    local missing_deps=()
    local required_deps=($(get_config_value "dependencies.required" ""))
    
    for dep in "${required_deps[@]}"; do
        if ! command_exists "$dep"; then
            missing_deps+=("$dep")
        fi
    done
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        error "缺少必要依赖: ${missing_deps[*]}"
        info "请安装缺少的依赖后重试"
        return 1
    fi
    
    return 0
}

# 检查系统架构
check_architecture() {
    local arch=$(uname -m)
    local supported_archs=($(get_config_value "system.supported_archs" "x86_64 amd64"))
    
    for supported_arch in "${supported_archs[@]}"; do
        if [ "$arch" = "$supported_arch" ]; then
            return 0
        fi
    done
    
    error "不支持的架构: $arch"
    info "支持的架构: ${supported_archs[*]}"
    return 1
}

# 检查操作系统
check_os() {
    local os=$(uname -s | tr '[:upper:]' '[:lower:]')
    local supported_os=($(get_config_value "system.supported_os" "linux"))
    
    for supported in "${supported_os[@]}"; do
        if [ "$os" = "$supported" ]; then
            return 0
        fi
    done
    
    error "不支持的操作系统: $os"
    info "支持的操作系统: ${supported_os[*]}"
    return 1
}

# 检查系统资源
check_system_resources() {
    local min_memory=$(get_config_value "system.min_memory" "128")
    local min_disk_space=$(get_config_value "system.min_disk_space" "100")
    
    # 检查内存
    local available_memory=$(free -m | awk 'NR==2{printf "%.0f", $7}')
    if [ "$available_memory" -lt "$min_memory" ]; then
        warn "可用内存不足: ${available_memory}MB < ${min_memory}MB"
    fi
    
    # 检查磁盘空间
    local available_disk=$(df -m / | awk 'NR==2{print $4}')
    if [ "$available_disk" -lt "$min_disk_space" ]; then
        warn "可用磁盘空间不足: ${available_disk}MB < ${min_disk_space}MB"
    fi
}

# 下载文件
download_file() {
    local url="$1"
    local output="$2"
    local timeout=$(get_config_value "security.download_timeout" "300")
    
    log_info "下载文件: $url"
    
    if command_exists curl; then
        curl -L --connect-timeout "$timeout" --max-time "$timeout" -o "$output" "$url"
    elif command_exists wget; then
        wget --timeout="$timeout" -O "$output" "$url"
    else
        error "没有可用的下载工具 (curl 或 wget)"
        return 1
    fi
}

# 验证文件校验和
verify_checksum() {
    local file="$1"
    local expected_checksum="$2"
    
    if [ -z "$expected_checksum" ]; then
        return 0
    fi
    
    local actual_checksum=$(sha256sum "$file" | cut -d' ' -f1)
    if [ "$actual_checksum" = "$expected_checksum" ]; then
        log_info "文件校验和验证通过"
        return 0
    else
        error "文件校验和验证失败"
        log_error "期望: $expected_checksum"
        log_error "实际: $actual_checksum"
        return 1
    fi
}

# 创建目录
create_directory() {
    local dir="$1"
    local mode="${2:-755}"
    
    if [ ! -d "$dir" ]; then
        log_info "创建目录: $dir"
        mkdir -p "$dir"
        chmod "$mode" "$dir"
    fi
}

# 复制文件
copy_file() {
    local src="$1"
    local dst="$2"
    local mode="${3:-755}"
    
    if [ -f "$src" ]; then
        log_info "复制文件: $src -> $dst"
        cp "$src" "$dst"
        chmod "$mode" "$dst"
        return 0
    else
        error "源文件不存在: $src"
        return 1
    fi
}

# 设置文件权限
set_permissions() {
    local file="$1"
    local mode="$2"
    local owner="$3"
    
    if [ -f "$file" ] || [ -d "$file" ]; then
        chmod "$mode" "$file"
        if [ -n "$owner" ]; then
            chown "$owner" "$file"
        fi
        log_debug "设置权限: $file ($mode, $owner)"
    fi
}

# 错误处理
handle_error() {
    local exit_code=$?
    local line_number=$1
    local command="$2"
    
    if [ $exit_code -ne 0 ]; then
        error "命令执行失败 (退出码: $exit_code)"
        error "位置: 第 $line_number 行"
        error "命令: $command"
        exit $exit_code
    fi
}

# 设置错误捕获
set_error_trap() {
    trap 'handle_error $LINENO "$BASH_COMMAND"' ERR
}

# 清理函数
cleanup() {
    log_info "执行清理操作"
    # 这里可以添加清理逻辑
}

# 设置清理陷阱
set_cleanup_trap() {
    trap cleanup EXIT
}

# 获取安装路径
get_install_paths() {
    if is_root; then
        CLASH_BIN_DIR=$(get_config_value "install.clash_bin_dir" "/usr/local/bin")
        CLASH_CONFIG_DIR=$(get_config_value "install.clash_config_dir" "/etc/clash")
    else
        CLASH_BIN_DIR=$(expand_path "$(get_config_value "install.clash_user_config_dir" "~/.local/bin")")
        CLASH_CONFIG_DIR=$(expand_path "$(get_config_value "install.clash_user_config_dir" "~/.config/clash")")
    fi
    
    export CLASH_BIN_DIR
    export CLASH_CONFIG_DIR
}

# 初始化函数
init() {
    # 设置错误捕获
    set_error_trap
    
    # 设置清理陷阱
    set_cleanup_trap
    
    # 初始化日志
    init_logging
    
    # 检查系统
    check_os || exit 1
    check_architecture || exit 1
    check_dependencies || exit 1
    check_system_resources
    
    # 获取安装路径
    get_install_paths
    
    log_info "Clash 安装程序初始化完成"
}
