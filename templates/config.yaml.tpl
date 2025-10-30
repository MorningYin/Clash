# Clash 配置文件
# 由 Clash 安装程序自动生成
# 生成时间: {{TIMESTAMP}}

port: {{HTTP_PORT}}
socks-port: {{SOCKS_PORT}}
allow-lan: false
mode: rule
log-level: info
external-controller: 127.0.0.1:{{API_PORT}}
secret: ""

dns:
  enable: true
  listen: 0.0.0.0:{{DNS_PORT}}
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  nameserver:
    - 114.114.114.114
    - 8.8.8.8
    - 223.5.5.5
  fallback:
    - 8.8.8.8
    - 1.1.1.1
  fallback-filter:
    geoip: true
    geoip-code: CN
    ipcidr:
      - 240.0.0.0/4

proxies: []

proxy-groups:
  - name: 自动选择
    type: url-test
    proxies: []
    url: http://www.gstatic.com/generate_204
    interval: 300
    timeout: 3000
  - name: 节点选择
    type: select
    proxies:
      - 自动选择
  - name: 全球直连
    type: select
    proxies:
      - DIRECT

rules:
  - DOMAIN-SUFFIX,local,DIRECT
  - IP-CIDR,127.0.0.0/8,DIRECT
  - IP-CIDR,172.16.0.0/12,DIRECT
  - IP-CIDR,192.168.0.0/16,DIRECT
  - IP-CIDR,10.0.0.0/8,DIRECT
  - IP-CIDR,17.0.0.0/8,DIRECT
  - IP-CIDR,100.64.0.0/10,DIRECT
  - DOMAIN-SUFFIX,cn,DIRECT
  - DOMAIN-KEYWORD,-cn,DIRECT
  - GEOIP,CN,全球直连
  - MATCH,节点选择
