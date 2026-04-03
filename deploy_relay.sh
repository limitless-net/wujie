#!/bin/bash
set -e

# ============================================================
#  HTTP Relay 中继代理 - 一键部署脚本 v2.0
#  用途：绕过阿里云中转节点的 ICP/SNI 检测
#  原理：App → SOCKS5(IP) → Relay → fetch(目标域名)
#  特性：IPv4/IPv6 双栈监听、旧版自动检测卸载、一键升级
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

clear
echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   HTTP Relay 中继代理 一键部署脚本 v2.0   ║${NC}"
echo -e "${CYAN}║   支持 IPv4/IPv6 双栈 · 自动检测旧版      ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
echo ""

# ---- 检查 root ----
if [ "$(id -u)" != "0" ]; then
    echo -e "${RED}✘ 请使用 root 用户运行本脚本${NC}"
    echo "  sudo bash deploy_relay.sh"
    exit 1
fi

# ============================================================
#  检测旧版安装并卸载
# ============================================================
EXISTING=false
OLD_PORT=""
OLD_KEY=""

if systemctl list-unit-files | grep -q 'http-relay.service'; then
    EXISTING=true
fi

if [ -f /opt/http-relay/relay.py ] || [ -f /etc/systemd/system/http-relay.service ]; then
    EXISTING=true
fi

if [ "$EXISTING" = true ]; then
    echo -e "${YELLOW}⚠ 检测到已有 HTTP Relay 安装！${NC}"
    echo ""

    # 尝试读取旧配置
    if [ -f /etc/systemd/system/http-relay.service ]; then
        OLD_PORT=$(grep -oP 'RELAY_PORT=\K\d+' /etc/systemd/system/http-relay.service 2>/dev/null || echo "")
        OLD_KEY=$(grep -oP 'RELAY_AUTH_KEY=\K\S+' /etc/systemd/system/http-relay.service 2>/dev/null || echo "")
        if [ -n "$OLD_PORT" ]; then
            echo -e "  旧端口: ${CYAN}${OLD_PORT}${NC}"
        fi
        if [ -n "$OLD_KEY" ]; then
            echo -e "  旧密钥: ${CYAN}${OLD_KEY}${NC}"
        fi
    fi

    # 检查运行状态
    if systemctl is-active --quiet http-relay 2>/dev/null; then
        echo -e "  运行状态: ${GREEN}运行中${NC}"
    else
        echo -e "  运行状态: ${RED}已停止${NC}"
    fi

    echo ""
    echo -e "${BOLD}  将先卸载旧版本，再重新安装${NC}"
    read -p "  是否继续? (Y/n): " UNINSTALL_CONFIRM
    UNINSTALL_CONFIRM=${UNINSTALL_CONFIRM:-Y}
    if [[ ! "$UNINSTALL_CONFIRM" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}已取消${NC}"
        exit 0
    fi

    echo ""
    echo -e "${YELLOW}正在卸载旧版本...${NC}"

    # 停止服务
    systemctl stop http-relay 2>/dev/null || true
    systemctl disable http-relay 2>/dev/null || true

    # 删除 systemd 服务文件
    rm -f /etc/systemd/system/http-relay.service
    systemctl daemon-reload 2>/dev/null || true

    # 删除程序文件
    rm -rf /opt/http-relay

    # 清理防火墙（尝试移除旧端口规则）
    if [ -n "$OLD_PORT" ]; then
        if command -v ufw &> /dev/null; then
            ufw delete allow ${OLD_PORT}/tcp > /dev/null 2>&1 || true
        elif command -v firewall-cmd &> /dev/null; then
            firewall-cmd --permanent --remove-port=${OLD_PORT}/tcp > /dev/null 2>&1 || true
            firewall-cmd --reload > /dev/null 2>&1 || true
        fi
    fi

    echo -e "${GREEN}✔ 旧版本已卸载${NC}"
    echo ""
fi

# ============================================================
#  开始新安装
# ============================================================

# ---- 检查/安装 Python3 ----
echo -e "${YELLOW}[1/6] 检查 Python3 环境...${NC}"
if command -v python3 &> /dev/null; then
    PY_VER=$(python3 --version 2>&1)
    echo -e "  ${GREEN}✔ $PY_VER${NC}"
else
    echo -e "  ${YELLOW}⚠ 未检测到 Python3，正在安装...${NC}"
    if command -v apt-get &> /dev/null; then
        apt-get update -qq && apt-get install -y -qq python3 > /dev/null 2>&1
    elif command -v yum &> /dev/null; then
        yum install -y -q python3 > /dev/null 2>&1
    elif command -v dnf &> /dev/null; then
        dnf install -y -q python3 > /dev/null 2>&1
    else
        echo -e "${RED}✘ 无法自动安装 Python3，请手动安装后重试${NC}"
        exit 1
    fi
    echo -e "  ${GREEN}✔ $(python3 --version 2>&1)${NC}"
fi

# ---- 检测本机 IP 地址 ----
echo -e "${YELLOW}[2/6] 检测网络环境...${NC}"

# 获取 IPv4
SERVER_IPV4=$(curl -4 -s --connect-timeout 5 http://ip.sb 2>/dev/null || \
              curl -4 -s --connect-timeout 5 http://ifconfig.me 2>/dev/null || \
              curl -4 -s --connect-timeout 5 http://icanhazip.com 2>/dev/null || \
              echo "")
SERVER_IPV4=$(echo "$SERVER_IPV4" | tr -d '[:space:]')

# 获取 IPv6
SERVER_IPV6=$(curl -6 -s --connect-timeout 5 http://ip.sb 2>/dev/null || \
              curl -6 -s --connect-timeout 5 http://ifconfig.me 2>/dev/null || \
              curl -6 -s --connect-timeout 5 http://icanhazip.com 2>/dev/null || \
              echo "")
SERVER_IPV6=$(echo "$SERVER_IPV6" | tr -d '[:space:]')

HAS_V4=false
HAS_V6=false
LISTEN_ADDR="::"   # 默认双栈监听

if [ -n "$SERVER_IPV4" ]; then
    HAS_V4=true
    echo -e "  ${GREEN}✔ IPv4: ${SERVER_IPV4}${NC}"
else
    echo -e "  ${YELLOW}⚠ 未检测到公网 IPv4${NC}"
fi

if [ -n "$SERVER_IPV6" ]; then
    HAS_V6=true
    echo -e "  ${GREEN}✔ IPv6: ${SERVER_IPV6}${NC}"
else
    echo -e "  ${YELLOW}⚠ 未检测到公网 IPv6${NC}"
fi

if [ "$HAS_V4" = false ] && [ "$HAS_V6" = false ]; then
    echo -e "${RED}✘ 未检测到任何公网 IP，无法部署${NC}"
    exit 1
fi

# 决定监听地址
if [ "$HAS_V4" = true ] && [ "$HAS_V6" = true ]; then
    echo -e "  ${GREEN}✔ 双栈可用，将同时监听 IPv4 和 IPv6${NC}"
    LISTEN_ADDR="::"
elif [ "$HAS_V4" = true ]; then
    LISTEN_ADDR="0.0.0.0"
else
    LISTEN_ADDR="::"
fi

# ---- 交互式配置 ----
echo ""
echo -e "${YELLOW}[3/6] 配置参数${NC}"
echo ""

# 端口（如果有旧配置则作为默认值）
DEFAULT_PORT=${OLD_PORT:-8899}
read -p "  请输入监听端口 [默认 ${DEFAULT_PORT}]: " INPUT_PORT
RELAY_PORT=${INPUT_PORT:-$DEFAULT_PORT}

# 认证密钥（如果有旧配置则作为默认值）
if [ -n "$OLD_KEY" ]; then
    DEFAULT_KEY="$OLD_KEY"
    echo ""
    echo -e "  检测到旧密钥: ${CYAN}${OLD_KEY}${NC}"
    read -p "  请输入认证密钥 [回车沿用旧密钥]: " INPUT_KEY
else
    DEFAULT_KEY=$(head -c 32 /dev/urandom | base64 | tr -d '=/+' | head -c 24)
    echo ""
    echo -e "  自动生成的密钥: ${CYAN}${DEFAULT_KEY}${NC}"
    read -p "  请输入认证密钥 [回车使用上方密钥]: " INPUT_KEY
fi
RELAY_KEY=${INPUT_KEY:-$DEFAULT_KEY}

# 确认
echo ""
echo -e "${BOLD}  ┌─────────────────────────────────────────┐${NC}"
echo -e "${BOLD}  │ 监听地址: ${GREEN}${LISTEN_ADDR}${NC}${BOLD}                         │${NC}"
echo -e "${BOLD}  │ 端口:     ${GREEN}${RELAY_PORT}${NC}${BOLD}                              │${NC}"
echo -e "${BOLD}  │ 密钥:     ${GREEN}${RELAY_KEY}${NC}${BOLD}    │${NC}"
if [ "$HAS_V4" = true ]; then
echo -e "${BOLD}  │ IPv4:     ${GREEN}${SERVER_IPV4}${NC}${BOLD}                   │${NC}"
fi
if [ "$HAS_V6" = true ]; then
echo -e "${BOLD}  │ IPv6:     ${GREEN}${SERVER_IPV6}${NC}${BOLD}  │${NC}"
fi
echo -e "${BOLD}  └─────────────────────────────────────────┘${NC}"
echo ""
read -p "  确认开始部署? (Y/n): " CONFIRM
CONFIRM=${CONFIRM:-Y}
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}已取消${NC}"
    exit 0
fi

# ---- 创建目录 ----
echo ""
echo -e "${YELLOW}[4/6] 创建 Relay 服务...${NC}"
mkdir -p /opt/http-relay

# ---- 写入 Python 中继服务（双栈版） ----
cat > /opt/http-relay/relay.py << 'PYEOF'
#!/usr/bin/env python3
"""
HTTP Relay Server v2.0 - 中继代理服务（双栈版）
接收 POST /r 请求，从 X-T 头解码目标 URL，代为请求并返回结果
支持 IPv4/IPv6 双栈监听
"""

import http.server
import socketserver
import urllib.request
import urllib.error
import base64
import json
import ssl
import os
import sys
import time
import socket


AUTH_KEY = os.environ.get('RELAY_AUTH_KEY', '')
PORT = int(os.environ.get('RELAY_PORT', '8899'))
LISTEN_ADDR = os.environ.get('RELAY_LISTEN_ADDR', '::')
VERSION = '2.0.0'


class RelayHandler(http.server.BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'
    server_version = 'nginx/1.24'   # 伪装 Server 头
    sys_version = ''

    def do_POST(self):
        """处理中继请求"""
        if self.path != '/r':
            self._respond(404, b'Not Found')
            return

        # 认证检查
        if self.headers.get('X-K', '') != AUTH_KEY:
            self._respond(403, b'Forbidden')
            return

        # 解码目标 URL (base64)
        target_b64 = self.headers.get('X-T', '')
        if not target_b64:
            self._respond(400, b'Missing X-T header')
            return

        try:
            target_url = base64.b64decode(target_b64).decode('utf-8')
        except Exception:
            self._respond(400, b'Invalid X-T encoding')
            return

        # 请求方法
        method = self.headers.get('X-M', 'GET').upper()

        # 自定义请求头 (base64 JSON)
        custom_headers = {}
        h_b64 = self.headers.get('X-H', '')
        if h_b64:
            try:
                custom_headers = json.loads(base64.b64decode(h_b64).decode('utf-8'))
            except Exception:
                pass

        # 读取请求体
        content_length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(content_length) if content_length > 0 else None

        # 发起实际请求
        start = time.time()
        try:
            ctx = ssl.create_default_context()
            ctx.check_hostname = False
            ctx.verify_mode = ssl.CERT_NONE

            req = urllib.request.Request(target_url, method=method, data=body)
            for k, v in custom_headers.items():
                req.add_header(k, v)
            if 'User-Agent' not in custom_headers:
                req.add_header('User-Agent',
                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36')

            with urllib.request.urlopen(req, timeout=20, context=ctx) as resp:
                resp_body = resp.read()
                resp_status = resp.status
                resp_headers = dict(resp.headers)

            elapsed = int((time.time() - start) * 1000)
            self._log(f'OK {resp_status} {method} {target_url} ({elapsed}ms)')

            self.send_response(200)
            self.send_header('X-S', str(resp_status))
            try:
                rh_json = json.dumps(resp_headers, ensure_ascii=False)
                self.send_header('X-RH', base64.b64encode(rh_json.encode()).decode())
            except Exception:
                pass
            self.send_header('Content-Length', str(len(resp_body)))
            self.send_header('Connection', 'close')
            self.end_headers()
            self.wfile.write(resp_body)

        except urllib.error.HTTPError as e:
            try:
                err_body = e.read()
            except Exception:
                err_body = b''
            elapsed = int((time.time() - start) * 1000)
            self._log(f'HTTP {e.code} {method} {target_url} ({elapsed}ms)')

            self.send_response(200)
            self.send_header('X-S', str(e.code))
            self.send_header('Content-Length', str(len(err_body)))
            self.send_header('Connection', 'close')
            self.end_headers()
            self.wfile.write(err_body)

        except Exception as e:
            elapsed = int((time.time() - start) * 1000)
            err_msg = f'Relay error: {e}'.encode()
            self._log(f'ERR {method} {target_url} - {e} ({elapsed}ms)')

            self.send_response(502)
            self.send_header('Content-Length', str(len(err_msg)))
            self.send_header('Connection', 'close')
            self.end_headers()
            self.wfile.write(err_msg)

    def do_GET(self):
        """健康检查"""
        if self.path == '/health':
            body = json.dumps({
                'status': 'ok',
                'version': VERSION,
                'listen': LISTEN_ADDR,
                'port': PORT,
            }).encode()
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(body)))
            self.send_header('Connection', 'close')
            self.end_headers()
            self.wfile.write(body)
            return
        self._respond(404, b'Not Found')

    def _respond(self, code, body):
        self.send_response(code)
        self.send_header('Content-Length', str(len(body)))
        self.send_header('Connection', 'close')
        self.end_headers()
        self.wfile.write(body)

    def _log(self, msg):
        ts = time.strftime('%H:%M:%S')
        sys.stdout.write(f'[{ts}] {msg}\n')
        sys.stdout.flush()

    def log_message(self, format, *args):
        """抑制默认日志，使用自定义格式"""
        pass


class DualStackServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    """支持 IPv4/IPv6 双栈的线程化 HTTP 服务器"""
    daemon_threads = True
    allow_reuse_address = True
    address_family = socket.AF_INET6  # IPv6 socket 可以同时接受 IPv4

    def server_bind(self):
        # 允许 IPv6 socket 同时接受 IPv4 连接（dual-stack）
        if self.address_family == socket.AF_INET6:
            try:
                self.socket.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 0)
            except (AttributeError, OSError):
                pass  # 某些系统不支持，降级为仅 IPv6
        super().server_bind()


class IPv4OnlyServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    """仅 IPv4 的线程化 HTTP 服务器"""
    daemon_threads = True
    allow_reuse_address = True
    address_family = socket.AF_INET


def main():
    if not AUTH_KEY:
        print('[!] 警告: 未设置 RELAY_AUTH_KEY 环境变量')
        sys.exit(1)

    # 根据监听地址选择服务器类型
    if LISTEN_ADDR == '0.0.0.0':
        server_class = IPv4OnlyServer
        bind_addr = '0.0.0.0'
    else:
        # '::' 或 IPv6 地址 → 双栈
        server_class = DualStackServer
        bind_addr = '::'

    server = server_class((bind_addr, PORT), RelayHandler)

    stack_info = '双栈(IPv4+IPv6)' if bind_addr == '::' else '仅IPv4'
    print(f'[Relay] HTTP Relay v{VERSION} 启动成功')
    print(f'[Relay] 监听: {bind_addr}:{PORT} ({stack_info})')
    print(f'[Relay] 健康检查: http://localhost:{PORT}/health')
    sys.stdout.flush()

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print('\n[Relay] 正在关闭...')
        server.shutdown()


if __name__ == '__main__':
    main()
PYEOF

chmod +x /opt/http-relay/relay.py
echo -e "  ${GREEN}✔ 中继服务已创建（双栈版 v2.0）${NC}"

# ---- 创建 systemd 服务 ----
echo -e "${YELLOW}[5/6] 配置 systemd 服务...${NC}"

cat > /etc/systemd/system/http-relay.service << EOF
[Unit]
Description=HTTP Relay Server (Dual-Stack)
After=network.target

[Service]
Type=simple
Environment=RELAY_AUTH_KEY=${RELAY_KEY}
Environment=RELAY_PORT=${RELAY_PORT}
Environment=RELAY_LISTEN_ADDR=${LISTEN_ADDR}
ExecStart=/usr/bin/python3 /opt/http-relay/relay.py
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable http-relay > /dev/null 2>&1
echo -e "  ${GREEN}✔ systemd 服务已配置${NC}"

# ---- 防火墙 ----
echo -e "${YELLOW}[6/6] 配置防火墙...${NC}"
FIREWALL_OK=false

if command -v ufw &> /dev/null; then
    ufw allow ${RELAY_PORT}/tcp > /dev/null 2>&1 && FIREWALL_OK=true
elif command -v firewall-cmd &> /dev/null; then
    firewall-cmd --permanent --add-port=${RELAY_PORT}/tcp > /dev/null 2>&1
    firewall-cmd --reload > /dev/null 2>&1 && FIREWALL_OK=true
fi

if [ "$FIREWALL_OK" = true ]; then
    echo -e "  ${GREEN}✔ 防火墙已放行端口 ${RELAY_PORT}${NC}"
else
    echo -e "  ${YELLOW}⚠ 未检测到防火墙工具，如有安全组请手动放行端口 ${RELAY_PORT}${NC}"
fi

# ---- 启动服务 ----
echo ""
echo -e "${BOLD}启动服务...${NC}"
systemctl restart http-relay
sleep 2

# 验证
if systemctl is-active --quiet http-relay; then
    # 健康检查
    HEALTH=$(curl -s http://localhost:${RELAY_PORT}/health 2>/dev/null || echo "")

    echo -e "  ${GREEN}✔ 服务已启动${NC}"
    if echo "$HEALTH" | grep -q "ok"; then
        echo -e "  ${GREEN}✔ 健康检查通过${NC}"
    fi

    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║              ✅ 部署成功！(v2.0 双栈)            ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${BOLD}监听地址:${NC}  ${CYAN}${LISTEN_ADDR}:${RELAY_PORT}${NC}"
    echo -e "  ${BOLD}认证密钥:${NC}  ${CYAN}${RELAY_KEY}${NC}"
    if [ "$HAS_V4" = true ]; then
    echo -e "  ${BOLD}IPv4:${NC}      ${CYAN}${SERVER_IPV4}${NC}"
    fi
    if [ "$HAS_V6" = true ]; then
    echo -e "  ${BOLD}IPv6:${NC}      ${CYAN}${SERVER_IPV6}${NC}"
    fi

    # ---- 生成客户端 Relay URL ----
    echo ""
    echo -e "  ${YELLOW}══ 客户端 Relay URL（直接复制到远程 config.json）══${NC}"
    echo ""

    if [ "$HAS_V4" = true ] && [ "$HAS_V6" = true ]; then
        # 双栈
        RELAY_URL="relay://${RELAY_KEY}@${SERVER_IPV4}:${RELAY_PORT}|[${SERVER_IPV6}]:${RELAY_PORT}"
        echo -e "  ${BOLD}双栈URL:${NC}"
        echo -e "  ${CYAN}${RELAY_URL}${NC}"
        echo ""
        echo -e "  ${BOLD}仅IPv4:${NC}"
        echo -e "  ${CYAN}relay://${RELAY_KEY}@${SERVER_IPV4}:${RELAY_PORT}${NC}"
        echo ""
        echo -e "  ${BOLD}仅IPv6:${NC}"
        echo -e "  ${CYAN}relay://${RELAY_KEY}@[${SERVER_IPV6}]:${RELAY_PORT}${NC}"
    elif [ "$HAS_V4" = true ]; then
        RELAY_URL="relay://${RELAY_KEY}@${SERVER_IPV4}:${RELAY_PORT}"
        echo -e "  ${BOLD}Relay URL:${NC}"
        echo -e "  ${CYAN}${RELAY_URL}${NC}"
    else
        RELAY_URL="relay://${RELAY_KEY}@[${SERVER_IPV6}]:${RELAY_PORT}"
        echo -e "  ${BOLD}Relay URL:${NC}"
        echo -e "  ${CYAN}${RELAY_URL}${NC}"
    fi

    echo ""
    echo -e "  ${YELLOW}══ config.json proxy 条目示例 ══${NC}"
    echo ""
    echo -e "  ${CYAN}{${NC}"
    echo -e "  ${CYAN}    \"url\": \"${RELAY_URL}\",${NC}"
    echo -e "  ${CYAN}    \"description\": \"HTTP中继（双栈）\",${NC}"
    echo -e "  ${CYAN}    \"protocol\": \"relay\"${NC}"
    echo -e "  ${CYAN}}${NC}"
    echo ""
    echo -e "  ${YELLOW}══ 管理命令 ══${NC}"
    echo ""
    echo -e "  查看状态:  ${CYAN}systemctl status http-relay${NC}"
    echo -e "  查看日志:  ${CYAN}journalctl -u http-relay -f${NC}"
    echo -e "  重启服务:  ${CYAN}systemctl restart http-relay${NC}"
    echo -e "  停止服务:  ${CYAN}systemctl stop http-relay${NC}"
    echo -e "  完整卸载:  ${CYAN}systemctl stop http-relay && systemctl disable http-relay && rm -rf /opt/http-relay /etc/systemd/system/http-relay.service && systemctl daemon-reload${NC}"
    echo -e "  重新部署:  ${CYAN}bash deploy_relay.sh${NC}  （会自动卸载旧版）"
    echo ""
    echo -e "  ${YELLOW}══ 本地测试 ══${NC}"
    echo ""
    echo -e "  ${CYAN}curl http://localhost:${RELAY_PORT}/health${NC}"
    T_B64=$(echo -n "https://www.baidu.com" | base64 | tr -d '\n')
    echo -e "  ${CYAN}curl -X POST http://localhost:${RELAY_PORT}/r -H 'X-K: ${RELAY_KEY}' -H 'X-T: ${T_B64}'${NC}"
    echo ""
else
    echo -e "${RED}✘ 服务启动失败！${NC}"
    echo ""
    echo -e "  查看日志: journalctl -u http-relay -n 30 --no-pager"
    echo ""
    journalctl -u http-relay -n 10 --no-pager
    exit 1
fi
