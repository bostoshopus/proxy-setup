#!/bin/bash

# Скрипт автоматической установки 3proxy на Debian 12 с логином boostshop

echo "🔄 Обновляем систему и устанавливаем зависимости..."
apt-get update --allow-releaseinfo-change
apt-get update --allow-releaseinfo-change --allow-releaseinfo-change-suite
apt-get update && apt-get install -y git wget curl gcc make build-essential libc6-dev net-tools sudo

# Очистка старых файлов, если вдруг они остались
echo "🧹 Удаляем старые файлы..."
rm -rf /tmp/3proxy /usr/local/bin/3proxy /etc/3proxy /var/log/3proxy.log /etc/systemd/system/3proxy.service

# Скачиваем и компилируем 3proxy
echo "⬇️ Скачиваем и компилируем 3proxy..."
cd /tmp
git clone https://github.com/z3APA3A/3proxy.git
cd 3proxy
make -f Makefile.Linux

# Проверяем, успешно ли скомпилировался бинарник
if [ ! -f "src/3proxy" ]; then
    echo "❌ Ошибка: Бинарник 3proxy не найден! Компиляция провалилась."
    exit 1
fi

# Устанавливаем 3proxy
echo "🚀 Устанавливаем 3proxy..."
mkdir -p /usr/local/bin
cp src/3proxy /usr/local/bin/3proxy
chmod +x /usr/local/bin/3proxy

# Запрашиваем параметры у пользователя
read -p "Введите количество прокси: " PROXY_COUNT
read -p "Введите используемую IPv6 подсеть (например, 2a03:f80:49:4092::/48 или /64): " IPV6_SUBNET

# Генерация случайного стартового порта
START_PORT=$((RANDOM % 40000 + 10000))
IPV4=$(curl -4 ifconfig.me)

# Создаем конфигурацию 3proxy
echo "📄 Создаем конфигурацию 3proxy..."
mkdir -p /etc/3proxy
cat <<EOF > /etc/3proxy/3proxy.cfg
daemon
log /var/log/3proxy.log
auth strong
EOF

# Генерация списка прокси
PROXY_FILE="/root/proxy_list.txt"
echo "" > $PROXY_FILE

for ((i=0; i<$PROXY_COUNT; i++)); do
    IPV6="${IPV6_SUBNET}::${i}"
    PORT=$((START_PORT + i))
    PASSWORD=$(openssl rand -base64 12)

    echo "users boostshop:CL:$PASSWORD" >> /etc/3proxy/3proxy.cfg
    echo "allow boostshop" >> /etc/3proxy/3proxy.cfg
    echo "socks -6 -p$PORT" >> /etc/3proxy/3proxy.cfg

    echo "$IPV4:$PORT:boostshop:$PASSWORD" >> $PROXY_FILE
done

# Создаем systemd сервис
echo "🔧 Создаем systemd сервис для 3proxy..."
cat <<EOF > /etc/systemd/system/3proxy.service
[Unit]
Description=3proxy Proxy Server
After=network.target

[Service]
ExecStart=/usr/local/bin/3proxy /etc/3proxy/3proxy.cfg
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

# Перезагружаем systemd, включаем и запускаем сервис
echo "♻️ Перезапускаем сервис 3proxy..."
systemctl daemon-reload
systemctl enable 3proxy
systemctl restart 3proxy

# Проверяем статус 3proxy
echo "🔍 Проверяем статус 3proxy..."
sleep 3
systemctl status 3proxy --no-pager

# Выводим путь к файлу с прокси
echo "✅ Установка завершена! Прокси сохранены в файл: /root/proxy_list.txt"
echo "📄 Для просмотра прокси выполните: cat /root/proxy_list.txt"
