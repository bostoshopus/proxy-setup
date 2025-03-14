#!/bin/bash

# Обновление системы и установка зависимостей
echo "🔄 Обновление системы и установка необходимых пакетов..."
apt-get update --allow-releaseinfo-change
apt-get update --allow-releaseinfo-change --allow-releaseinfo-change-suite
apt-get update && apt-get install -y git wget curl make gcc build-essential net-tools sudo systemctl nano

# Установка 3proxy
echo "🔧 Установка 3proxy..."
cd /tmp
git clone https://github.com/3proxy/3proxy.git
cd 3proxy
make -f Makefile.Linux
mkdir -p /usr/local/bin /usr/local/etc/3proxy
cp src/3proxy /usr/local/bin/
chmod +x /usr/local/bin/3proxy

# Создание конфигурации 3proxy
echo "⚙️ Настройка 3proxy..."
mkdir -p /usr/local/etc/3proxy
CONFIG_FILE="/usr/local/etc/3proxy/3proxy.cfg"

# Запрос количества прокси
read -p "Введите количество прокси: " PROXY_COUNT
read -p "Введите IPv6 подсеть (например, 2a03:f80:49:4092::/48 или /64): " IPV6_SUBNET

# Генерация списка прокси
START_PORT=40000
PROXY_FILE="/root/proxy_list.txt"
> $PROXY_FILE

echo "daemon" > $CONFIG_FILE
echo "log /dev/null" >> $CONFIG_FILE
echo "nserver 8.8.8.8" >> $CONFIG_FILE
echo "nserver 8.8.4.4" >> $CONFIG_FILE
echo "maxconn 1000" >> $CONFIG_FILE
echo "nscache 65536" >> $CONFIG_FILE
echo "timeouts 1 5 30 60 180 1800 15 60" >> $CONFIG_FILE
echo "users proxyuser:CL:proxy123" >> $CONFIG_FILE

for ((i=0; i<$PROXY_COUNT; i++)); do
  HEX=$(openssl rand -hex 2)
  IPV6="${IPV6_SUBNET::-3}:$HEX"
  LOGIN="user$i"
  PASSWORD=$(openssl rand -base64 12)

  echo "auth strong" >> $CONFIG_FILE
  echo "allow $LOGIN" >> $CONFIG_FILE
  echo "proxy -6 -n -a -p$((START_PORT + i)) -i$(curl -4 ifconfig.me) -e$IPV6" >> $CONFIG_FILE

  echo "$(curl -4 ifconfig.me):$((START_PORT + i)):$LOGIN:$PASSWORD" >> $PROXY_FILE
done

# Создание systemd сервиса для автозапуска 3proxy
echo "🛠️ Создание systemd сервиса..."
cat <<EOF > /etc/systemd/system/3proxy.service
[Unit]
Description=3proxy Proxy Server
After=network.target

[Service]
ExecStart=/usr/local/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Перезапуск 3proxy и добавление в автозапуск
echo "🚀 Запуск 3proxy..."
systemctl daemon-reload
systemctl enable 3proxy
systemctl restart 3proxy

echo "✅ Прокси установлены и полностью анонимизированы!"
echo "📜 Все прокси сохранены в файл: $PROXY_FILE"
cat $PROXY_FILE
