#!/bin/bash

# Устанавливаем все необходимые зависимости
echo "🔄 Обновление системы и установка необходимых пакетов..."
apt-get update --allow-releaseinfo-change
apt-get update --allow-releaseinfo-change --allow-releaseinfo-change-suite
apt-get update && apt-get install -y git wget curl make gcc build-essential net-tools sudo systemctl

# Проверяем и включаем systemctl (если его нет)
if ! command -v systemctl &> /dev/null; then
    echo "⚠️ Systemctl не найден! Устанавливаем..."
    apt-get install -y systemd
fi

# Загружаем и запускаем установку NPPRProxy
echo "⬇️ Загрузка и установка NPPRProxy..."
wget -O npprproxyfull.sh https://raw.githubusercontent.com/nppr-team/npprproxydebian/main/npprproxyfull.sh
chmod +x npprproxyfull.sh
bash npprproxyfull.sh || bash npprproxyfull.sh --disable-inet6-ifaces-check

# Проверяем и исправляем ошибки с IPv6
if [[ $? -ne 0 ]]; then
    echo "⚠️ Возникла ошибка с IPv6. Пробуем обойти её..."
    bash npprproxyfull.sh --disable-inet6-ifaces-check
fi

# Принимаем лицензионное соглашение для 3proxy
echo "✅ Принятие лицензионного соглашения для 3proxy..."
mkdir -p /usr/local/etc/3proxy
echo "AcceptLicenseAgreement = 1" > /usr/local/etc/3proxy/3proxy.cfg

# Проверяем и запускаем 3proxy
if command -v 3proxy &> /dev/null; then
    echo "🚀 Запуск 3proxy..."
    3proxy /usr/local/etc/3proxy/3proxy.cfg
else
    echo "❌ Ошибка: 3proxy не найден! Проверяем установку..."
    bash npprproxyfull.sh --reinstall
fi

# Автоматический запуск 3proxy при перезагрузке
echo "🔧 Настройка автозапуска 3proxy..."
cat <<EOF > /etc/systemd/system/3proxy.service
[Unit]
Description=3Proxy Proxy Server
After=network.target

[Service]
ExecStart=/usr/local/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable 3proxy
systemctl restart 3proxy

echo "✅ Установка завершена! 3proxy успешно запущен."
