#!/bin/bash
# Скрипт автоматической установки 3proxy с логином boostshop

# Обновление системы и установка зависимостей
apt-get update --allow-releaseinfo-change
apt-get upgrade -y
apt-get install -y git wget curl build-essential net-tools sudo

# Удаляем старую версию 3proxy, если есть
pkill 3proxy
rm -rf /usr/local/bin/3proxy /etc/3proxy /tmp/3proxy

# Скачивание и компиляция 3proxy
cd /tmp
git clone https://github.com/z3APA3A/3proxy.git
cd 3proxy
make -f Makefile.Linux
mkdir -p /usr/local/bin
cp src/3proxy /usr/local/bin/
chmod +x /usr/local/bin/3proxy

# Запрос параметров у пользователя
read -p "Введите количество прокси: " PROXY_COUNT
read -p "Введите используемую IPv6 подсеть (например, 2a03:f80:49:4092::/48 или /64): " IPV6_SUBNET

# Генерация случайного 5-значного стартового порта
START_PORT=$((RANDOM % 40000 + 10000))

# Получение основного IPv4
IPV4=$(curl -4 ifconfig.me)

# Создаём файл для списка прокси
PROXY_FILE="/root/proxy_list.txt"
echo "" > $PROXY_FILE

# Генерация списка прокси
for ((i=0; i<$PROXY_COUNT; i++)); do
    IPV6="${IPV6_SUBNET::-3}$i"
    PORT=$((START_PORT + i))
    PASSWORD=$(openssl rand -base64 12)

    # Запись в файл
    echo "$IPV4:$PORT:boostshop:$PASSWORD" >> $PROXY_FILE
done

# Создание конфигурации для 3proxy
mkdir -p /etc/3proxy
cat > /etc/3proxy/3proxy.cfg <<EOF
daemon
log /var/log/3proxy.log
auth strong
users boostshop:CL:$PASSWORD
allow boostshop
proxy -6 -p$START_PORT
socks -6 -p$((START_PORT + 1))
EOF

# Создание systemd сервиса для 3proxy
cat > /etc/systemd/system/3proxy.service <<EOF
[Unit]
Description=3proxy Proxy Server
After=network.target

[Service]
ExecStart=/usr/local/bin/3proxy /etc/3proxy/3proxy.cfg
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Перезапуск systemd и запуск 3proxy
systemctl daemon-reload
systemctl enable 3proxy
systemctl restart 3proxy

echo "✅ Установка завершена!"
echo "📄 Прокси сохранены в файл /root/proxy_list.txt"
