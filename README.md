# Trading Proxy Setup

Автоматическая настройка двухзвенного shadowsocks прокси для трейдинга с минимальным пингом до биржи.

## Схема работы

```
Твой ПК (Shadowsocks клиент)
        ↓
Транзитный сервер — Хабаровск/EdgeCenter  (glider в Docker)
        ↓
Exit сервер — Япония/ISHosting  (shadowsocks-libev)
        ↓
Binance / Bybit / биржа
```

## Использование

### Шаг 1 — Exit сервер (Япония)

Подключись к серверу по SSH и выполни:

```bash
wget https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/setup_exit_server.sh
chmod +x setup_exit_server.sh
./setup_exit_server.sh
```

Скрипт спросит порт, пароль и метод шифрования — и выведет итоговые параметры.

### Шаг 2 — Транзитный сервер (Хабаровск)

Подключись к серверу по SSH и выполни:

```bash
wget https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/setup_transit_server.sh
chmod +x setup_transit_server.sh
./setup_transit_server.sh
```

Скрипт спросит IP exit сервера, пароль и метод — и настроит glider в Docker.

### Шаг 3 — Shadowsocks клиент (Windows)

Скачай: https://github.com/shadowsocks/shadowsocks-windows/releases

Параметры:
- **Server** — IP транзитного сервера (Хабаровск)
- **Port** — порт (по умолчанию 8388)
- **Password** — твой пароль
- **Encryption** — aes-256-gcm

## Требования

- Ubuntu 20.04 / 22.04
- Root доступ

## Полезные команды

```bash
# Статус shadowsocks на exit сервере
systemctl status shadowsocks-libev

# Логи glider на транзитном сервере
docker logs proxy

# Перезапустить glider
docker restart proxy

# Поменять exit сервер на транзитном (новый IP)
docker stop proxy && docker rm proxy
docker run -d --name proxy --restart unless-stopped --network host \
  nadoo/glider -verbose \
  -listen "ss://AEAD_AES_256_GCM:ПАРОЛЬ@:8388" \
  -forward "ss://AEAD_AES_256_GCM:ПАРОЛЬ@НОВЫЙ_IP:8388"
```
