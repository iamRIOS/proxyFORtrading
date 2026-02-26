#!/bin/bash
# =============================================================
#  EXIT SERVER SETUP (город рядом с биржей)
#  Устанавливает shadowsocks-libev и настраивает его как
#  конечный сервер-выход.
#
#  Использование:
#    chmod +x setup_exit_server.sh
#    ./setup_exit_server.sh
# =============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; exit 1; }

echo ""
echo "=================================================="
echo "   EXIT SERVER SETUP — Shadowsocks-libev"
echo "=================================================="
echo ""

# ---------- Параметры ----------
read -r -p "Введите порт shadowsocks [8388]: " SS_PORT
SS_PORT=${SS_PORT:-8388}

read -r -p "Введите пароль shadowsocks [генерировать автоматически]: " SS_PASS
if [ -z "$SS_PASS" ]; then
    SS_PASS=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16)
    warn "Сгенерирован пароль: ${YELLOW}$SS_PASS${NC}"
fi

read -r -p "Введите метод шифрования [aes-256-gcm]: " SS_METHOD
SS_METHOD=${SS_METHOD:-aes-256-gcm}

echo ""
echo "Параметры:"
echo "  Порт:    $SS_PORT"
echo "  Пароль:  $SS_PASS"
echo "  Метод:   $SS_METHOD"
echo ""
read -r -p "Продолжить? (y/n): " CONFIRM
[ "$CONFIRM" != "y" ] && err "Отменено."

# ---------- Установка ----------
log "Обновляем пакеты..."
apt update -y && apt upgrade -y

log "Устанавливаем shadowsocks-libev..."
apt install -y shadowsocks-libev

# ---------- Конфиг ----------
log "Создаём конфиг..."
mkdir -p /etc/shadowsocks-libev
cat > /etc/shadowsocks-libev/config.json << EOF
{
  "server": ["::0", "0.0.0.0"],
  "mode": "tcp_and_udp",
  "server_port": $SS_PORT,
  "local_port": 1080,
  "password": "$SS_PASS",
  "timeout": 60,
  "fast_open": true,
  "reuse_port": true,
  "no_delay": true,
  "method": "$SS_METHOD"
}
EOF

# ---------- Systemd ----------
log "Настраиваем автозапуск..."
cat > /etc/systemd/system/shadowsocks-libev.service << 'EOF'
[Unit]
Description=Shadowsocks-Libev Service
After=network-online.target

[Service]
ExecStart=/usr/bin/ss-server -c /etc/shadowsocks-libev/config.json
Restart=on-failure
KillMode=mixed

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable shadowsocks-libev

# ---------- Перезапуск чтобы применить конфиг ----------
log "Запускаем shadowsocks с новым конфигом..."
systemctl restart shadowsocks-libev

# ---------- Firewall ----------
log "Открываем порт $SS_PORT в iptables..."
iptables -I INPUT -p tcp --dport $SS_PORT -j ACCEPT
iptables -I INPUT -p udp --dport $SS_PORT -j ACCEPT

apt install -y iptables-persistent 2>/dev/null || true
iptables-save > /etc/iptables/rules.v4 2>/dev/null || true

# ---------- Проверка ----------
sleep 2
if systemctl is-active --quiet shadowsocks-libev; then
    log "Shadowsocks запущен успешно!"
else
    err "Shadowsocks не запустился. Проверь: systemctl status shadowsocks-libev"
fi

# ---------- Итог ----------
SERVER_IP=$(curl -4s ifconfig.me 2>/dev/null || ip addr show | grep 'inet ' | grep -v '127.0.0.1' | grep -v '172\.' | awk '{print $2}' | cut -d/ -f1 | head -1)
echo ""
echo "=================================================="
echo -e "${GREEN}   EXIT SERVER ГОТОВ! Используй эти данные при настройке транзитного сервера:${NC}"
echo "=================================================="
echo ""
echo "  IP exit сервера: $SERVER_IP"
echo "  Порт:            $SS_PORT"
echo "  Пароль:          $SS_PASS"
echo "  Метод:           $SS_METHOD"
echo ""
echo "  Эти данные вводишь при запуске setup_transit_server.sh"
echo ""
