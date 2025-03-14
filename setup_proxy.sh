#!/bin/bash

# Обновление системы и установка зависимостей
apt update && apt upgrade -y
apt install -y git curl build-essential net-tools sudo

# Скачивание и сборка 3proxy
rm -rf /tmp/3proxy
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

# Получение текущего IPv4
IPV4=$(curl -4 ifconfig.me)

# Файл для хранения списка прокси
PROXY_FILE="/root/proxy_list.txt"
echo "" > $PROXY_FILE

# Генерация списка прокси
for ((i=0; i<$PROXY_COUNT; i++)); do
    HEX=$(openssl rand -hex 2)
    IPV6_ADDR="$IPV6_SUBNET:$HEX"
    PORT=$(($START_PORT + i))
    PASSWORD=$(openssl rand -base64 12)
    echo "$IPV4:$PORT:boostshop:$PASSWORD" >> $PROXY_FILE

done

# Создание конфигурации для 3proxy
cat <<EOF > /etc/3proxy.cfg
daemon
nserver 8.8.8.8
nserver 8.8.4.4
config /etc/3proxy.cfg
log /var/log/3proxy.log
socks -p3128
EOF

# Создание systemd сервиса для автозапуска 3proxy
cat <<EOF > /etc/systemd/system/3proxy.service
[Unit]
Description=3Proxy Server
After=network.target

[Service]
ExecStart=/usr/local/bin/3proxy /etc/3proxy.cfg
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Запуск 3proxy и добавление в автозагрузку
systemctl daemon-reload
systemctl enable 3proxy
systemctl restart 3proxy

# Вывод завершения
echo "✅ Прокси успешно созданы! Найдите их в файле /root/proxy_list.txt"
