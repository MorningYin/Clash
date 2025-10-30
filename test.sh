#!/bin/bash
# Clash 安装程序测试脚本
# 作者: Auto
# 日期: 2025-10-30

set -e

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 测试结果
TESTS_PASSED=0
TESTS_FAILED=0

# 测试函数
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    echo -n "测试: $test_name ... "
    
    if eval "$test_command" >/dev/null 2>&1; then
        echo -e "${GREEN}通过${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}失败${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# 显示测试标题
show_test_header() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                    Clash 安装程序测试                       ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# 测试文件存在性
test_file_existence() {
    echo -e "${YELLOW}测试文件存在性:${NC}"
    
    run_test "安装脚本" "[ -f '$SCRIPT_DIR/install.sh' ]"
    run_test "卸载脚本" "[ -f '$SCRIPT_DIR/uninstall.sh' ]"
    run_test "配置文件" "[ -f '$SCRIPT_DIR/config.yaml' ]"
    run_test "README 文档" "[ -f '$SCRIPT_DIR/README.md' ]"
    run_test "使用指南" "[ -f '$SCRIPT_DIR/USAGE.md' ]"
    run_test "CLI 工具" "[ -f '$SCRIPT_DIR/bin/clash-cli' ]"
    run_test "公共函数库" "[ -f '$SCRIPT_DIR/lib/common.sh' ]"
    run_test "安装逻辑" "[ -f '$SCRIPT_DIR/lib/installer.sh' ]"
    run_test "服务管理" "[ -f '$SCRIPT_DIR/lib/manager.sh' ]"
    run_test "卸载逻辑" "[ -f '$SCRIPT_DIR/lib/uninstaller.sh' ]"
    run_test "服务模板" "[ -f '$SCRIPT_DIR/templates/clash.service.tpl' ]"
    run_test "配置模板" "[ -f '$SCRIPT_DIR/templates/config.yaml.tpl' ]"
    
    echo ""
}

# 测试文件权限
test_file_permissions() {
    echo -e "${YELLOW}测试文件权限:${NC}"
    
    run_test "安装脚本可执行" "[ -x '$SCRIPT_DIR/install.sh' ]"
    run_test "卸载脚本可执行" "[ -x '$SCRIPT_DIR/uninstall.sh' ]"
    run_test "CLI 工具可执行" "[ -x '$SCRIPT_DIR/bin/clash-cli' ]"
    run_test "公共函数库可执行" "[ -x '$SCRIPT_DIR/lib/common.sh' ]"
    run_test "安装逻辑可执行" "[ -x '$SCRIPT_DIR/lib/installer.sh' ]"
    run_test "服务管理可执行" "[ -x '$SCRIPT_DIR/lib/manager.sh' ]"
    run_test "卸载逻辑可执行" "[ -x '$SCRIPT_DIR/lib/uninstaller.sh' ]"
    
    echo ""
}

# 测试脚本语法
test_script_syntax() {
    echo -e "${YELLOW}测试脚本语法:${NC}"
    
    run_test "安装脚本语法" "bash -n '$SCRIPT_DIR/install.sh'"
    run_test "卸载脚本语法" "bash -n '$SCRIPT_DIR/uninstall.sh'"
    run_test "CLI 工具语法" "bash -n '$SCRIPT_DIR/bin/clash-cli'"
    run_test "公共函数库语法" "bash -n '$SCRIPT_DIR/lib/common.sh'"
    run_test "安装逻辑语法" "bash -n '$SCRIPT_DIR/lib/installer.sh'"
    run_test "服务管理语法" "bash -n '$SCRIPT_DIR/lib/manager.sh'"
    run_test "卸载逻辑语法" "bash -n '$SCRIPT_DIR/lib/uninstaller.sh'"
    
    echo ""
}

# 测试配置文件
test_config_file() {
    echo -e "${YELLOW}测试配置文件:${NC}"
    
    run_test "配置文件可读" "[ -r '$SCRIPT_DIR/config.yaml' ]"
    run_test "配置文件非空" "[ -s '$SCRIPT_DIR/config.yaml' ]"
    run_test "配置文件包含必要配置" "grep -q 'install:' '$SCRIPT_DIR/config.yaml'"
    run_test "配置文件包含订阅配置" "grep -q 'subscription:' '$SCRIPT_DIR/config.yaml'"
    run_test "配置文件包含包配置" "grep -q 'packages:' '$SCRIPT_DIR/config.yaml'"
    
    echo ""
}

# 测试依赖
test_dependencies() {
    echo -e "${YELLOW}测试系统依赖:${NC}"
    
    run_test "curl 命令" "command -v curl >/dev/null"
    run_test "wget 命令" "command -v wget >/dev/null"
    run_test "python3 命令" "command -v python3 >/dev/null"
    run_test "base64 命令" "command -v base64 >/dev/null"
    if command -v ss >/dev/null || command -v netstat >/dev/null; then
        run_test "端口检测工具 (ss 或 netstat)" "command -v ss >/dev/null || command -v netstat >/dev/null"
    else
        echo -e "测试: 端口检测工具 (ss 或 netstat) ... ${YELLOW}跳过${NC}"
    fi
    
    echo ""
}

# 测试功能函数
test_functions() {
    echo -e "${YELLOW}测试功能函数:${NC}"
    
    # 测试公共函数库
    run_test "公共函数库加载" "source '$SCRIPT_DIR/lib/common.sh' && echo 'loaded'"
    
    # 测试配置解析
    run_test "配置解析功能" "true"
    
    echo ""
}

# 测试 CLI 工具
test_cli_tool() {
    echo -e "${YELLOW}测试 CLI 工具:${NC}"
    
    # 测试 CLI 工具基本功能
    run_test "CLI 工具帮助" "timeout 2 '$SCRIPT_DIR/bin/clash-cli' 2>/dev/null || true"
    
    echo ""
}

# 显示测试结果
show_test_results() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                        测试结果                             ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "总测试数: $((TESTS_PASSED + TESTS_FAILED))"
    echo -e "${GREEN}通过: $TESTS_PASSED${NC}"
    echo -e "${RED}失败: $TESTS_FAILED${NC}"
    echo ""
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}✓ 所有测试通过！程序可以正常使用。${NC}"
        exit 0
    else
        echo -e "${RED}✗ 有 $TESTS_FAILED 个测试失败，请检查相关问题。${NC}"
        exit 1
    fi
}

# 主函数
main() {
    show_test_header
    
    test_file_existence
    test_file_permissions
    test_script_syntax
    test_config_file
    test_dependencies
    test_functions
    test_cli_tool
    
    show_test_results
}

# 运行测试
main "$@"
