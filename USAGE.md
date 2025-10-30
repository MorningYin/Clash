# Clash 安装程序使用指南

## 📚 目录

- [快速开始](#快速开始)
- [详细安装步骤](#详细安装步骤)
- [配置说明](#配置说明)
- [管理工具使用](#管理工具使用)
- [高级功能](#高级功能)
- [故障排除](#故障排除)
- [常见问题](#常见问题)

## 🚀 快速开始

### 1. 准备环境

确保系统满足以下要求：

```bash
# 检查系统信息
uname -a

# 检查依赖
which curl wget python3 base64

# 检查权限
whoami
```

### 2. 下载程序

```bash
# 方法一：克隆仓库
git clone <repository-url> clash-installer
cd clash-installer

# 方法二：下载压缩包
wget <download-url> -O clash-installer.tar.gz
tar -xzf clash-installer.tar.gz
cd clash-installer
```

### 3. 配置订阅

编辑 `config.yaml` 文件：

```yaml
subscription:
  url: "https://your-subscription-url"
  auto_update: true
  update_interval: 24
```

### 4. 运行安装

```bash
chmod +x install.sh
./install.sh
```

## 📋 详细安装步骤

### 步骤 1: 系统检查

程序会自动检查：
- 操作系统兼容性
- 系统架构支持
- 必要依赖是否安装
- 系统资源是否充足

### 步骤 2: 选择安装方式

程序提供三种安装方式：

#### 完整安装 (推荐)
```bash
选择: 1
```
包含所有功能组件，适合大多数用户。

#### 仅安装核心程序
```bash
选择: 2
```
只安装 Clash 可执行文件，适合手动配置用户。

#### 自定义安装
```bash
选择: 3
```
手动选择安装组件，适合高级用户。

### 步骤 3: 安装过程

程序会依次执行：
1. 创建目录结构
2. 安装 Clash 核心程序
3. 安装 Country.mmdb
4. 生成配置文件
5. 下载并转换订阅
6. 创建更新脚本
7. 设置定时任务
8. 安装管理工具
9. 配置环境变量

### 步骤 4: 安装完成

安装完成后会显示：
- 服务状态信息
- 代理端口信息
- 使用说明
- 配置文件位置

## ⚙️ 配置说明

### 基本配置

编辑 `config.yaml` 文件进行配置：

```yaml
# 安装配置
install:
  http_port: 7890      # HTTP 代理端口
  socks_port: 7891     # SOCKS5 代理端口
  api_port: 9090       # 管理面板端口
  dns_port: 53         # DNS 端口

# 订阅配置
subscription:
  url: "https://your-subscription-url"
  auto_update: true
  update_interval: 24

# 本地包配置
packages:
  clash:
    local_path: "packages/mihomo-linux-amd64-compatible-v1.19.15.gz"
    download_url: "https://github.com/MetaCubeX/mihomo/releases/download/v1.19.15/mihomo-linux-amd64-compatible-v1.19.15.gz"
```

### 高级配置

```yaml
# 系统配置
system:
  supported_archs: ["x86_64", "amd64", "aarch64", "arm64"]
  min_memory: 128
  min_disk_space: 100

# 日志配置
logging:
  level: "info"
  max_log_size: 10
  max_log_files: 5

# 安全配置
security:
  verify_checksums: false
  force_https: true
  download_timeout: 300
```

## 🎛️ 管理工具使用

### clash-cli 交互式管理

```bash
# 启动管理界面
clash-cli

# 或使用完整路径
/usr/local/bin/clash-cli
```

管理界面功能：
1. 启动服务
2. 停止服务
3. 重启服务
4. 查看状态
5. 更新订阅
6. 查看日志
7. 测试连接
8. 代理设置
9. 节点管理

### 命令行管理

```bash
# 服务管理
clash-cli start     # 启动服务
clash-cli stop      # 停止服务
clash-cli restart   # 重启服务
clash-cli status    # 查看状态

# 订阅管理
clash-cli update    # 更新订阅

# 日志查看
clash-cli logs      # 查看日志
```

### 代理环境变量

```bash
# 加载代理环境变量
source /etc/clash/proxy-env.sh  # root 用户
source ~/.config/clash/proxy-env.sh  # 普通用户

# 使用便捷命令
clash_on    # 启用代理
clash_off   # 禁用代理
clash_test  # 测试连接
```

## 🔧 高级功能

### 自动更新

程序支持自动更新订阅：

```bash
# 查看定时任务
crontab -l | grep clash

# 手动更新
/etc/clash/update-subscription.sh

# 禁用自动更新
crontab -l | grep -v "update-subscription.sh" | crontab -
```

### 服务管理

#### systemd 服务 (root 用户)

```bash
# 服务控制
systemctl start clash
systemctl stop clash
systemctl restart clash
systemctl status clash

# 开机自启
systemctl enable clash
systemctl disable clash

# 查看日志
journalctl -u clash -f
```

#### 普通用户服务

```bash
# 使用管理工具
clash-cli start
clash-cli stop
clash-cli restart
clash-cli status

# 查看日志
tail -f ~/.config/clash/clash.log
```

### 配置文件管理

```bash
# 编辑配置文件
nano /etc/clash/config.yaml  # root 用户
nano ~/.config/clash/config.yaml  # 普通用户

# 验证配置
/usr/local/bin/clash -t -f /etc/clash/config.yaml

# 重新加载配置
clash-cli restart
```

### 日志管理

```bash
# 查看实时日志
tail -f /etc/clash/clash.log

# 查看安装日志
tail -f /var/log/clash-installer.log

# 清理日志
truncate -s 0 /etc/clash/clash.log
```

## 🛠️ 故障排除

### 安装问题

#### 1. 权限不足
```bash
# 检查文件权限
ls -la install.sh

# 添加执行权限
chmod +x install.sh

# 使用 sudo (如果需要)
sudo ./install.sh
```

#### 2. 依赖缺失
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install curl wget python3

# CentOS/RHEL
sudo yum install curl wget python3

# Arch Linux
sudo pacman -S curl wget python
```

#### 3. 网络问题
```bash
# 测试网络连接
ping google.com
curl -I https://github.com

# 使用代理下载
export http_proxy=http://proxy:port
export https_proxy=http://proxy:port
./install.sh
```

### 运行问题

#### 1. 服务启动失败
```bash
# 查看错误日志
tail -f /etc/clash/clash.log

# 验证配置文件
/usr/local/bin/clash -t -f /etc/clash/config.yaml

# 检查端口占用
ss -tlnp | grep -E ":(7890|7891|9090)"
```

#### 2. 代理连接失败
```bash
# 测试代理连接
curl -x http://127.0.0.1:7890 http://www.google.com

# 检查防火墙
sudo ufw status
sudo iptables -L

# 检查服务状态
clash-cli status
```

#### 3. 订阅更新失败
```bash
# 测试订阅链接
curl -s "https://your-subscription-url"

# 手动更新
/etc/clash/update-subscription.sh

# 查看更新日志
tail -f /etc/clash/update.log
```

### 配置问题

#### 1. 配置文件错误
```bash
# 验证 YAML 语法
python3 -c "import yaml; yaml.safe_load(open('/etc/clash/config.yaml'))"

# 重置配置文件
cp /etc/clash/config.yaml.backup /etc/clash/config.yaml
```

#### 2. 端口冲突
```bash
# 查看端口占用
ss -tlnp | grep -E ":(7890|7891|9090)"

# 修改端口配置
nano /etc/clash/config.yaml
# 修改 port, socks-port, external-controller 等配置
```

## ❓ 常见问题

### Q: 安装后无法启动服务？
A: 检查以下几点：
1. 配置文件是否正确
2. 端口是否被占用
3. 权限是否正确
4. 查看错误日志

### Q: 代理连接失败？
A: 尝试以下步骤：
1. 检查服务是否运行
2. 测试代理端口
3. 检查防火墙设置
4. 验证订阅配置

### Q: 如何更新 Clash 版本？
A: 重新运行安装程序，或手动替换可执行文件。

### Q: 如何备份配置？
A: 配置文件位于 `/etc/clash/` 或 `~/.config/clash/`，直接复制即可。

### Q: 如何完全卸载？
A: 运行 `./uninstall.sh` 选择完全卸载。

### Q: 支持哪些订阅格式？
A: 支持 Base64 编码的节点链接，包括 SS、Trojan、VMess 等协议。

### Q: 如何添加自定义规则？
A: 编辑配置文件中的 `rules` 部分，或使用规则集。

### Q: 如何设置开机自启？
A: root 用户会自动设置 systemd 服务，普通用户需要手动设置。

---

如有其他问题，请查看日志文件或提交 Issue。
