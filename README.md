# Clash 一键安装程序

一个功能完善的 Clash Premium (Mihomo) 一键安装和管理程序，支持自动订阅更新、节点转换和便捷管理。

## ✨ 特性

- 🚀 **一键安装**: 自动检测系统环境，一键完成 Clash 安装和配置
- 📦 **本地包支持**: 优先使用本地安装包，避免网络下载失败
- 🔄 **自动更新**: 支持订阅自动更新和节点转换
- 👥 **多用户支持**: 支持 root 用户和普通用户安装
- 🎛️ **管理工具**: 提供交互式 CLI 管理界面
- 🛠️ **完整卸载**: 支持完全卸载和配置保留
- 📝 **详细日志**: 完整的安装和运行日志记录
- 🎨 **友好界面**: 彩色输出和进度提示

## 📋 系统要求

- **操作系统**: Linux (支持主流发行版)
- **架构**: x86_64, aarch64, arm64
- **内存**: 最少 128MB
- **磁盘空间**: 最少 100MB
- **必备依赖**: `curl`, `wget`, `python3` (需包含 PyYAML 模块)、`base64`
- **可选依赖**: `crontab`、`systemd`

> ⚠️ 在 Docker、容器或精简发行版中，`crontab` 与 `systemd` 可能不存在。程序会自动跳过相关功能（订阅定时更新、systemd 服务管理），核心功能不受影响。

## 🚀 快速开始

### 1. 下载程序

```bash
# 克隆或下载程序
git clone <repository-url> clash-installer
cd clash-installer

# 或者直接下载
wget <download-url> -O clash-installer.tar.gz
tar -xzf clash-installer.tar.gz
cd clash-installer
```

### 2. 配置安装包 (可选)

将本地安装包放入 `packages/` 目录：

```bash
# 创建 packages 目录
mkdir -p packages

# 下载 Clash 安装包
wget https://github.com/MetaCubeX/mihomo/releases/download/v1.19.15/mihomo-linux-amd64-compatible-v1.19.15.gz -O packages/mihomo-linux-amd64-compatible-v1.19.15.gz

# 下载 Country.mmdb
wget https://github.com/Dreamacro/maxmind-geoip/releases/latest/download/Country.mmdb -O packages/Country.mmdb
```

### 3. 配置订阅链接

编辑 `config.yaml` 文件，设置您的订阅链接：

```yaml
subscription:
  url: "https://your-subscription-url"
  auto_update: true
  update_interval: 24
```

### 4. 初始化环境（仅首次安装需要）

```bash
# 安装 Python 依赖
python3 -m pip install --user pyyaml
```

### 5. 运行安装

```bash
# 给安装脚本执行权限
chmod +x install.sh

# 运行安装程序
./install.sh
```

## 📖 详细使用说明

### 安装选项

程序提供三种安装方式：

1. **完整安装** (推荐)
   - 安装 Clash 核心程序
   - 下载订阅并转换配置
   - 设置自动更新
   - 安装管理工具
   - 配置环境变量

2. **仅安装核心程序**
   - 只安装 Clash 可执行文件
   - 不下载订阅
   - 适合手动配置

3. **自定义安装**
   - 手动选择安装组件
   - 灵活配置

### 管理工具

安装完成后，使用 `clash-cli` 管理 Clash：

```bash
# 启动交互式管理界面
clash-cli

# 或者直接使用命令
clash-cli start    # 启动服务
clash-cli stop     # 停止服务
clash-cli status   # 查看状态
clash-cli update   # 更新订阅
```

### 代理设置

启用代理环境变量：

```bash
# 加载代理环境变量
source /etc/clash/proxy-env.sh  # root 用户
# 或
source ~/.config/clash/proxy-env.sh  # 普通用户

# 使用便捷命令
clash_on    # 启用代理
clash_off   # 禁用代理
clash_test  # 测试连接
```

### 配置文件

- **主配置**: `/etc/clash/config.yaml` (root) 或 `~/.config/clash/config.yaml` (普通用户)
- **日志文件**: `/etc/clash/clash.log` 或 `~/.config/clash/clash.log`
- **更新脚本**: `/etc/clash/update-subscription.sh` 或 `~/.config/clash/update-subscription.sh`

## ⚙️ 配置说明

### config.yaml 配置项

```yaml
# 安装配置
install:
  clash_bin_dir: "/usr/local/bin"        # Clash 可执行文件目录
  clash_config_dir: "/etc/clash"          # 配置文件目录
  http_port: 7890                         # HTTP 代理端口
  socks_port: 7891                        # SOCKS5 代理端口
  api_port: 9090                          # 管理面板端口

# 本地安装包配置
packages:
  clash:
    local_path: "packages/mihomo-linux-amd64-compatible-v1.19.15.gz"
    download_url: "https://github.com/MetaCubeX/mihomo/releases/download/v1.19.15/mihomo-linux-amd64-compatible-v1.19.15.gz"
  country_mmdb:
    local_path: "packages/Country.mmdb"
    download_url: "https://github.com/Dreamacro/maxmind-geoip/releases/latest/download/Country.mmdb"

# 订阅配置
subscription:
  url: "https://your-subscription-url"
  auto_update: true
  update_interval: 24

# 系统配置
system:
  supported_archs: ["x86_64", "amd64", "aarch64", "arm64"]
  min_memory: 128
  min_disk_space: 100
```

## 🛠️ 高级功能

### 自动更新

程序支持自动更新订阅：

```bash
# 手动更新订阅
/etc/clash/update-subscription.sh

# 查看定时任务（需要 crontab）
crontab -l | grep clash
```

> 在没有 `crontab` 的环境中，程序会提示并跳过定时任务，但仍可通过上述脚本进行手动更新。

### 服务管理

#### systemd 服务 (root 用户)

```bash
# 启动服务
systemctl start clash

# 停止服务
systemctl stop clash

# 重启服务
systemctl restart clash

# 查看状态
systemctl status clash

# 开机自启
systemctl enable clash
```

> 如果宿主机未使用 systemd（例如 Docker 容器），安装脚本会自动跳过 service 创建，可使用 CLI 管理工具（见下）来控制 Clash。

#### 普通用户服务

```bash
# 使用管理工具
clash-cli start
clash-cli stop
clash-cli restart
clash-cli status
```

### 日志查看

```bash
# 查看日志
tail -f /etc/clash/clash.log

# 或使用管理工具
clash-cli logs
```

## 🗑️ 卸载程序

### 交互式卸载

```bash
./uninstall.sh
```

### 快速卸载

```bash
./uninstall.sh --quick
```

### 卸载选项

1. **完全卸载**: 删除所有文件和配置
2. **仅删除配置**: 保留可执行文件，删除配置
3. **保留配置**: 仅停止服务，保留所有文件

## 🔧 故障排除

### 常见问题

1. **安装失败**
   ```bash
   # 检查依赖
   which curl wget python3 base64
   
   # 检查权限
   ls -la install.sh
   ```

2. **服务启动失败**
   ```bash
   # 查看日志
   tail -f /etc/clash/clash.log
   
   # 验证配置
   /usr/local/bin/clash -t -f /etc/clash/config.yaml
   ```

3. **代理连接失败**
   ```bash
   # 测试连接
   curl -x http://127.0.0.1:7890 http://www.google.com
   
   # 检查端口
   ss -tlnp | grep -E ":(7890|7891|9090)"
   ```

4. **订阅更新失败**
   ```bash
   # 手动测试订阅链接
   curl -s "https://your-subscription-url"
   
   # 检查网络连接
   ping google.com
   ```

### 日志位置

- **安装日志**: `/var/log/clash-installer.log` (root) 或 `~/.local/log/clash-installer.log` (普通用户)
- **运行日志**: `/etc/clash/clash.log` 或 `~/.config/clash/clash.log`
- **更新日志**: `/etc/clash/update.log` 或 `~/.config/clash/update.log`

## 📁 项目结构

```
clash-installer/
├── install.sh              # 主安装脚本
├── uninstall.sh            # 卸载脚本
├── config.yaml             # 配置文件
├── lib/                    # 函数库
│   ├── common.sh          # 公共函数
│   ├── installer.sh       # 安装逻辑
│   ├── manager.sh         # 服务管理
│   └── uninstaller.sh     # 卸载逻辑
├── templates/              # 模板文件
│   ├── clash.service.tpl  # systemd 服务模板
│   └── config.yaml.tpl    # Clash 配置模板
├── bin/                    # 可执行文件
│   └── clash-cli          # CLI 管理工具
├── packages/               # 本地安装包目录
│   ├── mihomo-linux-amd64-v*.gz
│   └── Country.mmdb
└── README.md              # 说明文档
```

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 许可证

MIT License

## 🙏 致谢

- [Mihomo](https://github.com/MetaCubeX/mihomo) - Clash Premium 核心
- [Dreamacro](https://github.com/Dreamacro) - 原始 Clash 项目

---

**注意**: 请确保您有合法的代理服务订阅，并遵守当地法律法规。
