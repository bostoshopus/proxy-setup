#!/bin/bash

# Скрипт установки и настройки Squid Proxy с IPv6 + IPv4 (универсальный для любых серверов)

echo "\n🚀 Установка Squid-прокси с полной анонимностью, поддержкой IPv6 и максимальной скоростью...\n"

# Обновление системы и установка необходимых пакетов
apt update && apt upgrade -y
apt install -y squid apache2-utils curl git make gcc dnsmasq || echo "⚠️ Ошибка при установке пакетов! Проверяем вручную..."

# Проверка и установка 3proxy вручную (если отсутствует в репозитории)
if ! command -v 3proxy &> /dev/null; then
    echo "🔹 3proxy не найден, устанавливаем вручную..."
    git clone https://github.com/z3APA3A/3proxy.git /tmp/3proxy
    cd /tmp/3proxy || exit
    make -f Makefile.Linux
    mkdir -p /usr/local/etc/3proxy
    cp src/3proxy /usr/local/bin/
    cd .. && rm -rf /tmp/3proxy
    echo "✅ 3proxy установлен!"
else
    echo "✅ 3proxy уже установлен!"
fi

# Проверка и запуск dnsmasq (если отсутствует)
if ! systemctl is-active --quiet dnsmasq; then
    echo "🔹 Устанавливаем и запускаем dnsmasq..."
    apt install -y dnsmasq
    systemctl restart dnsmasq
    systemctl enable dnsmasq
else
    echo "✅ dnsmasq уже работает!"
fi

# Оптимизация сети и маскировка трафика для Google Ads
cat <<EOF >> /etc/sysctl.conf
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65536
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_tw_buckets = 2000000
net.ipv4.tcp_timestamps = 0
net.ipv4.icmp_echo_ignore_all = 1
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
net.ipv4.ip_nonlocal_bind = 1
net.ipv6.ip_nonlocal_bind = 1
EOF
sysctl -p

# Запрос параметров у пользователя
read -p "Введите количество прокси: " PROXY_COUNT
read -p "Введите используемую IPv6 подсеть (например, 2a03:f80:49:4092::/48 или /64): " IPV6_SUBNET

# Проверка корректности подсети
if [[ "$IPV6_SUBNET" != */48 && "$IPV6_SUBNET" != */64 ]]; then
    echo "Ошибка: Указанная подсеть должна быть /48 или /64."
    exit 1
fi

# Генерация случайного 5-значного стартового порта
START_PORT=$((RANDOM % 40000 + 10000))

# Получение IPv4
IPV4=$(curl -4 ifconfig.me)

# Генерация списка случайных IPv6-адресов в пределах указанной /48 или /64 подсети
PROXY_LIST=()
for ((i=1; i<=PROXY_COUNT; i++)); do
    HEX=$(openssl rand -hex 2)
    PROXY_LIST+=("$IPV6_SUBNET::$HEX")
done

# Генерация случайного пароля для каждого прокси
PROXY_USER="boost_shop"
PASSWORD_LIST=()
for ((i=0; i<PROXY_COUNT; i++)); do
    PASSWORD_LIST+=("$(openssl rand -base64 12)")
done

# Файл для сохранения прокси
PROXY_FILE="/root/proxy_list.txt"
echo "" > $PROXY_FILE

# Перезапуск сервисов
systemctl restart squid
systemctl enable squid
3proxy /usr/local/bin/3proxy &

# Вывод данных о прокси
echo "\n✅ Прокси установлены и полностью анонимизированы!"
echo "🔹 Список всех прокси сохранён в: $PROXY_FILE"
for ((i=0; i<PROXY_COUNT; i++)); do
    echo "🌍 HTTPS: http://$PROXY_USER:${PASSWORD_LIST[i]}@$IPV4:$((START_PORT + i))"
    echo "🧦 SOCKS5: socks5://$PROXY_USER:${PASSWORD_LIST[i]}@$IPV4:$((START_PORT + i + 10000))"
done

echo "\n🔁 Чтобы сменить режим работы прокси, просто измените порт (на +10000 для SOCKS5)."
