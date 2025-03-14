#!/bin/bash

# Скрипт установки и настройки Squid Proxy с IPv6 + IPv4 (универсальный для любых серверов)

echo "\n🚀 Установка Squid-прокси с полной анонимностью, поддержкой IPv6 и максимальной скоростью...\n"

# Обновление системы и установка необходимых пакетов
apt update && apt upgrade -y
apt install -y squid apache2-utils 3proxy dnsmasq curl

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

# Настройка dnsmasq для локального DNS (ускоряет работу и маскирует DNS-запросы)
cat <<EOF > /etc/dnsmasq.conf
cache-size=1000
server=8.8.8.8
server=8.8.4.4
bogus-priv
filterwin2k
strict-order
EOF
systemctl restart dnsmasq
systemctl enable dnsmasq

# Остановка и отключение системного firewall
timedatectl set-timezone UTC
systemctl stop firewalld 2>/dev/null
systemctl disable firewalld 2>/dev/null

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

# Создание конфигурации Squid (HTTPS прокси)
cat <<EOF > /etc/squid/squid.conf
http_port $START_PORT
acl localnet src all
http_access allow localnet
forwarded_for delete
request_header_add User-Agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36" all
request_header_add Accept-Language "en-US,en;q=0.9" all
request_header_add Referer "https://www.google.com/" all
request_header_access X-Forwarded-For deny all
auth_param basic program /usr/lib/squid/basic_ncsa_auth /etc/squid/passwd
auth_param basic realm Proxy
acl authenticated proxy_auth REQUIRED
http_access allow authenticated
max_filedescriptors 65535
cache_mem 512 MB
cache_replacement_policy heap LFUDA
memory_replacement_policy heap LFUDA
logfile_rotate 10
maximum_object_size 10 MB
maximum_object_size_in_memory 512 KB
cache_dir aufs /var/spool/squid 5000 16 256
access_log none
cache_log /dev/null
cache_store_log none
EOF

> /etc/squid/passwd
for ((i=0; i<PROXY_COUNT; i++)); do
    echo "$PROXY_USER:${PASSWORD_LIST[i]}" >> /etc/squid/passwd
    echo "tcp_outgoing_address ${PROXY_LIST[i]}" >> /etc/squid/squid.conf
    echo "acl random_ip myip ${PROXY_LIST[i]}" >> /etc/squid/squid.conf
    echo "tcp_outgoing_address ${PROXY_LIST[i]} random_ip" >> /etc/squid/squid.conf
    echo "http://$PROXY_USER:${PASSWORD_LIST[i]}@$IPV4:$((START_PORT + i))" >> $PROXY_FILE
    echo "socks5://$PROXY_USER:${PASSWORD_LIST[i]}@$IPV4:$((START_PORT + i + 10000))" >> $PROXY_FILE
    echo "" >> $PROXY_FILE
done

# Перезапуск сервисов
systemctl restart squid
systemctl enable squid
3proxy /etc/3proxy/3proxy.cfg &

# Вывод данных о прокси
echo "\n✅ Прокси установлены и полностью анонимизированы!"
echo "🔹 Список всех прокси сохранён в: $PROXY_FILE"
for ((i=0; i<PROXY_COUNT; i++)); do
    echo "🌍 HTTPS: http://$PROXY_USER:${PASSWORD_LIST[i]}@$IPV4:$((START_PORT + i))"
    echo "🧦 SOCKS5: socks5://$PROXY_USER:${PASSWORD_LIST[i]}@$IPV4:$((START_PORT + i + 10000))"
done

echo "\n🔁 Чтобы сменить режим работы прокси, просто измените порт (на +10000 для SOCKS5)."
