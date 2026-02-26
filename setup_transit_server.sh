#!/bin/bash
# =============================================================
#  TRANSIT SERVER SETUP (город рядом с тобой)
#  Устанавливает Docker + glider, который принимает
#  shadowsocks соединение и форвардит на exit server.
#
#  Использование:
#    chmod +x setup_transit_server.sh
#    ./setup_transit_server.sh
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
echo "   TRANSIT SERVER SETUP — Glider + Docker"
echo "=================================================="
echo ""

# ---------- Параметры ----------
read -r -p "Введите IP exit сервера: " EXIT_IP
[ -z "$EXIT_IP" ] && err "IP exit сервера обязателен!"

read -r -p "Введите порт exit сервера [8388]: " EXIT_PORT
EXIT_PORT=${EXIT_PORT:-8388}

read -r -p "Введите пароль shadowsocks: " SS_PASS
[ -z "$SS_PASS" ] && err "Пароль обязателен!"

read -r -p "Введите метод шифрования [AEAD_AES_256_GCM]: " SS_METHOD
SS_METHOD=${SS_METHOD:-AEAD_AES_256_GCM}

read -r -p "Введите порт на котором слушает этот сервер [8388]: " LISTEN_PORT
LISTEN_PORT=${LISTEN_PORT:-8388}

echo ""
echo "Параметры:"
echo "  Слушаем на порту: $LISTEN_PORT"
echo "  Exit server:      $EXIT_IP:$EXIT_PORT"
echo "  Пароль:           $SS_PASS"
echo "  Метод:            $SS_METHOD"
echo ""
read -r -p "Продолжить? (y/n): " CONFIRM
[ "$CONFIRM" != "y" ] && err "Отменено."

# ---------- Установка Docker ----------
if ! command -v docker &>/dev/null; then
    log "Устанавливаем Docker..."
    apt update -y
    apt install -y docker.io
    systemctl enable --now docker
    log "Docker установлен."
else
    log "Docker уже установлен."
fi

# ---------- Удаляем старый контейнер если есть ----------
if docker ps -a --format '{{.Names}}' | grep -q "^proxy$"; then
    warn "Найден старый контейнер proxy — удаляем..."
    docker stop proxy && docker rm proxy
fi

# ---------- Запускаем glider ----------
log "Запускаем glider контейнер..."
docker run -d \
    --name proxy \
    --restart unless-stopped \
    --network host \
    nadoo/glider \
    -verbose \
    -listen "ss://${SS_METHOD}:${SS_PASS}@:${LISTEN_PORT}" \
    -forward "ss://${SS_METHOD}:${SS_PASS}@${EXIT_IP}:${EXIT_PORT}"

# ---------- Firewall ----------
log "Открываем порт $LISTEN_PORT в iptables..."
iptables -I INPUT -p tcp --dport $LISTEN_PORT -j ACCEPT
iptables -I INPUT -p udp --dport $LISTEN_PORT -j ACCEPT

apt install -y iptables-persistent 2>/dev/null || true
iptables-save > /etc/iptables/rules.v4 2>/dev/null || true

# ---------- Проверка ----------
sleep 3
if docker ps --format '{{.Names}}' | grep -q "^proxy$"; then
    log "Glider контейнер запущен успешно!"
else
    err "Контейнер не запустился. Проверь: docker logs proxy"
fi

# ---------- Итог ----------
TRANSIT_IP=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
echo ""
echo "=================================================="
echo -e "${GREEN}   ТРАНЗИТНЫЙ СЕРВЕР ГОТОВ! Параметры для Shadowsocks клиента:${NC}"
echo "=================================================="
echo ""
echo "  Shadowsocks Windows:"
echo "  Server:     $TRANSIT_IP"
echo "  Port:       $LISTEN_PORT"
echo "  Password:   $SS_PASS"
echo "  Encryption: aes-256-gcm"
echo ""
echo "  Маршрут трафика:"
echo "  ПК → $TRANSIT_IP:$LISTEN_PORT → $EXIT_IP:$EXIT_PORT → Биржа"
echo ""
echo "  Полезные команды:"
echo "  docker logs proxy        # логи glider"
echo "  docker restart proxy     # перезапустить"
echo "  docker stats proxy       # мониторинг"
echo ""
