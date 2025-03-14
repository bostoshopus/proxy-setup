#!/bin/bash

# Автоматическая установка 3proxy с настройкой IPv6-прокси
# Этот скрипт устанавливает все зависимости, компилирует 3proxy, настраивает его и запускает

set -e  # Остановка при ошибке

# 1. Обновление пакетов и установка зависимостей
apt update && apt upgrade -y
apt install -y git wget curl build-essential iproute2 net-tools sudo

# 2. Скачивание и установка 3proxy
cd /tmp
rm -rf 3proxy  # Удаляем старую папку, если есть

git clone https://github.com/z3APA3A/3proxy.git
cd 3proxy
make -f Makefile.Linux
make -f Makefile.Linux install

# 3. Проверка наличия бинарника
if [ ! -f /usr/local/bin/3proxy ]; then
    echo "Ошибка: 3proxy не был установлен!"
    exit 1
fi

# 4. Запрос параметров у пользователя
read -p "Введите количество прокси: " PROXY_COUNT
read -p "Введите используемую IPv6 подсеть (например, 2a03:f80:49:4092::/48 или /64): " IPV6_SUBNET

# 5. Генерация списка IPv6-адресов и портов
START_PORT=$((RANDOM % 40000 + 10000))
IPV4=$(curl -4 ifconfig.me)
PROXY_FILE="/root/proxy_list.txt"
echo "" > $PROXY_FILE

for ((i=0; i<PROXY_COUNT; i++)); do
    HEX=$(openssl rand -hex 2)
    IPV6="$IPV6_SUBNET:$HEX"
    PORT=$((START_PORT + i))
    LOGIN="boost_shop"
    PASSWORD=$(openssl rand -base64 12)
    echo "$IPV4:$PORT:$LOGIN:$PASSWORD" >> $PROXY_FILE
    echo "$IPV6:$PORT:$LOGIN:$PASSWORD" >> $PROXY_FILE

done

# 6. Настройка systemd для автозапуска
cat > /etc/systemd/system/3proxy.service <<EOF
[Unit]
Description=3proxy Proxy Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/3proxy /etc/3proxy/3proxy.cfg
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable 3proxy
systemctl restart 3proxy

# 7. Проверка статуса 3proxy
systemctl status 3proxy --no-pager

# 8. Интеграция с существующим скриптом
wget -O npprproxyfull.sh https://raw.githubusercontent.com/nppr-team/npprproxydebian/main/npprproxyfull.sh
chmod +x npprproxyfull.sh
bash npprproxyfull.sh

# 9. Вывод списка прокси
echo "✅ Прокси установлены! Список сохранён в $PROXY_FILE"
cat $PROXY_FILE
